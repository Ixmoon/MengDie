import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../../data/llmapi/llm_models.dart';
import '../../../domain/models/models.dart';
import '../../../data/llmapi/llm_service.dart';
import '../../tools/context_xml_service.dart';
import '../api_key_provider.dart';
import '../repository_providers.dart'; 
import 'mixins/ui_state_manager.dart';
import 'mixins/message_operations.dart';
import 'mixins/generation_logic.dart';
import 'mixins/background_tasks.dart';
import 'mixins/special_actions.dart';
import '../chat_state_providers.dart';


class ChatStateNotifier extends StateNotifier<ChatScreenState>
    with
        UiStateManager,
        MessageOperations,
        GenerationLogic,
        BackgroundTasks,
        SpecialActions {
    @override
    final Ref ref;

    @override
    final int chatId;

    // --- Properties that belong to the Notifier itself ---
    @override
    StreamSubscription<LlmStreamChunk>? llmStreamSubscription;

    @override
    bool isFinalizing = false;

    ChatStateNotifier(this.ref, this.chatId) : super(const ChatScreenState());

    // --- Method Implementations to satisfy Mixin contracts ---

    @override
    ApiConfig getEffectiveApiConfig({String? specificConfigId}) {
        final allConfigs = ref.read(apiKeyNotifierProvider).apiConfigs;
        if (allConfigs.isEmpty) {
            throw Exception("无法获取有效API配置：全局API配置列表为空。");
        }
        final chat = ref.read(currentChatProvider(chatId)).value;
        if (specificConfigId != null) {
            final config = allConfigs.firstWhereOrNull((c) => c.id == specificConfigId);
            if (config != null) return config;
        }
        if (chat?.apiConfigId != null) {
            final config = allConfigs.firstWhereOrNull((c) => c.id == chat!.apiConfigId);
            if (config != null) return config;
        }
        return allConfigs.first;
    }

    @override
    String? getEffectiveApiConfigId({String? specificConfigId}) {
        try {
            return getEffectiveApiConfig(specificConfigId: specificConfigId).id;
        } catch (e) {
            return null;
        }
    }
    
    Future<void> calculateAndStoreTokenCount() async {
      if (!mounted) return;

      final apiConfigs = ref.read(apiKeyNotifierProvider).apiConfigs;
      if (apiConfigs.isEmpty) {
        if (mounted && state.totalTokens != null) {
          state = state.copyWith(clearTotalTokens: true);
        }
        return;
      }

      final chat = ref.read(currentChatProvider(chatId)).value;
      final messages = ref.read(chatMessagesProvider(chatId)).value;

      if (chat == null || messages == null || messages.isEmpty) {
        if (mounted) state = state.copyWith(clearTotalTokens: true);
        return;
      }

      try {
        final llmService = ref.read(llmServiceProvider);
        final contextXmlService = ref.read(contextXmlServiceProvider);
        
        final apiRequestContext = await contextXmlService.buildApiRequestContext(
          chatId: chatId,
          currentUserMessage: messages.last,
        );
        
        final apiConfig = getEffectiveApiConfig();
        final count = await llmService.countTokens(
          llmContext: apiRequestContext.contextParts,
          apiConfig: apiConfig,
        );

        if (mounted) {
          state = state.copyWith(totalTokens: count > 0 ? count : null);
          debugPrint("ChatStateNotifier($chatId): Token count updated to $count");
        }
      } catch (e) {
        debugPrint("ChatStateNotifier($chatId): Error calculating token count: $e");
        if (mounted) {
          state = state.copyWith(clearTotalTokens: true);
        }
      }
    }

    @override
    void dispose() {
        llmStreamSubscription?.cancel();
        stopUpdateTimer(); // from UiStateManager
        topMessageTimer?.cancel(); // from UiStateManager
        super.dispose();
    }

  /// 统一的聊天衍生操作入口，由UI层调用。
  ///
  /// [upToMessageId]
  ///   - `0`: 克隆设置 (不含消息)。
  ///   - `> 0`: 从指定消息分叉。
  /// [asTemplate] 如果为 true, 则另存为模板。
  Future<void> duplicateChat({
    int? upToMessageId,
    bool asTemplate = false,
  }) async {
    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final originalChat = ref.read(currentChatProvider(chatId)).value;
      if (originalChat == null) {
        throw Exception("原始聊天不存在。");
      }

      // 默认情况下，克隆或另存为模板时总是清除总结。
      bool shouldClearSummary = true;

      // 仅在分叉操作 (upToMessageId > 0) 且存在总结时，才进行检查。
      if ((upToMessageId ?? 0) > 0 && originalChat.contextSummary != null) {
        final contextXmlService = ref.read(contextXmlServiceProvider);
        final tempContext = await contextXmlService.buildApiRequestContext(
          chatId: chatId,
          // 使用一个虚拟的当前消息来获取历史状态
          currentUserMessage: Message(chatId: chatId, role: MessageRole.user, parts: [MessagePart.text("check scope")])
        );
        
        // 检查分叉点是否在被丢弃（即已总结）的消息中。
        final isForkingFromSummarized = tempContext.droppedMessages.any((m) => m.id == upToMessageId);
        
        // 如果分叉点不在已总结的部分，则不应清除总结，让新对话继承它。
        if (!isForkingFromSummarized) {
          shouldClearSummary = false;
        }
        debugPrint("ChatStateNotifier($chatId): 分叉检查 - 分叉点 $upToMessageId 是否在总结区? $isForkingFromSummarized. 是否清除总结? $shouldClearSummary.");
      }


      final newChatId = await chatRepo.duplicateChat(
        chatId,
        upToMessageId: upToMessageId,
        asTemplate: asTemplate,
        shouldClearSummary: shouldClearSummary, // 传递新参数
      );

      // 另存为模板时，不进行页面跳转，仅显示提示。
      if (asTemplate) {
        showTopMessage('已成功另存为模板', backgroundColor: Colors.green);
        // 手动刷新模板列表
        ref.invalidate(chatListProvider((parentFolderId: null, mode: ChatListMode.templateManagement)));
        return;
      }

      // 对于分叉和克隆，执行页面跳转。
      // 关键：先显示消息，再触发跳转。
      showTopMessage(upToMessageId == 0 ? '已成功克隆为新聊天' : '已创建分叉对话', backgroundColor: Colors.green);
      
      // 强制刷新当前文件夹的聊天列表，确保新聊天在数据源中。
      // 这是解决跳转问题的关键步骤。
      await ref.refresh(chatListProvider((parentFolderId: originalChat.parentFolderId, mode: ChatListMode.normal)).future);

      // 安全地触发页面跳转
      ref.read(activeChatIdProvider.notifier).state = newChatId;

    } catch (e) {
      debugPrint("Notifier duplicateChat 时出错: $e");
      if (mounted) {
        showTopMessage('操作失败: $e', backgroundColor: Colors.red);
      }
    }
  }
}
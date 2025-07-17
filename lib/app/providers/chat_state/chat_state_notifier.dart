import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../../domain/models/api_config.dart';
import '../../../domain/models/message.dart';
import '../../../data/llmapi/llm_models.dart';
import '../../../domain/models/chat.dart';
import '../../repositories/message_repository.dart';
import '../../../data/llmapi/llm_service.dart';
import '../../tools/context_xml_service.dart';
import '../api_key_provider.dart';
import '../repository_providers.dart'; // Added to resolve provider errors
import 'chat_screen_state.dart';
import 'mixins/ui_state_manager.dart';
import 'mixins/message_operations.dart';
import 'mixins/generation_logic.dart';
import 'mixins/background_tasks.dart';
import 'mixins/special_actions.dart';
import 'chat_data_providers.dart';

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

    // --- Properties to satisfy UiStateManager contract ---
    @override
    Timer? updateTimer;
    
    @override
    Timer? topMessageTimer;

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

  Future<void> forkChat(Message fromMessage) async {
    // This logic is now self-contained and safe from UI lifecycle issues.
    // It directly updates the global state provider upon completion.
    
    final chatRepo = ref.read(chatRepositoryProvider);
    final messageRepo = ref.read(messageRepositoryProvider);
    final allMessagesAsync = ref.read(chatMessagesProvider(chatId));
    final originalChat = ref.read(currentChatProvider(chatId)).value;

    if (originalChat == null || allMessagesAsync.value == null) {
      showTopMessage('无法分叉：原始数据丢失', backgroundColor: Colors.red);
      return;
    }

    final allMessages = allMessagesAsync.value!;
    final forkIndex = allMessages.indexWhere((m) => m.id == fromMessage.id);
    if (forkIndex == -1) {
      showTopMessage('无法分叉：未找到消息', backgroundColor: Colors.red);
      return;
    }

    final messagesToKeep = allMessages.sublist(0, forkIndex + 1);

    try {
      String newTitle;
      final baseTitle = originalChat.title ?? "无标题";
      final RegExp titleRegex = RegExp(r'^(.*)-(\d+)$');
      final Match? match = titleRegex.firstMatch(baseTitle);

      if (match != null) {
        final namePart = match.group(1);
        final numberPart = int.tryParse(match.group(2) ?? '');
        if (namePart != null && numberPart != null) {
          newTitle = '$namePart-${numberPart + 1}';
        } else {
          newTitle = '$baseTitle-1';
        }
      } else {
        newTitle = '$baseTitle-1';
      }

      final now = DateTime.now();
      final newChat = Chat(
        title: newTitle,
        parentFolderId: originalChat.parentFolderId,
        systemPrompt: originalChat.systemPrompt,
        coverImageBase64: originalChat.coverImageBase64,
        backgroundImagePath: originalChat.backgroundImagePath,
        apiConfigId: originalChat.apiConfigId,
        contextConfig: originalChat.contextConfig.copyWith(),
        xmlRules: List.from(originalChat.xmlRules),
        enablePreprocessing: originalChat.enablePreprocessing,
        preprocessingPrompt: originalChat.preprocessingPrompt,
        preprocessingApiConfigId: originalChat.preprocessingApiConfigId,
        contextSummary: null,
        enableSecondaryXml: originalChat.enableSecondaryXml,
        secondaryXmlPrompt: originalChat.secondaryXmlPrompt,
        secondaryXmlApiConfigId: originalChat.secondaryXmlApiConfigId,
        continuePrompt: originalChat.continuePrompt,
        createdAt: now,
        updatedAt: now,
      );
      
      final newChatId = await chatRepo.saveChat(newChat);

      final List<Message> newMessages = messagesToKeep.map((originalMsg) {
        return Message(
          chatId: newChatId,
          parts: originalMsg.parts,
          role: originalMsg.role,
          timestamp: originalMsg.timestamp,
          originalXmlContent: originalMsg.originalXmlContent,
          secondaryXmlContent: originalMsg.secondaryXmlContent,
        );
      }).toList();
      await messageRepo.saveMessages(newMessages);

      // Directly update the active chat ID, making the UI react.
      // This is safe because it uses the notifier's own 'ref'.
      ref.read(activeChatIdProvider.notifier).state = newChatId;

      showTopMessage('已创建分叉对话', backgroundColor: Colors.green);

    } catch (e) {
      debugPrint("Notifier 分叉对话时出错: $e");
      if (mounted) {
        showTopMessage('分叉对话失败: $e', backgroundColor: Colors.red);
      }
    }
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/sync/sync_service.dart';
import '../../../../domain/enums.dart';
import '../../../../domain/models/message.dart';
import '../../../tools/context_xml_service.dart';
import '../../repository_providers.dart';
import '../../../repositories/message_repository.dart'; // Corrected import
import '../chat_screen_state.dart';
import '../chat_data_providers.dart';

mixin MessageOperations on StateNotifier<ChatScreenState> {
    // Abstract dependencies to be implemented by the main class
    Ref get ref;
    int get chatId;
    bool get mounted;

    // Abstract methods that this mixin depends on
    void clearHelpMeReplySuggestions();
    void showTopMessage(String text, {Color? backgroundColor, Duration duration = const Duration(seconds: 3)});

    Future<void> deleteMessage(int messageId) async {
    if (!mounted) return;
    try {
      final messageRepo = ref.read(messageRepositoryProvider);
      final deleted = await messageRepo.deleteMessage(messageId);
      if (mounted) {
        if (deleted) {
          showTopMessage('消息已删除', backgroundColor: Colors.green, duration: const Duration(seconds: 2));
          clearHelpMeReplySuggestions(); // Clear suggestions as they might be based on the deleted message

          final chatRepo = ref.read(chatRepositoryProvider);
          final chat = await chatRepo.getChat(chatId);
          if (chat != null && chat.contextSummary != null) {
            final contextXmlService = ref.read(contextXmlServiceProvider);
            final tempContext = await contextXmlService.buildApiRequestContext(
              chatId: chatId,
              currentUserMessage: Message(chatId: chatId, role: MessageRole.user, parts: [MessagePart.text("check scope")])
            );
            final bool isMessageInSummarizedScope = tempContext.droppedMessages.any((m) => m.id == messageId);

            if (isMessageInSummarizedScope) {
              await chatRepo.saveChat(chat.copyWith(contextSummary: null));
              debugPrint("ChatStateNotifier($chatId): 因被删除的消息在摘要范围内，已清除上下文摘要。");
            } else {
              debugPrint("ChatStateNotifier($chatId): 被删除的消息不在摘要范围内，保留上下文摘要。");
            }
          }
        } else {
          showTopMessage('删除消息失败，可能已被删除', backgroundColor: Colors.orange);
        }
      }
    } catch (e) {
      debugPrint("Notifier 删除消息时出错: $e");
      if (mounted) {
        showTopMessage('删除消息出错: $e', backgroundColor: Colors.red);
      }
    }
  }

  Future<void> editMessage(int messageId, {String? newText, List<MessagePart>? newParts, Message? updatedMessage}) async {
    if (!mounted) return;
    try {
      final messageRepo = ref.read(messageRepositoryProvider);
      
      Message? messageToSave = updatedMessage;

      if (messageToSave == null) {
        final message = await messageRepo.getMessageById(messageId);
        if (message == null) {
          showTopMessage('无法编辑：未找到消息', backgroundColor: Colors.red);
          return;
        }
        if (newParts != null) {
          messageToSave = message.copyWith(parts: newParts);
        } else if (newText != null) {
          final updatedParts = message.parts.where((p) => p.type != MessagePartType.text).toList();
          updatedParts.insert(0, MessagePart.text(newText));
          messageToSave = message.copyWith(parts: updatedParts);
        } else {
          return; // Nothing to update
        }
      }
      
      await messageRepo.saveMessage(messageToSave);

      if (mounted) {
        showTopMessage('消息已更新', backgroundColor: Colors.green, duration: const Duration(seconds: 2));
        clearHelpMeReplySuggestions(); 

        final chatRepo = ref.read(chatRepositoryProvider);
        final chat = await chatRepo.getChat(chatId);
        if (chat != null && chat.contextSummary != null) {
          final contextXmlService = ref.read(contextXmlServiceProvider);
          final tempContext = await contextXmlService.buildApiRequestContext(
            chatId: chatId,
            currentUserMessage: Message(chatId: chatId, role: MessageRole.user, parts: [MessagePart.text("check scope")])
          );
          final bool isMessageInSummarizedScope = tempContext.droppedMessages.any((m) => m.id == messageId);

          if (isMessageInSummarizedScope) {
            await chatRepo.saveChat(chat.copyWith(contextSummary: null));
            debugPrint("ChatStateNotifier($chatId): 因被编辑的消息在摘要范围内，已清除上下文摘要。");
          } else {
            debugPrint("ChatStateNotifier($chatId): 被编辑的消息不在摘要范围内，保留上下文摘要。");
          }
        }
      }
    } catch (e) {
      debugPrint("Notifier 更新消息时出错: $e");
      if (mounted) {
        showTopMessage('保存编辑失败: $e', backgroundColor: Colors.red);
      }
    }
  }

  Future<void> leaveChat() async {
    if (!mounted) return;
    await SyncService.instance.forcePushChanges();
    ref.read(activeChatIdProvider.notifier).state = null;
  }

  Future<void> cloneChatAsTemplate() async {
    if (!mounted) return;
    try {
      final repo = ref.read(chatRepositoryProvider);
      await repo.cloneChat(chatId, asTemplate: true);
      if (!mounted) return;
      showTopMessage('已成功另存为模板', backgroundColor: Colors.green);
      ref.invalidate(chatListProvider((parentFolderId: null, mode: ChatListMode.templateManagement)));
    } catch (e) {
      if (mounted) {
        showTopMessage('另存为模板失败: $e', backgroundColor: Colors.red);
      }
    }
  }

  Future<int?> cloneChatAsNew() async {
    if (!mounted) return null;
    try {
      final repo = ref.read(chatRepositoryProvider);
      final newChatId = await repo.cloneChat(chatId, asTemplate: false);
      if (!mounted) return null;
      showTopMessage('已成功克隆为新聊天', backgroundColor: Colors.green);
      return newChatId;
    } catch (e) {
      if (mounted) {
        showTopMessage('克隆为新聊天失败: $e', backgroundColor: Colors.red);
      }
      return null;
    }
  }
}
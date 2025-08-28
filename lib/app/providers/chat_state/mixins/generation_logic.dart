import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import '../../../../domain/models/api_config.dart';
import '../../../../domain/models/message.dart';
import '../../../../domain/enums.dart';
import '../../../../data/llmapi/llm_models.dart';
import '../../../services/llm_coordinator_service.dart';
import '../../../../domain/models/chat.dart';
import '../../repository_providers.dart';
import '../chat_screen_state.dart';
import '../chat_data_providers.dart';

mixin GenerationLogic on StateNotifier<ChatScreenState> {
    // Abstract properties to be implemented by the main class
    Ref get ref;
    int get chatId;
    StreamSubscription<LlmStreamChunk>? get llmStreamSubscription;
    set llmStreamSubscription(StreamSubscription<LlmStreamChunk>? value);
    bool get isFinalizing;
    set isFinalizing(bool value);


    // Abstract methods to be implemented by other mixins or the main class
    ApiConfig getEffectiveApiConfig({String? specificConfigId});
    Future<void> runAsyncProcessingTasks(Message modelMessage);
    Future<Message> getFinalProcessedMessage(Chat chat, Message initialMessage);
    void clearHelpMeReplySuggestions();
    // Methods from UiStateManager that are used here
    void showTopMessage(String text, {Color? backgroundColor, Duration duration = const Duration(seconds: 3)});
    void startUpdateTimer();
    void stopUpdateTimer();


    // --- Methods moved from ChatStateNotifier ---

    Future<void> regenerateResponse(Message userMessage) async {
      if (!mounted) return;
  
      final allMessages = ref.read(chatMessagesProvider(chatId)).value ?? [];
      
      final messageIndex = allMessages.indexWhere((m) => m.id == userMessage.id);
      final isLastUserMsg = userMessage.role == MessageRole.user &&
          messageIndex >= 0 &&
          (messageIndex == allMessages.length - 1 ||
              (messageIndex == allMessages.length - 2 &&
                  allMessages.last.role == MessageRole.model));
  
      if (!isLastUserMsg) {
        showTopMessage('只能为最后的用户消息重新生成回复', backgroundColor: Colors.orange);
        return;
      }
      if (state.isLoading) {
        debugPrint("重新生成取消：已在加载中。");
        return;
      }
  
      await cancelGeneration();
  
      try {
        final messageRepo = ref.read(messageRepositoryProvider);
        List<int> messagesToDelete = [];
        if (messageIndex != -1 && messageIndex < allMessages.length - 1) {
          for (int i = messageIndex + 1; i < allMessages.length; i++) {
            if (allMessages[i].role == MessageRole.model) {
              messagesToDelete.add(allMessages[i].id);
            }
          }
        }
        if (messagesToDelete.isNotEmpty) {
          for (final msgId in messagesToDelete) {
            await messageRepo.deleteMessage(msgId);
          }
          await Future.delayed(const Duration(milliseconds: 100));
        }
      } catch (e) {
          showTopMessage('删除旧回复失败: $e', backgroundColor: Colors.red);
          return;
      }
  
      if (!mounted) return;
  
      clearHelpMeReplySuggestions();
      
      if (state.isImageGenerationMode) {
        await (this as dynamic).generateImage(userMessage);
      } else {
        await sendMessage(userMessage: userMessage, isRegeneration: true);
      }
    }

  Future<void> continueGeneration() async {
    if (state.isLoading) {
      debugPrint("续写操作取消：已在加载中。");
      return;
    }

    final allMessages = ref.read(chatMessagesProvider(chatId)).value ?? [];
    if (allMessages.isEmpty || allMessages.last.role != MessageRole.model) {
      showTopMessage('只能在模型回复后进行续写', backgroundColor: Colors.orange);
      return;
    }

    await sendMessage(isContinuation: true);
  }

  Future<void> sendMessage({
    List<MessagePart>? userParts,
    Message? userMessage, // Used for regeneration
    bool isRegeneration = false,
    bool isContinuation = false,
    String? promptOverride,
    int? messageToUpdateId,
    String? apiConfigIdOverride,
  }) async {
    if (state.isImageGenerationMode && !isRegeneration && !isContinuation) {
      if (userParts != null && userParts.isNotEmpty) {
        final userMessage = Message(
          chatId: chatId,
          role: MessageRole.user,
          parts: userParts,
        );
        final messageRepo = ref.read(messageRepositoryProvider);
        await messageRepo.saveMessage(userMessage);
        await (this as dynamic).generateImage(userMessage);
      }
      return;
    }

    if (state.isLoading && !isRegeneration && !isContinuation) {
      debugPrint("sendMessage ($chatId) 取消：已在加载中。");
      return;
    }
    
    if (state.isCancelled) {
      state = state.copyWith(isCancelled: false);
    }
    
    final apiConfig = getEffectiveApiConfig(specificConfigId: apiConfigIdOverride);
    final chat = ref.read(currentChatProvider(chatId)).value;
    if (chat == null) {
      showTopMessage('无法发送消息：聊天数据未加载。', backgroundColor: Colors.red);
      return;
    }

    Message messageForContext;
    List<Message> messagesToSave = [];

    if (isRegeneration && userMessage != null) {
      messageForContext = userMessage;
      debugPrint("重新生成操作，使用现有消息作为上下文。");
    } else if (isContinuation) {
      final allMessages = ref.read(chatMessagesProvider(chatId)).value ?? [];
      if (allMessages.isEmpty) return;
      messageForContext = allMessages.last;
      debugPrint("续写操作，使用现有历史作为上下文。");
    } else if (userParts != null && userParts.isNotEmpty) {
      final userMessage = Message(
        chatId: chatId,
        role: MessageRole.user,
        parts: userParts,
      );
      messagesToSave.add(userMessage);
      messageForContext = userMessage;
    } else {
      return; // Nothing to send
    }

    state = state.copyWith(
        isLoading: true,
        isPrimaryResponseLoading: true,
        isCancelled: false,
        clearError: true,
        clearTopMessage: true,
        clearStreaming: true,
        clearHelpMeReplySuggestions: true,
        clearStreamingMessage: true,
        generationStartTime: DateTime.now(),
    );
    startUpdateTimer();
    
    if (!isRegeneration && !isContinuation) {
      try {
        final messageRepo = ref.read(messageRepositoryProvider);
        await messageRepo.saveMessages(messagesToSave);
        final chatRepo = ref.read(chatRepositoryProvider);
        await chatRepo.saveChat(chat.copyWith(updatedAt: DateTime.now()));
        debugPrint("用户发送的 ${messagesToSave.length} 条原子消息已保存。");
      } catch (e) {
        debugPrint("保存用户消息时出错: $e");
        if (mounted) {
          showTopMessage('无法保存您的消息: $e', backgroundColor: Colors.red);
          state = state.copyWith(isLoading: false);
          stopUpdateTimer();
        }
        return;
      }
    }

    String? lastMessageOverride;
    if (promptOverride != null) {
      lastMessageOverride = promptOverride;
      debugPrint("sendMessage: 使用了 promptOverride。");
    } else if (isContinuation && (chat.continuePrompt?.isNotEmpty ?? false)) {
      lastMessageOverride = chat.continuePrompt;
      debugPrint("续写操作：将续写提示词作为最后的用户消息。");
    }

    try {
      if (state.isStreamMode) {
          await _handleStreamResponse(apiConfig, messageForContext, lastMessageOverride, messageToUpdateId: messageToUpdateId);
      } else {
          await _handleSingleResponse(apiConfig, messageForContext, lastMessageOverride, messageToUpdateId: messageToUpdateId);
      }
    } catch (e) {
        debugPrint("ChatStateNotifier:sendMessage($chatId): 调用LLM时出错: $e");
        if (mounted) {
          showTopMessage('生成回复失败: $e', backgroundColor: Colors.red);
          state = state.copyWith(isLoading: false);
          stopUpdateTimer();
        }
        return;
    }
   }

  Future<void> _handleStreamResponse(ApiConfig apiConfig, Message currentUserMessage, String? lastMessageOverride, {int? messageToUpdateId}) async {
    final messageRepo = ref.read(messageRepositoryProvider);
    int targetMessageId;
    Message baseMessage;
    String initialRawText = '';

    if (messageToUpdateId != null) {
      targetMessageId = messageToUpdateId;
      final msg = await messageRepo.getMessageById(targetMessageId);
      if (msg == null) {
        showTopMessage('无法恢复消息：未找到原始消息', backgroundColor: Colors.red);
        state = state.copyWith(isLoading: false);
        stopUpdateTimer();
        return;
      }
      baseMessage = msg;
      final StringBuffer combinedBuffer = StringBuffer(baseMessage.rawText);
      if (baseMessage.originalXmlContent != null && baseMessage.originalXmlContent!.isNotEmpty) {
        combinedBuffer.write(baseMessage.originalXmlContent);
      }
      initialRawText = combinedBuffer.toString();
    } else {
      targetMessageId = -DateTime.now().millisecondsSinceEpoch;
      baseMessage = Message(
        id: targetMessageId,
        chatId: chatId,
        role: MessageRole.model,
        parts: [MessagePart.text("...")],
      );
      debugPrint("ChatStateNotifier($chatId): Created temporary streaming message with ID: $targetMessageId.");
    }
 
    state = state.copyWith(
      streamingMessage: baseMessage,
      isStreamingMessageVisible: true,
      isStreaming: true,
    );
 
     final coordinator = ref.read(llmCoordinatorProvider);
     final stream = coordinator.generateStreamResponse(
        chatId: chatId,
        apiConfig: apiConfig,
        currentUserMessage: currentUserMessage,
        lastMessageOverride: lastMessageOverride,
     );
     llmStreamSubscription?.cancel();
     llmStreamSubscription = stream.listen(
       (chunk) async {
         if (!mounted) return;
 
         if (chunk.error != null) {
           showTopMessage('消息流错误: ${chunk.error}', backgroundColor: Colors.red);
           llmStreamSubscription?.cancel();
           await _finalizeStreamedMessage(targetMessageId, hasError: true);
           return;
         }
 
         if (chunk.isFinished) {
           return;
         }
 
        final accumulatedNewText = chunk.accumulatedText;
        final combinedRawText = initialRawText + accumulatedNewText;
        
        final messageToUpdate = (state.streamingMessage ?? baseMessage).copyWith(
          id: targetMessageId,
          parts: [MessagePart.text(combinedRawText)]
        );

        if (mounted) {
          state = state.copyWith(streamingMessage: messageToUpdate);
        }
       },
       onError: (error) {
         if (mounted) {
           showTopMessage('消息流错误: $error', backgroundColor: Colors.red);
         }
          if (!isFinalizing) {
            _finalizeStreamedMessage(targetMessageId, hasError: true);
          }
       },
       onDone: () async {
         if (!isFinalizing) {
           await _finalizeStreamedMessage(targetMessageId);
         }
       },
       cancelOnError: true,
     );
  }
 
  Future<void> _handleSingleResponse(ApiConfig apiConfig, Message currentUserMessage, String? lastMessageOverride, {int? messageToUpdateId}) async {
    try {
      final coordinator = ref.read(llmCoordinatorProvider);
      final response = await coordinator.generateSingleResponse(
          chatId: chatId,
          apiConfig: apiConfig,
          currentUserMessage: currentUserMessage,
          lastMessageOverride: lastMessageOverride,
      );
      if (!mounted) return;
 
      if (state.isCancelled) return;
      if (response.isSuccess && response.parts.isNotEmpty) {
       state = state.copyWith(clearStreamingMessage: true);
        final messageRepo = ref.read(messageRepositoryProvider);
        final String newContent = response.parts.map((p) => p.text ?? "").join("\n");
        
        Message messageToProcess;

        if (messageToUpdateId != null) {
          final baseMessage = await messageRepo.getMessageById(messageToUpdateId);
          if (baseMessage == null) {
            showTopMessage('无法恢复消息：未找到原始消息', backgroundColor: Colors.red);
            state = state.copyWith(isLoading: false);
            stopUpdateTimer();
            return;
          }
          final StringBuffer combinedBuffer = StringBuffer(baseMessage.rawText);
          if (baseMessage.originalXmlContent != null && baseMessage.originalXmlContent!.isNotEmpty) {
            combinedBuffer.write(baseMessage.originalXmlContent);
          }
          final initialRawText = combinedBuffer.toString();
          final combinedRawText = initialRawText + newContent;
          messageToProcess = baseMessage.copyWith(parts: [MessagePart.text(combinedRawText)]);
        } else {
          messageToProcess = Message(
            chatId: chatId,
            role: MessageRole.model,
            parts: response.parts,
          );
        }
 
        final chat = ref.read(currentChatProvider(chatId)).value;
        if (chat == null) {
          showTopMessage('无法处理消息：聊天数据丢失', backgroundColor: Colors.red);
          return;
        }
        final processedMessage = await getFinalProcessedMessage(chat, messageToProcess);
        if (state.isCancelled) return;

        final savedMessageId = await messageRepo.saveMessage(processedMessage);
        final savedMessage = await messageRepo.getMessageById(savedMessageId);
        
        state = state.copyWith(
          isPrimaryResponseLoading: false,
          clearError: true,
          clearTopMessage: true,
        );

        if (savedMessage != null) {
          if (state.isCancelled) return;
          await runAsyncProcessingTasks(savedMessage);
        } else {
          state = state.copyWith(
            isLoading: false
          );
          stopUpdateTimer();
        }
 
       debugPrint("ChatStateNotifier($chatId): Single response and async tasks finished (ID: $savedMessageId).");
      } else {
       showTopMessage(response.error ?? "发送消息失败 (可能响应为空)", backgroundColor: Colors.red);
       state = state.copyWith(isLoading: false);
     }
    } catch (e) {
      if (mounted) {
        showTopMessage('发送消息时发生意外错误: $e', backgroundColor: Colors.red);
        state = state.copyWith(isLoading: false);
      }
    }
  }

  Future<void> cancelGeneration() async {
    if ((!state.isLoading && !state.isStreaming && !state.isProcessingInBackground && !state.isGeneratingSuggestions) || state.isCancelled) {
      debugPrint("Cancel generation skipped: isLoading=${state.isLoading}, isStreaming=${state.isStreaming}, isProcessingInBackground=${state.isProcessingInBackground}, isGeneratingSuggestions=${state.isGeneratingSuggestions}, isCancelled=${state.isCancelled}");
      return;
    }

    debugPrint("Attempting to cancel generation for chat $chatId...");

    try {
      if (mounted) {
        state = state.copyWith(isCancelled: true);
      }

      await ref.read(llmCoordinatorProvider).cancelGeneration();

      if (llmStreamSubscription != null) {
        await llmStreamSubscription?.cancel();
        llmStreamSubscription = null;
      }

      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          isStreaming: false,
          isProcessingInBackground: false,
          isGeneratingSuggestions: false,
          clearStreaming: true,
          clearStreamingMessage: true,
        );
        stopUpdateTimer();
        showTopMessage("已停止", backgroundColor: Colors.blueGrey);
      }
    } catch (e) {
      debugPrint("Error during cancelGeneration: $e");
      if (mounted) {
        showTopMessage("取消操作时出错: $e", backgroundColor: Colors.red);
      }
    } finally {
      debugPrint("Cancellation process finished for chat $chatId.");
    }
  }

  Future<void> _finalizeStreamedMessage(int messageId, {bool hasError = false}) async {
    if (!mounted || isFinalizing) return;
    
    if (state.isCancelled) {
      isFinalizing = false;
      debugPrint("Finalization skipped for message ID $messageId because task was cancelled.");
      return;
    }

    isFinalizing = true;
    debugPrint("Finalizing stream for message ID $messageId... Has Error: $hasError");

    final messageRepo = ref.read(messageRepositoryProvider);
    final messageToFinalize = state.streamingMessage;
    bool wasRunning = state.isLoading || state.isStreaming;
 
    if (hasError && (messageToFinalize == null || messageToFinalize.rawText.trim().isEmpty || messageToFinalize.rawText == "...")) {
      debugPrint("Stream ended in error with no content. Clearing temporary message.");
      if (mounted) {
        state = state.copyWith(
          isLoading: false, isStreaming: false, clearStreaming: true,
          clearStreamingMessage: true,
        );
        stopUpdateTimer();
      }
      isFinalizing = false;
      return;
    }

    if (messageToFinalize == null) {
      debugPrint("Finalization skipped: No message found in state.");
      isFinalizing = false;
      return;
    }

    Message? finalMessageToSave;
    if (!hasError) {
      if (messageToFinalize.id > 0) {
        finalMessageToSave = messageToFinalize;
      } else {
        finalMessageToSave = Message(
          chatId: messageToFinalize.chatId,
          role: messageToFinalize.role,
          parts: messageToFinalize.parts,
          timestamp: messageToFinalize.timestamp,
        );
      }
    }

    if (mounted) {
      state = state.copyWith(
        isPrimaryResponseLoading: false,
        isStreaming: false,
        clearStreaming: true,
      );
    }

    try {
      final chat = ref.read(currentChatProvider(chatId)).value;
      if (chat != null && finalMessageToSave != null) {
        final processedMessage = await getFinalProcessedMessage(chat, finalMessageToSave);
        if (state.isCancelled) {
          isFinalizing = false;
          return;
        }

        final savedId = await messageRepo.saveMessage(processedMessage);
        final savedMessage = await messageRepo.getMessageById(savedId);
        
        if (savedMessage != null) {
          if (mounted) {
            state = state.copyWith(streamingMessage: savedMessage);
          }

          debugPrint("Running async post-save processing for newly saved message ID $savedId...");
          if (!state.isCancelled) {
            await runAsyncProcessingTasks(savedMessage);
            debugPrint("Async post-save processing for message ID $savedId finished.");
            if (mounted && !state.isCancelled) {
              showTopMessage("已完成", backgroundColor: Colors.green);
            }
          } else {
            debugPrint("Async post-save processing for message ID $savedId skipped due to cancellation.");
          }
        }
      } else if (wasRunning) {
        debugPrint("Skipping async processing: chat or message not available.");
        if (mounted) {
          showTopMessage("已停止", backgroundColor: Colors.blueGrey);
        }
      }
    } catch (e) {
      debugPrint("Error during finalization's post-processing: $e");
      if (mounted) {
        showTopMessage('后台处理任务出错: $e', backgroundColor: Colors.red);
      }
    } finally {
      isFinalizing = false;
      debugPrint("Finalization process finished. isFinalizing reset to false.");
    }
  }
}
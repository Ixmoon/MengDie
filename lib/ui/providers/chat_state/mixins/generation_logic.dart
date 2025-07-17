import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import '../../../../data/models/api_config.dart';
import '../../../../data/models/message.dart';
import '../../../../data/models/enums.dart'; // Added import for MessageRole
import '../../../../service/llmapi/llm_models.dart';
import '../../../../service/llmapi/llm_service.dart';
import '../../../../data/models/chat.dart';
import '../../repository_providers.dart';
import '../../../../data/repositories/message_repository.dart';
import '../chat_screen_state.dart';
import '../chat_data_providers.dart';
import 'ui_state_manager.dart';
import '../../../../service/process/context_xml_service.dart';

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
      
      // 1. 检查是否可以重新生成
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
  
      await cancelGeneration(); // 确保之前的任何生成都已停止
  
      // 2. 删除之前的模型回复
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
          // 短暂延迟以确保数据库更新反映到流中
          await Future.delayed(const Duration(milliseconds: 100));
        }
      } catch (e) {
          showTopMessage('删除旧回复失败: $e', backgroundColor: Colors.red);
          return;
      }
  
      if (!mounted) return;
  
      // 3. 根据当前模式调用正确的生成方法
      clearHelpMeReplySuggestions(); // Clear suggestions before regenerating
      
      if (state.isImageGenerationMode) {
        // 调用图片生成逻辑
        await (this as dynamic).generateImage(userMessage);
      } else {
        // 调用文本生成逻辑
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
    // Branch for image generation
    if (state.isImageGenerationMode && !isRegeneration && !isContinuation) {
      if (userParts != null && userParts.isNotEmpty) {
        final userMessage = Message(
          chatId: chatId,
          role: MessageRole.user,
          parts: userParts,
        );
        // Save user message before calling generateImage
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
    
    // Reset the cancellation state for this new request.
    if (state.isCancelled) {
      state = state.copyWith(isCancelled: false);
    }
    
    final chat = ref.read(currentChatProvider(chatId)).value;
    if (chat == null) {
      showTopMessage('无法发送消息：聊天数据未加载。', backgroundColor: Colors.red);
      return;
    }

    // Determine the message to send for context, and the list of messages to save
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
      // A single user turn can contain multiple parts (e.g., text and an image).
      // These should be combined into a single Message object to represent one turn.
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

    // --- Start loading state ---
    state = state.copyWith(
        isLoading: true, // Master lock ON
        isPrimaryResponseLoading: true, // Primary response lock ON
        isCancelled: false, // Ensure cancellation is reset when starting
        clearError: true,
        clearTopMessage: true,
        clearStreaming: true,
        clearHelpMeReplySuggestions: true,
        clearStreamingMessage: true, // Clear any previous leftovers
        generationStartTime: DateTime.now(),
    );
    startUpdateTimer();
    
    // --- Save new user messages (if not regenerating or continuing) ---
    if (!isRegeneration && !isContinuation) {
      try {
        final messageRepo = ref.read(messageRepositoryProvider);
        await messageRepo.saveMessages(messagesToSave); // Batch save
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

    // --- Build API context ---
    List<LlmContent> llmApiContext;
    String? carriedOverXmlForThisTurn;
    try {
      final contextXmlService = ref.read(contextXmlServiceProvider);
      
      String? lastMessageOverride;

      if (promptOverride != null) {
        lastMessageOverride = promptOverride;
        debugPrint("sendMessage: 使用了 promptOverride。");
      } else if (isContinuation && (chat.continuePrompt?.isNotEmpty ?? false)) {
        lastMessageOverride = chat.continuePrompt;
        // For continuation, we keep the original system prompt.
        // The line clearing it has been removed.
        debugPrint("续写操作：将续写提示词作为最后的用户消息。");
      }

      final apiRequestContext = await contextXmlService.buildApiRequestContext(
        chatId: chatId,
        currentUserMessage: messageForContext, // Pass the representative message for context
        lastMessageOverride: lastMessageOverride,
        // For standard chat, regeneration, and continuation, always keep the original system prompt.
        keepAsSystemPrompt: true,
      );
      
      llmApiContext = apiRequestContext.contextParts;
      carriedOverXmlForThisTurn = apiRequestContext.carriedOverXml;

    } catch (e) {
        debugPrint("ChatStateNotifier:sendMessage($chatId): 构建 API 上下文时出错: $e");
        if (mounted) {
          showTopMessage('构建请求上下文失败: $e', backgroundColor: Colors.red);
          state = state.copyWith(isLoading: false);
          stopUpdateTimer();
        }
        return;
     }

     final llmService = ref.read(llmServiceProvider);

     // 重构：LlmService 不再处理配置逻辑，由 Notifier 决定
    final apiConfig = getEffectiveApiConfig(specificConfigId: apiConfigIdOverride);
    
    if (state.isStreamMode) {
        await _handleStreamResponse(llmService, apiConfig, llmApiContext, messageToUpdateId: messageToUpdateId);
    } else {
        await _handleSingleResponse(llmService, apiConfig, llmApiContext, carriedOverXmlForThisTurn, messageToUpdateId: messageToUpdateId);
    }
   }

  Future<void> _handleStreamResponse(LlmService llmService, ApiConfig apiConfig, List<LlmContent> llmContext, {int? messageToUpdateId}) async {
    final messageRepo = ref.read(messageRepositoryProvider);
   int targetMessageId; // Will be a temporary negative ID or a real one for resume
    Message baseMessage;
    String initialRawText = '';

    if (messageToUpdateId != null) {
      // This is a resume/continue action for an existing message.
      targetMessageId = messageToUpdateId;
      final msg = await messageRepo.getMessageById(targetMessageId);
      if (msg == null) {
        showTopMessage('无法恢复消息：未找到原始消息', backgroundColor: Colors.red);
        state = state.copyWith(isLoading: false);
        stopUpdateTimer();
        return;
      }
      baseMessage = msg;
      // 恢复时，将原始文本和XML内容结合起来，以确保新内容正确追加。
      final StringBuffer combinedBuffer = StringBuffer(baseMessage.rawText);
      if (baseMessage.originalXmlContent != null && baseMessage.originalXmlContent!.isNotEmpty) {
        combinedBuffer.write(baseMessage.originalXmlContent);
      }
      initialRawText = combinedBuffer.toString();
    } else {
      // This is a new message. Do not save to DB. Create a temporary in-memory message.
      // Use a unique negative ID for the key to avoid conflicts with real DB IDs.
      targetMessageId = -DateTime.now().millisecondsSinceEpoch;
      baseMessage = Message(
        id: targetMessageId, // Assign temporary negative ID
        chatId: chatId,
        role: MessageRole.model,
        parts: [MessagePart.text("...")], // Start with a placeholder text
      );
      debugPrint("ChatStateNotifier($chatId): Created temporary streaming message with ID: $targetMessageId.");
    }
 
    // The streaming message is now stored in the state, not the DB.
    // Create the initial placeholder message in the state.
    state = state.copyWith(
      streamingMessage: baseMessage,
      isStreamingMessageVisible: true,
      isStreaming: true,
    );
 
     final stream = llmService.sendMessageStream(llmContext: llmContext, apiConfig: apiConfig);
     llmStreamSubscription?.cancel();
     llmStreamSubscription = stream.listen(
       (chunk) async {
         if (!mounted) return;
 
         if (chunk.error != null) {
           showTopMessage('消息流错误: ${chunk.error}', backgroundColor: Colors.red);
           // On error, we still finalize to save what we have and clean up.
           llmStreamSubscription?.cancel();
           await _finalizeStreamedMessage(targetMessageId, hasError: true);
           return;
         }
 
         if (chunk.isFinished) {
           // This chunk signals the end, but onDone is the sole handler for finalization.
           return;
         }
 
        // --- Live Update Logic (State only) ---
        final accumulatedNewText = chunk.accumulatedText;
        final combinedRawText = initialRawText + accumulatedNewText;
        
        // Update the message object in the state, not the database.
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
         // onDone is the single source of truth for saving a completed or canceled stream.
         if (!isFinalizing) {
           await _finalizeStreamedMessage(targetMessageId);
         }
       },
       cancelOnError: true,
     );
  }
 
  Future<void> _handleSingleResponse(LlmService llmService, ApiConfig apiConfig, List<LlmContent> llmContext, String? initialCarriedOverXml, {int? messageToUpdateId}) async {
    try {
      final response = await llmService.sendMessageOnce(llmContext: llmContext, apiConfig: apiConfig);
      if (!mounted) return;
 
      if (state.isCancelled) return; // Check for cancellation after response
      if (response.isSuccess && response.parts.isNotEmpty) {
       state = state.copyWith(clearStreamingMessage: true); // Ensure no streaming leftovers
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
          // 恢复时，将原始文本和XML内容结合起来，以确保新内容正确追加。
          final StringBuffer combinedBuffer = StringBuffer(baseMessage.rawText);
          if (baseMessage.originalXmlContent != null && baseMessage.originalXmlContent!.isNotEmpty) {
            combinedBuffer.write(baseMessage.originalXmlContent);
          }
          final initialRawText = combinedBuffer.toString();
          final combinedRawText = initialRawText + newContent;
          // 我们将完整的合并文本暂时放入parts中，后续处理会分离它们
          messageToProcess = baseMessage.copyWith(parts: [MessagePart.text(combinedRawText)]);
        } else {
          messageToProcess = Message(
            chatId: chatId,
            role: MessageRole.model,
            parts: response.parts,
          );
        }
 
        // 2. Process the message in-memory *before* saving.
        final chat = ref.read(currentChatProvider(chatId)).value;
        if (chat == null) {
          showTopMessage('无法处理消息：聊天数据丢失', backgroundColor: Colors.red);
          return;
        }
        final processedMessage = await getFinalProcessedMessage(chat, messageToProcess);
        if (state.isCancelled) return; // Check after processing

        // 3. Save the fully processed message to the database ONCE.
        final savedMessageId = await messageRepo.saveMessage(processedMessage);
        final savedMessage = await messageRepo.getMessageById(savedMessageId);
        
        // 4. The primary response is "done". Turn off its specific lock.
        //    Keep the master `isLoading` lock on for background tasks.
        state = state.copyWith(
          isPrimaryResponseLoading: false,
          clearError: true,
          clearTopMessage: true,
        );

        // 5. Asynchronously run post-save tasks on the saved message.
        if (savedMessage != null) {
          if (state.isCancelled) return; // Final check before starting background tasks
          await runAsyncProcessingTasks(savedMessage);
        } else {
          // If there's no message, ensure loading state is cleared.
          state = state.copyWith(
            isLoading: false
          );
          stopUpdateTimer();
        }
 
       debugPrint("ChatStateNotifier($chatId): Single response and async tasks finished (ID: $savedMessageId).");
       // calculateAndStoreTokenCount(); // Recalculate tokens based on initial saved message. - REMOVED: The listener in MessageList will handle this.
      } else {
       showTopMessage(response.error ?? "发送消息失败 (可能响应为空)", backgroundColor: Colors.red);
       state = state.copyWith(isLoading: false);
     }
    } catch (e) {
      if (mounted) {
        showTopMessage('发送消息时发生意外错误: $e', backgroundColor: Colors.red);
        state = state.copyWith(isLoading: false);
      }
    } finally {
      // No need for a finally block to stop the timer, as it's stopped on success.
    }
  }

  Future<void> cancelGeneration() async {
    // If nothing is running, or it's already cancelled, do nothing.
    if ((!state.isLoading && !state.isStreaming && !state.isProcessingInBackground && !state.isGeneratingSuggestions) || state.isCancelled) {
      debugPrint("Cancel generation skipped: isLoading=${state.isLoading}, isStreaming=${state.isStreaming}, isProcessingInBackground=${state.isProcessingInBackground}, isGeneratingSuggestions=${state.isGeneratingSuggestions}, isCancelled=${state.isCancelled}");
      return;
    }

    debugPrint("Attempting to cancel generation for chat $chatId...");

    try {
      // 1. Set the cancellation flag in the state. This is the new source of truth.
      if (mounted) {
        state = state.copyWith(isCancelled: true);
      }

      // 2. Cancel any active LLM request (covers main stream and background tasks)
      await ref.read(llmServiceProvider).cancelActiveRequest();

      // 3. Cancel the stream subscription if it exists.
      // This will trigger its onDone/onError, which will see the isCancelled flag and stop.
      if (llmStreamSubscription != null) {
        await llmStreamSubscription?.cancel();
        llmStreamSubscription = null;
      }

      // 4. Finalize state immediately for instant UI feedback.
      // The async tasks will check the `isCancelled` state flag and stop themselves.
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          isStreaming: false,
          isProcessingInBackground: false,
          isGeneratingSuggestions: false, // Also clear this flag
          clearStreaming: true,
          clearStreamingMessage: true, // Also clear the cached message
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
    
    // CRITICAL: If cancellation was requested, stop all finalization and post-processing.
    if (state.isCancelled) {
      isFinalizing = false; // Release lock
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

    // 1. Create a new message object for saving, stripping the temporary ID.
    // This happens only on successful completion.
    Message? finalMessageToSave;
    if (!hasError) {
      if (messageToFinalize.id > 0) {
        // This is an update to an existing message.
        finalMessageToSave = messageToFinalize;
      } else {
        // This is a new message. Create a new object without the temporary negative ID.
        finalMessageToSave = Message(
          chatId: messageToFinalize.chatId,
          role: messageToFinalize.role,
          parts: messageToFinalize.parts,
          timestamp: messageToFinalize.timestamp,
        );
      }
    }

    // 2. The primary response (stream) is "done". Turn off its specific lock.
    //    Keep the master `isLoading` lock on for background tasks.
    if (mounted) {
      state = state.copyWith(
        isPrimaryResponseLoading: false,
        isStreaming: false,
        clearStreaming: true,
        // CRITICAL: Do NOT clear isLoading or the streaming message here.
      );
    }

    // 3. Now, with the main state cleared, run async pre-save and post-save processing.
    try {
      final chat = ref.read(currentChatProvider(chatId)).value;
      if (chat != null && finalMessageToSave != null) {
        // 3a. Process the message in-memory BEFORE saving.
        final processedMessage = await getFinalProcessedMessage(chat, finalMessageToSave);
        if (state.isCancelled) {
          isFinalizing = false;
          return;
        }

        // 3b. Save the fully processed message to the database ONCE.
        final savedId = await messageRepo.saveMessage(processedMessage);
        final savedMessage = await messageRepo.getMessageById(savedId);
        
        // 3c. Run post-save async tasks.
        if (savedMessage != null) {
          // CRITICAL: Update the state's streamingMessage with the one from the DB.
          // This "promotes" the temporary message to a persistent one with a real ID,
          // ensuring a seamless transition in the UI.
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
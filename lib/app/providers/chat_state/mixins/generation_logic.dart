import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import '../../../../domain/models/api_config.dart';
import '../../../../domain/models/message.dart';
import '../../../../domain/enums.dart'; // Added import for MessageRole
import '../../../../data/llmapi/llm_models.dart';
import '../../../../data/llmapi/llm_service.dart';
import '../../../../domain/models/chat.dart';
import '../../repository_providers.dart';
import '../../../repositories/message_repository.dart';
import '../chat_screen_state.dart';
import '../chat_data_providers.dart';

import '../../../tools/context_xml_service.dart';

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
        await sendMessage(userMessage: userMessage, isRegeneration: true, requestThoughts: true);
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
    bool forceNonStreaming = false, // New parameter to override stream mode
    bool requestThoughts = false,
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
        clearCarriedOverXml: true, // Clear previous XML at the start of a new message
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
      
      // 将计算出的XML暂存到状态中，以便UI可以显示它
      if (mounted) {
        state = state.copyWith(carriedOverXml: carriedOverXmlForThisTurn);
      }

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
    
    // Use the new parameter to override the stream mode check when needed.
    final bool shouldUseStream = state.isStreamMode && !forceNonStreaming;

    if (shouldUseStream) {
        await _handleStreamResponse(llmService, apiConfig, llmApiContext, requestThoughts: requestThoughts, messageToUpdateId: messageToUpdateId);
    } else {
        await _handleSingleResponse(llmService, apiConfig, llmApiContext, carriedOverXmlForThisTurn, requestThoughts: requestThoughts, messageToUpdateId: messageToUpdateId);
    }
   }

  Future<void> _handleStreamResponse(LlmService llmService, ApiConfig apiConfig, List<LlmContent> llmContext, {required bool requestThoughts, int? messageToUpdateId}) async {
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
 
     final stream = llmService.sendMessageStream(llmContext: llmContext, apiConfig: apiConfig, requestThoughts: requestThoughts);
     llmStreamSubscription?.cancel();
     llmStreamSubscription = stream.listen(
       (chunk) async {
         if (!mounted) return;

         switch (chunk.type) {
           case LlmStreamChunkType.text:
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
             break;
           
           case LlmStreamChunkType.error:
             showTopMessage('消息流错误: ${chunk.error}', backgroundColor: Colors.red);
             if (!isFinalizing) {
               await _finalizeStreamedMessage(targetMessageId, hasError: true);
             }
             break;

           case LlmStreamChunkType.finish_reason:
             showTopMessage('输出因 ${chunk.textChunk} 而中断', backgroundColor: Colors.orange);
             // We still finalize normally, as this is a known termination reason.
             if (!isFinalizing) {
               await _finalizeStreamedMessage(targetMessageId);
             }
             break;
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
           await _finalizeStreamedMessage(targetMessageId, isCancelled: state.isCancelled);
         }
       },
       cancelOnError: true,
     );
  }
 Future<void> _handleSingleResponse(LlmService llmService, ApiConfig apiConfig, List<LlmContent> llmContext, String? initialCarriedOverXml, {required bool requestThoughts, int? messageToUpdateId}) async {
   try {
     final response = await llmService.sendMessageOnce(llmContext: llmContext, apiConfig: apiConfig, requestThoughts: requestThoughts);
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
    if ((!state.isLoading && !state.isStreaming && !state.isProcessingInBackground && !state.isGeneratingSuggestions) || state.isCancelled) {
      debugPrint("Cancel generation skipped: isLoading=${state.isLoading}, isStreaming=${state.isStreaming}, isProcessingInBackground=${state.isProcessingInBackground}, isGeneratingSuggestions=${state.isGeneratingSuggestions}, isCancelled=${state.isCancelled}");
      return;
    }

    debugPrint("Attempting to cancel generation for chat $chatId...");

    // 1. Set the cancellation flag. This is the primary source of truth.
    if (mounted) {
      state = state.copyWith(isCancelled: true);
    }

    try {
      // 2. Cancel any active network/API request.
      await ref.read(llmServiceProvider).cancelActiveRequest();

      // 3. Cancel the Dart stream subscription. This is crucial.
      // It will trigger the `onDone` or `onError` callback in the stream listener.
      await llmStreamSubscription?.cancel();
      llmStreamSubscription = null;

      // 4. Delegate finalization to the now-triggered onDone/onError handler.
      // The handler will see `isCancelled` is true and save the partial message.
      // We pass the temporary message ID if available.
      final tempMessageId = state.streamingMessage?.id;
      // Regardless of whether there was a streaming message or not,
      // we must reset all loading states.
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          isStreaming: false,
          isPrimaryResponseLoading: false,
          isProcessingInBackground: false,
          isGeneratingSuggestions: false, // <-- CRITICAL FIX: Reset this state as well.
          isCancelled: false, // Reset cancellation flag after handling
        );
        stopUpdateTimer();
        showTopMessage("已停止", backgroundColor: Colors.blueGrey);
      }
      
      // If there was a streaming message, we still need to finalize it to save partial progress.
      if (tempMessageId != null) {
        await _finalizeStreamedMessage(tempMessageId, isCancelled: true);
      }
    } catch (e) {
      debugPrint("Error during cancelGeneration: $e");
      if (mounted) {
        showTopMessage("取消操作时出错: $e", backgroundColor: Colors.red);
        // Ensure state is cleaned up even on error
        state = state.copyWith(isLoading: false, isStreaming: false, isProcessingInBackground: false, isGeneratingSuggestions: false);
        stopUpdateTimer();
      }
    } finally {
      debugPrint("Cancellation process finished for chat $chatId.");
    }
  }

  Future<void> _finalizeStreamedMessage(int messageId, {bool hasError = false, bool isCancelled = false}) async {
    if (!mounted || isFinalizing) return;
    isFinalizing = true;

    // Use the isCancelled parameter OR the state flag. The parameter is more immediate.
    final bool wasCancelled = isCancelled || state.isCancelled;
    debugPrint("Finalizing stream for message ID $messageId... Has Error: $hasError, Was Cancelled: $wasCancelled");

    final messageRepo = ref.read(messageRepositoryProvider);
    final messageToFinalize = state.streamingMessage;

    // If there's no content and it wasn't a successful stream, just clean up.
    if (messageToFinalize == null || messageToFinalize.rawText.trim().isEmpty || messageToFinalize.rawText == "...") {
      if (hasError || wasCancelled) {
        debugPrint("Stream ended with no content due to error or cancellation. Clearing state.");
        if (mounted) {
          state = state.copyWith(
            isLoading: false,
            isStreaming: false,
            isPrimaryResponseLoading: false,
            isProcessingInBackground: false,
            clearStreaming: true,
            clearStreamingMessage: true,
          );
          stopUpdateTimer();
        }
        isFinalizing = false;
        return;
      }
    }
    
    if (messageToFinalize == null) {
      debugPrint("Finalization skipped: No message found in state.");
      // Still need to clean up the loading state if something was running.
      if (mounted) {
        state = state.copyWith(isLoading: false, isStreaming: false, isPrimaryResponseLoading: false);
        stopUpdateTimer();
      }
      isFinalizing = false;
      return;
    }

    // The primary response part is done (stream ended/cancelled/errored).
    if (mounted) {
      state = state.copyWith(
        isPrimaryResponseLoading: false,
        isStreaming: false,
        clearStreaming: true,
      );
    }

    try {
      final chat = ref.read(currentChatProvider(chatId)).value;
      if (chat != null) {
        // Process the message in-memory BEFORE saving.
        // For cancelled messages, we still process to handle any partial XML.
        final processedMessage = await getFinalProcessedMessage(chat, messageToFinalize);

        // Save the fully processed message to the database.
        final savedId = await messageRepo.saveMessage(processedMessage);
        final savedMessage = await messageRepo.getMessageById(savedId);

        if (savedMessage != null) {
          // "Promote" the temporary message to a persistent one in the state.
          if (mounted) {
            state = state.copyWith(streamingMessage: savedMessage);
          }

          // Run post-save tasks ONLY if the stream completed successfully.
          if (!wasCancelled && !hasError) {
            debugPrint("Running async post-save processing for newly saved message ID $savedId...");
            await runAsyncProcessingTasks(savedMessage);
            debugPrint("Async post-save processing for message ID $savedId finished.");
            // 只有在流正常成功结束后才显示“已完成”。
            // 如果是因为错误、取消或已知的“中断原因”而结束，则不显示此消息，
            // 以免覆盖掉之前已经显示的更具体的信息。
            if (mounted && !state.isCancelled && !hasError) {
              showTopMessage("已完成", backgroundColor: Colors.green);
            }
          } else {
            debugPrint("Async post-save processing for message ID $savedId skipped due to cancellation or error.");
          }
        }
      } else {
        debugPrint("Skipping message save/processing: chat not available.");
      }
    } catch (e) {
      debugPrint("Error during finalization's post-processing: $e");
      if (mounted) {
        showTopMessage('后台处理任务出错: $e', backgroundColor: Colors.red);
      }
    } finally {
      // Final state cleanup, regardless of success or failure.
      if (mounted) {
        state = state.copyWith(
          isLoading: false, // Master lock OFF
          isProcessingInBackground: false,
          isStreamingMessageVisible: false, // Hide the temp message
          isCancelled: false, // Reset cancellation flag for the next run
        );
        stopUpdateTimer();
      }
      isFinalizing = false;
      debugPrint("Finalization process finished. isFinalizing reset to false.");
    }
  }
}
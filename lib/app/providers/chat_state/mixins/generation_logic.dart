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
import '../../settings_providers.dart';
import '../../../tools/context_xml_service.dart';

mixin GenerationLogic on StateNotifier<ChatScreenState> {
  // Abstract properties to be implemented by the main class
  Ref get ref;
  int get chatId;
  StreamSubscription<LlmStreamChunk>? get llmStreamSubscription;
  set llmStreamSubscription(StreamSubscription<LlmStreamChunk>? value);
  Timer? get pseudoStreamTimer;
  set pseudoStreamTimer(Timer? value);

  // Abstract methods to be implemented by other mixins or the main class
  ApiConfig getEffectiveApiConfig({String? specificConfigId});
  Future<void> runAsyncProcessingTasks(Message modelMessage);
  Future<Message> getFinalProcessedMessage(Chat chat, Message initialMessage);
  void clearHelpMeReplySuggestions();
  // Methods from UiStateManager that are used here
  void showTopMessage(
    String text, {
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 3),
  });
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
      await sendMessage(
        userMessage: userMessage,
        isRegeneration: true,
        requestThoughts: true,
      );
    }
  }

  Future<void> continueGeneration() async {
    if (state.isLoading) {
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
      return;
    }

    // Reset the cancellation state for this new request.
    if (state.isCancelled) {
      state = state.copyWith(isCancelled: false);
    }

    Chat? chat = ref.read(currentChatProvider(chatId)).value;
    if (chat == null) {
      showTopMessage('无法发送消息：聊天数据未加载。', backgroundColor: Colors.red);
      return;
    }

    // --- 前台门卫：在发送前进行精确的上下文检查和阻塞式总结 ---
    try {
      // 1. 如果后台正在总结，等待它完成
      if (state.isSummarizing) {
        showTopMessage("正在等待后台总结完成...", duration: const Duration(seconds: 120));
        while (state.isSummarizing && mounted) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
        showTopMessage("后台总结已完成。", backgroundColor: Colors.green);
      }

      // 2. 进行一次精确的、同步的发送前检查
      final contextXmlService = ref.read(contextXmlServiceProvider);
      final predictionResult = await contextXmlService.predictContextUsage(
        chatId: chatId,
      );

      // 3. 如果预测仍然会超限，触发一次阻塞式总结
      if (predictionResult.willExceed) {
        showTopMessage(
          "上下文已满，正在强制同步总结...",
          duration: const Duration(seconds: 120),
        );
        // 直接调用并等待后台任务中的总结逻辑完成
        final updatedChat = await (this as dynamic).executePreprocessing(chat);
        showTopMessage("强制总结已完成。", backgroundColor: Colors.green);

        // 关键修复：使用 executePreprocessing 返回的更新后的 chat 对象
        if (updatedChat != null) {
          chat = updatedChat;
        }

        if (chat == null) {
          showTopMessage('无法发送消息：总结后聊天数据丢失。', backgroundColor: Colors.red);
          return;
        }
      }
    } catch (e) {
      showTopMessage("发送前检查出错: $e", backgroundColor: Colors.red);
      state = state.copyWith(isLoading: false); // Release lock on error
      return;
    }
    // --- 前台门卫检查结束 ---

    // Determine the message to send for context, and the list of messages to save
    Message messageForContext;
    List<Message> messagesToSave = [];

    if (isRegeneration && userMessage != null) {
      messageForContext = userMessage;
    } else if (isContinuation) {
      final allMessages = ref.read(chatMessagesProvider(chatId)).value ?? [];
      if (allMessages.isEmpty) return;
      messageForContext = allMessages.last;
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
      clearCarriedOverXml:
          true, // Clear previous XML at the start of a new message
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
      } catch (e) {
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
      } else if (isContinuation && (chat.continuePrompt?.isNotEmpty ?? false)) {
        lastMessageOverride = chat.continuePrompt;
        // For continuation, we keep the original system prompt.
        // The line clearing it has been removed.
      }

      // --- 修正中断恢复的上下文构建逻辑 ---
      // 根据最新的设计原则，“中断恢复”是一个半偏离任务，需要临时替换系统提示词以专注于修复任务。
      final globalSettings = ref.read(globalSettingsProvider);
      final isResumeTask = isContinuation &&
          promptOverride != null &&
          promptOverride == globalSettings.resumePrompt;

      final apiRequestContext = await contextXmlService.buildApiRequestContext(
        chatId: chatId,
        currentUserMessage:
            messageForContext, // Pass the representative message for context
        lastMessageOverride: lastMessageOverride,
        // 如果是中断恢复任务，则执行“替换+降级”策略
        chatSystemPromptOverride: isResumeTask ? promptOverride : null,
        keepAsSystemPrompt: !isResumeTask,
      );

      llmApiContext = apiRequestContext.contextParts;
      carriedOverXmlForThisTurn = apiRequestContext.carriedOverXml;

      // 将计算出的XML暂存到状态中，以便UI可以显示它
      if (mounted) {
        state = state.copyWith(carriedOverXml: carriedOverXmlForThisTurn);
      }
    } catch (e) {
      if (mounted) {
        showTopMessage('构建请求上下文失败: $e', backgroundColor: Colors.red);
        state = state.copyWith(isLoading: false);
        stopUpdateTimer();
      }
      return;
    }

    final llmService = ref.read(llmServiceProvider);

    // 重构：LlmService 不再处理配置逻辑，由 Notifier 决定
    final apiConfig = getEffectiveApiConfig(
      specificConfigId: apiConfigIdOverride,
    );

    // Corrected Logic: Differentiate between real streaming and simulated streaming.
    final bool shouldUseRealStream = state.isStreamMode && !forceNonStreaming;
    final bool shouldUsePseudoStreamSimulation =
        !shouldUseRealStream && state.isPseudoStreamMode;

    if (shouldUseRealStream) {
      // Case 1: Real streaming from API.
      // The UI layer (MessageBubble) will use _TypewriterText for animation
      // if isPseudoStreamMode is also true, acting as a buffer/smoother.
      await _handleStreamResponse(
        llmService,
        apiConfig,
        llmApiContext,
        requestThoughts: requestThoughts,
        messageToUpdateId: messageToUpdateId,
        isGoogleSearchEnabled: state.isGoogleSearchEnabled,
        isUrlContextEnabled: state.isUrlContextEnabled,
        isCodeExecutionEnabled: state.isCodeExecutionEnabled,
      );
    } else if (shouldUsePseudoStreamSimulation) {
      // Case 2: No real stream, but pseudo-stream is on.
      // We get the full response once, then simulate the typing animation.
      await _handlePseudoStreamResponse(
        llmService,
        apiConfig,
        llmApiContext,
        requestThoughts: requestThoughts,
        messageToUpdateId: messageToUpdateId,
        isGoogleSearchEnabled: state.isGoogleSearchEnabled,
        isUrlContextEnabled: state.isUrlContextEnabled,
        isCodeExecutionEnabled: state.isCodeExecutionEnabled,
      );
    } else {
      // Case 3: Standard single-shot response, no streaming or animation.
      await _handleSingleResponse(
        llmService,
        apiConfig,
        llmApiContext,
        carriedOverXmlForThisTurn,
        requestThoughts: requestThoughts,
        messageToUpdateId: messageToUpdateId,
        isGoogleSearchEnabled: state.isGoogleSearchEnabled,
        isUrlContextEnabled: state.isUrlContextEnabled,
        isCodeExecutionEnabled: state.isCodeExecutionEnabled,
      );
    }
  }

  Future<void> _handleStreamResponse(
    LlmService llmService,
    ApiConfig apiConfig,
    List<LlmContent> llmContext, {
    required bool requestThoughts,
    int? messageToUpdateId,
    required bool isGoogleSearchEnabled,
    required bool isUrlContextEnabled,
    required bool isCodeExecutionEnabled,
  }) async {
    final messageRepo = ref.read(messageRepositoryProvider);
    Message? messageToUpdate;

    // --- Step 1: Create placeholder and set it as the UI-controlled message ---
    try {
      if (messageToUpdateId != null) {
        messageToUpdate = await messageRepo.getMessageById(messageToUpdateId);
        if (messageToUpdate == null) throw Exception("Original message not found.");
      } else {
        final placeholder = Message(
          chatId: chatId,
          role: MessageRole.model,
          parts: [MessagePart.text("...")],
        );
        final newId = await messageRepo.saveMessage(placeholder);
        messageToUpdate = placeholder.copyWith(id: newId);
      }
      // Immediately set this message as the one controlled by the UI.
      state = state.copyWith(
        uiControlledMessage: messageToUpdate,
        isStreaming: true,
      );
    } catch (e) {
      showTopMessage('无法创建占位消息: $e', backgroundColor: Colors.red);
      _finalizeResponse(null, hasError: true);
      return;
    }

    final stream = llmService.sendMessageStream(
      llmContext: llmContext,
      apiConfig: apiConfig,
      requestThoughts: requestThoughts,
      isGoogleSearchEnabled: isGoogleSearchEnabled,
      isUrlContextEnabled: isUrlContextEnabled,
      isCodeExecutionEnabled: isCodeExecutionEnabled,
    );

    llmStreamSubscription?.cancel();
    llmStreamSubscription = stream.listen(
      (chunk) {
        if (!mounted || state.isCancelled) return;

        if (chunk.type == LlmStreamChunkType.text) {
          // --- Live Update Logic (UI State only) ---
          final updatedMessage = state.uiControlledMessage?.copyWith(
            parts: [MessagePart.text(chunk.accumulatedText)],
          );
          if (updatedMessage != null) {
            state = state.copyWith(uiControlledMessage: updatedMessage);
          }
        } else if (chunk.type == LlmStreamChunkType.error) {
          showTopMessage('消息流错误: ${chunk.error}', backgroundColor: Colors.red);
        } else if (chunk.type == LlmStreamChunkType.finishReason) {
          showTopMessage('输出因 ${chunk.textChunk} 而中断', backgroundColor: Colors.orange);
        }
      },
      onError: (error) {
        if (mounted) {
          showTopMessage('消息流错误: $error', backgroundColor: Colors.red);
        }
        _finalizeResponse(state.uiControlledMessage, hasError: true);
      },
      onDone: () {
        _finalizeResponse(state.uiControlledMessage, isCancelled: state.isCancelled);
      },
      cancelOnError: true,
    );
  }

  Future<void> _handleSingleResponse(
    LlmService llmService,
    ApiConfig apiConfig,
    List<LlmContent> llmContext,
    String? initialCarriedOverXml, {
    required bool requestThoughts,
    int? messageToUpdateId,
    required bool isGoogleSearchEnabled,
    required bool isUrlContextEnabled,
    required bool isCodeExecutionEnabled,
  }) async {
    Message? messageToUpdate;
    try {
      // --- Step 1: Create placeholder and set it as the UI-controlled message ---
      final messageRepo = ref.read(messageRepositoryProvider);
      if (messageToUpdateId != null) {
        messageToUpdate = await messageRepo.getMessageById(messageToUpdateId);
        if (messageToUpdate == null) throw Exception("Original message not found.");
      } else {
        final placeholder = Message(
          chatId: chatId,
          role: MessageRole.model,
          parts: [MessagePart.text("...")],
        );
        final newId = await messageRepo.saveMessage(placeholder);
        messageToUpdate = placeholder.copyWith(id: newId);
      }
      state = state.copyWith(uiControlledMessage: messageToUpdate);

      // --- Step 2: Fetch the actual response ---
      final response = await llmService.sendMessageOnce(
        llmContext: llmContext,
        apiConfig: apiConfig,
        requestThoughts: requestThoughts,
        isGoogleSearchEnabled: isGoogleSearchEnabled,
        isUrlContextEnabled: isUrlContextEnabled,
        isCodeExecutionEnabled: isCodeExecutionEnabled,
      );
      if (!mounted) return;

      if (state.isCancelled) {
        _finalizeResponse(state.uiControlledMessage, isCancelled: true);
        return;
      }

      if (response.isSuccess && response.parts.isNotEmpty) {
        final String newContent = response.parts.map((p) => p.text ?? "").join("\n");
        final finalMessage = state.uiControlledMessage?.copyWith(
          parts: [MessagePart.text(newContent)],
        );
        // Update the UI state with the final content before finalizing.
        state = state.copyWith(uiControlledMessage: finalMessage);
        _finalizeResponse(finalMessage);
      } else {
        showTopMessage(response.error ?? "发送消息失败 (可能响应为空)", backgroundColor: Colors.red);
        _finalizeResponse(state.uiControlledMessage, hasError: true);
      }
    } catch (e) {
      if (mounted) {
        showTopMessage('发送消息时发生意外错误: $e', backgroundColor: Colors.red);
      }
      _finalizeResponse(state.uiControlledMessage, hasError: true);
    }
  }

  Future<void> _handlePseudoStreamResponse(
    LlmService llmService,
    ApiConfig apiConfig,
    List<LlmContent> llmContext, {
    required bool requestThoughts,
    int? messageToUpdateId,
    required bool isGoogleSearchEnabled,
    required bool isUrlContextEnabled,
    required bool isCodeExecutionEnabled,
  }) async {
    Message? messageToUpdate;

    // --- Step 1: Create placeholder and set it as the UI-controlled message ---
    try {
      final messageRepo = ref.read(messageRepositoryProvider);
      if (messageToUpdateId != null) {
        messageToUpdate = await messageRepo.getMessageById(messageToUpdateId);
        if (messageToUpdate == null) throw Exception("Original message not found.");
      } else {
        final placeholder = Message(
          chatId: chatId,
          role: MessageRole.model,
          parts: [MessagePart.text("...")],
        );
        final newId = await messageRepo.saveMessage(placeholder);
        messageToUpdate = placeholder.copyWith(id: newId);
      }
      state = state.copyWith(
        uiControlledMessage: messageToUpdate,
        isStreaming: true,
      );
    } catch (e) {
      showTopMessage('无法创建伪流式占位消息: $e', backgroundColor: Colors.red);
      _finalizeResponse(null, hasError: true);
      return;
    }

    // --- Step 2: Get the full response first ---
    final response = await llmService.sendMessageOnce(
      llmContext: llmContext,
      apiConfig: apiConfig,
      requestThoughts: requestThoughts,
      isGoogleSearchEnabled: isGoogleSearchEnabled,
      isUrlContextEnabled: isUrlContextEnabled,
      isCodeExecutionEnabled: isCodeExecutionEnabled,
    );

    if (!mounted || state.isCancelled) {
      _finalizeResponse(state.uiControlledMessage, isCancelled: true);
      return;
    }

    if (!response.isSuccess || response.parts.isEmpty) {
      showTopMessage(response.error ?? "伪流式获取响应失败", backgroundColor: Colors.red);
      _finalizeResponse(state.uiControlledMessage, hasError: true);
      return;
    }

    // --- Step 3: Animate the text update in the UI state ---
    final fullText = response.parts.map((p) => p.text ?? "").join("\n");
    int charIndex = 0;
    const baseDelay = 50;
    final delay = (baseDelay / state.pseudoStreamSpeed).clamp(10, 500).toInt();

    pseudoStreamTimer?.cancel();
    pseudoStreamTimer = Timer.periodic(Duration(milliseconds: delay), (timer) {
      if (!mounted || state.isCancelled) {
        timer.cancel();
        _finalizeResponse(state.uiControlledMessage, isCancelled: true);
        return;
      }

      if (charIndex < fullText.length) {
        charIndex++;
        final displayedText = fullText.substring(0, charIndex);
        final updatedMessage = state.uiControlledMessage?.copyWith(
          parts: [MessagePart.text(displayedText)],
        );
        if (updatedMessage != null) {
          state = state.copyWith(uiControlledMessage: updatedMessage);
        }
      } else {
        timer.cancel();
        // Ensure the final text is set before finalizing
        final finalMessage = state.uiControlledMessage?.copyWith(
          parts: [MessagePart.text(fullText)],
        );
        state = state.copyWith(uiControlledMessage: finalMessage);
        _finalizeResponse(finalMessage);
      }
    });
  }

  Future<void> cancelGeneration() async {
    if ((!state.isLoading && !state.isStreaming && !state.isProcessingInBackground && !state.isGeneratingSuggestions) || state.isCancelled) {
      return;
    }

    if (mounted) {
      state = state.copyWith(isCancelled: true);
    }

    try {
      await ref.read(llmServiceProvider).cancelActiveRequest();
      await llmStreamSubscription?.cancel();
      llmStreamSubscription = null;
      pseudoStreamTimer?.cancel();
      pseudoStreamTimer = null;

      // The onDone/onError handlers or the timer loop will catch the isCancelled flag
      // and call _finalizeResponse. We just need to clean up the UI state here.
      // The timer loop now explicitly calls finalize, ensuring partial saves.
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          isStreaming: false,
          isPrimaryResponseLoading: false,
          isProcessingInBackground: false,
          isGeneratingSuggestions: false,
          isCancelled: false, // Reset for next run
        );
        stopUpdateTimer();
        showTopMessage("已停止", backgroundColor: Colors.blueGrey);
      }
    } catch (e) {
      if (mounted) {
        showTopMessage("取消操作时出错: $e", backgroundColor: Colors.red);
        state = state.copyWith(
          isLoading: false,
          isStreaming: false,
          isProcessingInBackground: false,
          isGeneratingSuggestions: false,
        );
        stopUpdateTimer();
      }
    }
  }

  Future<void> _finalizeResponse(
    Message? finalMessage, {
    bool hasError = false,
    bool isCancelled = false,
  }) async {
    // This function is now the single point of exit for all generation types.

    // 1. Stop UI indicators
    if (mounted) {
      state = state.copyWith(
        isPrimaryResponseLoading: false,
        isStreaming: false,
      );
    }

    // 2. If there was an error or cancellation without a message, fully stop.
    if (finalMessage == null) {
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          clearUiControlledMessage: true,
        );
        stopUpdateTimer();
      }
      return;
    }

    // 3. Process the final message and run background tasks
    try {
      final messageRepo = ref.read(messageRepositoryProvider);
      final chat = ref.read(currentChatProvider(chatId)).value;

      if (chat != null) {
        // Process the message in-memory to extract XML, etc.
        final processedMessage = await getFinalProcessedMessage(chat, finalMessage);
        // Save the final, processed version back to the DB.
        await messageRepo.saveMessage(processedMessage);

        // The UI already has the final content. We just update the state with the processed version.
        state = state.copyWith(uiControlledMessage: processedMessage);

        // Run post-save tasks ONLY if the stream completed successfully.
        if (!isCancelled && !hasError) {
          await runAsyncProcessingTasks(processedMessage);
          if (mounted && !state.isCancelled && !hasError) {
            showTopMessage("已完成", backgroundColor: Colors.green);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        showTopMessage('后台处理任务出错: $e', backgroundColor: Colors.red);
      }
    } finally {
      // 4. Final state cleanup. The uiControlledMessage is intentionally NOT cleared.
      // It will be automatically moved to historicalMessages by the DB listener.
      if (mounted) {
        state = state.copyWith(
          isLoading: false, // Master lock OFF
          isProcessingInBackground: false,
          isCancelled: false, // Reset for the next run
        );
        stopUpdateTimer();
      }
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/api_config.dart';
import '../../../../domain/models/chat.dart';
import '../../../../domain/models/message.dart';
import '../../../../domain/enums.dart';
import '../../../../data/llmapi/llm_models.dart';
import '../../../../data/llmapi/llm_service.dart';
import '../../../tools/context_xml_service.dart';
import '../../../tools/xml_processor.dart';
import '../../settings_providers.dart';
import '../../../repositories/message_repository.dart';
import '../../repository_providers.dart';

import '../chat_data_providers.dart';
import '../special_action_type.dart';
import 'ui_state_manager.dart';

/// A private exception to signal that the background task was intentionally cancelled.
class _BackgroundTaskCancelledException implements Exception {}

mixin BackgroundTasks on UiStateManager {
  // Abstract dependencies required by this mixin, as per instructions.
  // These are expected to be implemented by the class using this mixin.
  @override
  Ref get ref;
  @override
  int get chatId;
  Future<void> updateContextDebugInfo(); // Dependency for debug info refresh
  Future<void> generateHelpMeReply({
    Function(List<String>)? onSuggestionsReady,
    bool forceRefresh = false,
  });
  Future<String> executeSpecialAction({
    required String prompt,
    required ApiConfig apiConfig,
    required SpecialActionType actionType,
    required Message targetMessage,
  });
  ApiConfig getEffectiveApiConfig({String? specificConfigId});
  @override
  void stopUpdateTimer();

  /// 手动触发总结，将当前上下文窗口压缩至约70%。
  Future<void> manuallySummarizeHistory() async {
    showTopMessage("正在生成手动总结...", duration: const Duration(seconds: 120));
    try {
      final contextXmlService = ref.read(contextXmlServiceProvider);
      final chatRepo = ref.read(chatRepositoryProvider);
      final chat = ref.read(currentChatProvider(chatId)).value;
      if (chat == null) throw Exception("Chat data not available.");

      // 1. 获取当前的上下文窗口信息
      final contextInfo = await contextXmlService.buildApiRequestContext(
        chatId: chatId,
        currentUserMessage: Message(
          chatId: chatId,
          role: MessageRole.user,
          parts: [MessagePart.text("manual summary check")],
        ),
      );
      final keptMessages = contextInfo.keptMessages;

      if (keptMessages.length < 3) {
        showTopMessage("上下文窗口中的消息太少，无法总结。", backgroundColor: Colors.orange);
        return;
      }

      // 2. 计算要从当前窗口中总结的消息数量（基于用户设置的比例）
      final summaryRatio =
          1.0 -
          ref.read(summaryRatioProvider); // Invert: 70% kept -> 30% summarized
      final countToSummarize = (keptMessages.length * summaryRatio).ceil();
      final messagesToSummarize = keptMessages.sublist(0, countToSummarize);

      // 3. 用于上下文的后续消息是窗口中剩余的70%的开头部分
      final followingMessages = keptMessages.length > countToSummarize
          ? keptMessages.sublist(
              countToSummarize,
              (countToSummarize + 4 > keptMessages.length)
                  ? keptMessages.length
                  : countToSummarize + 4,
            )
          : <Message>[];

      // 4. 生成新的总结块，并与任何已存在的总结合并
      final newSummaryChunk = await summarizeMessages(
        messagesToSummarize,
        chat.contextSummary, // 传入现有总结以进行合并
        followingMessages: followingMessages,
      );

      // 5. 保存新的总结和边界ID
      if (newSummaryChunk.isNotEmpty && mounted) {
        // 关键修复：新的边界应该是被总结消息的最后一条ID
        final newBoundaryId = messagesToSummarize.lastOrNull?.id;
        await chatRepo.saveChat(
          chat.copyWith(
            contextSummary: newSummaryChunk,
            lastSummarizedMessageId: newBoundaryId,
          ),
        );
        showTopMessage("手动总结已保存。", backgroundColor: Colors.green);
        // 总结后立即刷新调试信息
        updateContextDebugInfo();
      } else if (mounted) {
        throw Exception("总结过程返回了空内容。");
      }
    } catch (e) {
      showTopMessage("手动总结出错: $e", backgroundColor: Colors.red);
    }
  }

  Future<void> runAsyncProcessingTasks(Message modelMessage) async {
    if (!mounted) return;
    final chat = ref.read(currentChatProvider(chatId)).value;
    if (chat == null) return;

    if (!mounted || state.isCancelled) return; // Critical cancellation check

    // 1. Set background processing state
    if (mounted) {
      state = state.copyWith(isProcessingInBackground: true);
    }

    // 2. Fetch the complete, updated message history ONCE to ensure all tasks use the same data source.
    final allMessages = await ref
        .read(messageRepositoryProvider)
        .getMessagesForChat(chatId);

    List<Future> tasks = [];

    // 3. Gather all tasks that must run *after* the message is saved.
    tasks.add(executeAutoTitleGeneration(chat, modelMessage, allMessages));
    tasks.add(executeSecondaryXmlGeneration(chat, modelMessage));

    final bool shouldRunPreprocessing =
        chat.enablePreprocessing &&
        (chat.preprocessingPrompt?.isNotEmpty ?? false);
    if (shouldRunPreprocessing) {
      tasks.add(executePreprocessing(chat));
    }
    if (chat.enableHelpMeReply &&
        chat.helpMeReplyTriggerMode == HelpMeReplyTriggerMode.auto) {
      tasks.add(generateHelpMeReply());
    }

    // 3. Run tasks and clear state in a finally block
    if (tasks.isNotEmpty) {
      try {
        // A future that throws an exception when cancellation is requested.
        // This allows us to break out of the Future.any() and proceed to the finally block.
        Future<void> cancellationWatcher() async {
          while (mounted && !state.isCancelled) {
            // Check for cancellation periodically.
            await Future.delayed(const Duration(milliseconds: 100));
          }
          if (state.isCancelled) {
            // Throwing a specific exception allows for clean handling of the cancellation flow.
            throw _BackgroundTaskCancelledException();
          }
        }

        // Race the background tasks against the cancellation watcher.
        // If cancellationWatcher wins, Future.any completes with an exception.
        // If Future.wait(tasks) wins, it completes normally.
        await Future.any([Future.wait(tasks), cancellationWatcher()]);
      } on _BackgroundTaskCancelledException {
        // This is the expected outcome when the user cancels.
        // Do nothing here; the 'finally' block will handle all UI state cleanup.
      } catch (e) {
        if (!state.isCancelled) {
          // Only show error if not cancelled by user
          if (mounted) {
            showTopMessage(
              "后台处理任务出错: $e",
              backgroundColor: Colors.red.withAlpha(204),
            );
          }
        }
      } finally {
        if (mounted) {
          // Clear all processing states together, including the master isLoading flag.
          state = state.copyWith(
            isLoading: false, // Master lock OFF
            isPrimaryResponseLoading: false, // Ensure this is also off
            isProcessingInBackground: false,
          );
          stopUpdateTimer();
        }
      }
    } else {
      // If there are no tasks, ensure all loading states are cleared immediately.
      if (mounted) {
        state = state.copyWith(
          isLoading: false, // Master lock OFF
          isPrimaryResponseLoading: false, // Ensure this is also off
          isProcessingInBackground: false,
        );
        stopUpdateTimer();
      }
    }
  }

  // A helper to contain the logic of _executePostGenerationProcessing but return the final message
  Future<Message> getFinalProcessedMessage(
    Chat chat,
    Message initialMessage,
  ) async {
    // This is the full text received from the stream, including any XML.
    final fullRawText = initialMessage.rawText;

    // 1. Process the final text using rules to separate display text from extractable XML.
    final processResult = XmlProcessor.processPostStream(
      fullRawText,
      chat.xmlRules,
    );
    final finalTextForDisplay = processResult.modelsText;
    final extractedXml = processResult.extractedXml;

    // 2. Create the final, processed message object.
    final newParts = [MessagePart.text(finalTextForDisplay)];

    // Secondary XML is now handled as a post-processing async task.
    return initialMessage.copyWith(
      parts: newParts,
      originalXmlContent: extractedXml,
    );
  }

  Future<void> executeSecondaryXmlGeneration(
    Chat chat,
    Message targetMessage,
  ) async {
    if (state.isCancelled) return;
    // 只要提示词不为空，就执行生成。
    // 合并计算的逻辑由 context_xml_service 中的 enableSecondaryXml 开关控制。
    if (chat.secondaryXmlPrompt?.isEmpty ?? true) {
      return;
    }

    try {
      if (state.isCancelled) return;
      final apiConfig = getEffectiveApiConfig(
        specificConfigId: chat.secondaryXmlApiConfigId,
      );
      final generatedText = await executeSpecialAction(
        prompt: chat.secondaryXmlPrompt!,
        apiConfig: apiConfig,
        actionType: SpecialActionType.secondaryXml,
        targetMessage: targetMessage,
      );

      if (generatedText.isNotEmpty && mounted && !state.isCancelled) {
        final messageRepo = ref.read(messageRepositoryProvider);
        final updatedMessage = targetMessage.copyWith(
          secondaryXmlContent: generatedText,
        );
        await messageRepo.saveMessage(updatedMessage);
      } else if (mounted && !state.isCancelled) {
        // Secondary XML generation resulted in empty content. Skipping update.
      }
    } catch (e) {
      if (!state.isCancelled) {
        // Secondary XML generation failed. Do not rethrow, as this is a background task and shouldn't block or show a major error.
      }
    }
  }

  /// Executes automatic summarization based on a predictive model.
  Future<Chat?> executePreprocessing(Chat chat) async {
    if (state.isCancelled || state.isSummarizing) return null;

    // Set summarizing state immediately and ensure it's cleared
    if (mounted) {
      state = state.copyWith(isSummarizing: true);
    }

    try {
      final contextXmlService = ref.read(contextXmlServiceProvider);

      // 1. Predict if the next turn will exceed the budget.
      final predictionResult = await contextXmlService.predictContextUsage(
        chatId: chatId,
      );

      // 2. If it won't exceed, we're done.
      if (!predictionResult.willExceed) {
        return null; // Exit the try block. Finally will still run.
      }

      // 3. The messages in the current window are the combination of what was
      //    kept and what was just dropped by the prediction.
      final currentWindowMessages = [
        ...predictionResult.droppedMessages,
        ...predictionResult.keptMessages,
      ];

      if (currentWindowMessages.length < 3) {
        return null;
      }

      // 4. Correctly calculate which messages to summarize based on the global setting.
      // It should be ALL dropped messages PLUS a percentage of the kept messages.
      final summaryRatio =
          1.0 -
          ref.read(
            summaryRatioProvider,
          ); // e.g., 1.0 - 0.7 (keep) = 0.3 (summarize)
      final countToSummarizeFromKept =
          (predictionResult.keptMessages.length * summaryRatio).floor();
      final messagesToSummarize = [
        ...predictionResult.droppedMessages,
        ...predictionResult.keptMessages.sublist(0, countToSummarizeFromKept),
      ];

      if (messagesToSummarize.isEmpty) {
        return null;
      }

      // 5. The "following messages" for context are the ones that will REMAIN in the window,
      // which are the kept messages minus the portion we are also summarizing.
      final remainingKeptMessages = predictionResult.keptMessages.sublist(
        countToSummarizeFromKept,
      );
      final followingMessages = remainingKeptMessages.length > 4
          ? remainingKeptMessages.sublist(0, 4)
          : remainingKeptMessages;

      if (state.isCancelled) return null;

      // 6. Generate the new summary chunk, merging with any previous summary.
      final chatRepo = ref.read(chatRepositoryProvider);
      final newSummaryChunk = await summarizeMessages(
        messagesToSummarize,
        chat.contextSummary,
        followingMessages: followingMessages,
      );

      // 7. Save the new summary and update the boundary ID.
      if (newSummaryChunk.isNotEmpty && mounted) {
        // The new boundary is the timestamp of the last message we summarized.
        final newBoundaryId = messagesToSummarize.lastOrNull?.id;
        final chatToSave = chat.copyWith(
          contextSummary: newSummaryChunk,
          lastSummarizedMessageId: newBoundaryId,
        );
        await chatRepo.saveChat(chatToSave);
        updateContextDebugInfo();
        // 成功保存后，返回最新的 chat 对象
        return await chatRepo.getChat(chatId);
      } else if (mounted) {
        // Automatic summarization resulted in an empty summary. Nothing to save.
      }
    } catch (e) {
      if (!state.isCancelled) {
        showTopMessage(
          "自动总结出错: $e",
          backgroundColor: Colors.red.withAlpha(204),
        );
      }
    } finally {
      if (mounted) {
        state = state.copyWith(isSummarizing: false);
      }
    }
    return null; // 确保在所有路径上都有返回值
  }

  /// A reusable helper to summarize a list of messages in parallel chunks.
  Future<String> summarizeMessages(
    List<Message> messages,
    String? existingSummary, {
    List<Message>? followingMessages,
  }) async {
    if (state.isCancelled) return "";
    final chat = ref.read(currentChatProvider(chatId)).value;
    if (chat == null) return "";

    final contextXmlService = ref.read(contextXmlServiceProvider);

    // 1. Chunking: Split the messages into non-overlapping chunks based on the chat's context budget.
    final List<List<Message>> chunks = [];
    List<Message> remainingToChunk = List.from(messages);

    while (remainingToChunk.isNotEmpty) {
      if (state.isCancelled) return "";
      // We reuse the context builder to accurately determine how many messages fit in one chunk.
      final chunkingContext = await contextXmlService.buildApiRequestContext(
        chatId: chatId,
        currentUserMessage: Message(
          chatId: chatId,
          role: MessageRole.user,
          parts: [MessagePart.text("chunking")],
        ),
        historyOverride: remainingToChunk,
        chatSystemPromptOverride: chat.preprocessingPrompt,
      );

      // The messages that were *kept* by the context builder form our current chunk.
      final List<Message> currentChunk = chunkingContext.keptMessages;
      // The messages that were *dropped* are what we'll process in the next iteration.
      final List<Message> nextRemaining = chunkingContext.droppedMessages;

      if (currentChunk.isEmpty) {
        break;
      }
      chunks.add(currentChunk);
      remainingToChunk = nextRemaining;
    }

    if (chunks.isEmpty) {
      return existingSummary ?? "";
    }

    // 2. Parallel Summarization with Correct Context Chaining
    // 'chunks' 列表现在是 [最新的块, ..., 最旧的块]
    final List<Future<String>> summaryFutures = [];

    // 遍历 chunks 列表 (从新到旧)
    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i]; // 当前块

      // existingSummary 应该只与最旧的块合并。
      // 最旧的块是 'chunks' 列表中的最后一个元素。
      final summaryForThisChunk = (i == chunks.length - 1)
          ? existingSummary
          : null;

      // 为每个块提供正确的 'followingMessages' 以确保连贯性。
      List<Message>? messagesForContext;
      if (i == 0) {
        // 这是最新的块。它的上下文是后续的实时对话。
        messagesForContext = followingMessages;
      } else {
        // 对于任何其他块，它的上下文是它前面一个块 (更年轻的块) 的开头几条消息。
        // 例如，如果当前是 chunk_mid，它的上下文是 chunk_new 的开头。
        final previousChunkInList = chunks[i - 1];
        messagesForContext = previousChunkInList.length > 4
            ? previousChunkInList.sublist(0, 4)
            : previousChunkInList;
      }

      summaryFutures.add(
        _summarizeChunkWithRetry(
          chat,
          chunk,
          summaryForThisChunk,
          followingMessages: messagesForContext,
        ),
      );
    }

    final summaryResults = await Future.wait(summaryFutures);
    if (state.isCancelled) return "";

    // 3. Aggregation
    // 'summaryResults' 列表的顺序与 'summaryFutures' 的添加顺序一致，即 [最新的总结, ..., 最旧的总结]。
    // 我们需要将其反转为 [最旧的总结, ..., 最新的总结] 再进行拼接。
    final finalSummary = summaryResults.reversed
        .where((s) => s.isNotEmpty)
        .join('\n\n---\n\n');
    return finalSummary;
  }

  /// A robust helper to summarize a single chunk of messages with a retry mechanism.
  Future<String> _summarizeChunkWithRetry(
    Chat chat,
    List<Message> chunk,
    String? previousSummary, {
    List<Message>? followingMessages,
  }) async {
    const maxRetries = 3;
    final llmService = ref.read(llmServiceProvider);
    final summaryPrompt = chat.preprocessingPrompt!;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      if (state.isCancelled) {
        return ""; // Check for cancellation before each attempt
      }

      try {
        // Manually construct the context for this specific chunk.
        List<LlmContent> summaryContext = [
          LlmContent("system", [LlmTextPart(summaryPrompt)]),
        ];

        // Add the original system prompt (demoted to user role) to give context to the summarizer.
        if (chat.systemPrompt != null && chat.systemPrompt!.trim().isNotEmpty) {
          summaryContext.add(
            LlmContent("user", [LlmTextPart(chat.systemPrompt!)]),
          );
        }

        // If a previous summary is provided (only for the first chunk), add it.
        if (previousSummary != null && previousSummary.isNotEmpty) {
          final previousSummaryText = XmlProcessor.wrapWithTag(
            'previous_summary',
            previousSummary,
          );
          summaryContext.add(
            LlmContent("user", [LlmTextPart(previousSummaryText)]),
          );
        }

        // Add each message from the chunk.
        for (final message in chunk) {
          summaryContext.add(LlmContent.fromMessage(message));
        }

        // Add the guiding prompt at the end, optionally with the following conversation for context.
        String finalPromptText = summaryPrompt;
        if (followingMessages != null && followingMessages.isNotEmpty) {
          final followingConversation = followingMessages
              .map((m) {
                final role = m.role == MessageRole.user ? 'User' : 'Assistant';
                // Safely join parts, handling potential nulls
                final text = m.parts
                    .map((p) => p.text ?? '')
                    .where((t) => t.isNotEmpty)
                    .join(' ');
                return '$role: $text';
              })
              .join('\n\n');
          finalPromptText +=
              '\n\n--- 以下是后续的实际对话，请确保总结与后续实际对话连贯，后续的实际对话切勿纳入总结中 ---\n$followingConversation';
        }
        summaryContext.add(LlmContent("user", [LlmTextPart(finalPromptText)]));

        // 重构：直接获取配置对象
        final apiConfig = getEffectiveApiConfig(
          specificConfigId: chat.preprocessingApiConfigId,
        );
        final response = await llmService.sendMessageOnce(
          llmContext: summaryContext,
          apiConfig: apiConfig,
        );

        if (response.isSuccess && response.parts.isNotEmpty) {
          final summaryText = response.parts
              .map((p) => p.text ?? "")
              .join("\n")
              .trim();
          return summaryText; // Success
        } else {
          throw Exception("API Error: ${response.error ?? 'Empty response'}");
        }
      } catch (e) {
        if (attempt == maxRetries || state.isCancelled) {
          // If it's the last attempt or cancelled, rethrow to fail the Future.
          // The Future.wait will catch this, but we'll return an empty string
          // so that a single failed chunk doesn't stop the entire process.
          return "";
        }
        // Wait before retrying
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
    return ""; // Should be unreachable, but ensures a return value
  }

  Future<void> executeAutoTitleGeneration(
    Chat chat,
    Message currentModelMessage,
    List<Message> allMessages,
  ) async {
    if (state.isCancelled) return;
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted || state.isCancelled) return;

    final globalSettings = ref.read(globalSettingsProvider);
    if (!globalSettings.enableAutoTitleGeneration ||
        globalSettings.titleGenerationPrompt.isEmpty) {
      return;
    }

    // Use the passed-in message list, ensuring a unified data source.
    final modelMessagesCount = allMessages
        .where((m) => m.role == MessageRole.model)
        .length;

    if (modelMessagesCount != 1) {
      return;
    }

    try {
      if (state.isCancelled) return;
      final apiConfig = getEffectiveApiConfig(
        specificConfigId: globalSettings.titleGenerationApiConfigId,
      );
      final generatedText = await executeSpecialAction(
        prompt: globalSettings.titleGenerationPrompt,
        apiConfig: apiConfig,
        actionType: SpecialActionType.autoTitle,
        targetMessage: currentModelMessage,
      );
      final newTitle = generatedText.trim().replaceAll(RegExp(r'["\n]'), '');
      if (newTitle.isNotEmpty) {
        final chatRepo = ref.read(chatRepositoryProvider);
        final currentChat = await chatRepo.getChat(chatId);
        if (currentChat != null && mounted && !state.isCancelled) {
          await chatRepo.saveChat(currentChat.copyWith(title: newTitle));
        }
      } else {
        // Auto title generation resulted in an empty title. Skipping update.
      }
    } catch (e) {
      if (!state.isCancelled) {
        // We rethrow the error so Future.wait in _runAsyncProcessingTasks can catch it
        // and show a generic background error message.
        rethrow;
      }
    }
  }
}

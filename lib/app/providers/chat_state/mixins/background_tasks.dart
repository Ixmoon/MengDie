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

mixin BackgroundTasks on UiStateManager {
    // Abstract dependencies required by this mixin, as per instructions.
    // These are expected to be implemented by the class using this mixin.
    Ref get ref;
    int get chatId;
    Future<void> generateHelpMeReply({Function(List<String>)? onSuggestionsReady, bool forceRefresh = false});
    Future<String> executeSpecialAction({
        required String prompt,
        required ApiConfig apiConfig,
        required SpecialActionType actionType,
        required Message targetMessage,
    });
    ApiConfig getEffectiveApiConfig({String? specificConfigId});
    void stopUpdateTimer();

    Future<void> runAsyncProcessingTasks(Message modelMessage) async {
        if (!mounted) return;
        final chat = ref.read(currentChatProvider(chatId)).value;
        if (chat == null) return;

        if (!mounted || state.isCancelled) return; // Critical cancellation check

        // 1. Set background processing state
        if (mounted) {
            state = state.copyWith(isProcessingInBackground: true);
        }

        List<Future> tasks = [];

        // 2. Gather all tasks that must run *after* the message is saved.
        tasks.add(executeAutoTitleGeneration(chat, modelMessage));
        // _executePostGenerationProcessing is now done *before* saving, so it's removed from here.
        if (chat.enablePreprocessing && (chat.preprocessingPrompt?.isNotEmpty ?? false)) {
          tasks.add(executePreprocessing(chat));
        }
        if (chat.enableHelpMeReply && chat.helpMeReplyTriggerMode == HelpMeReplyTriggerMode.auto) {
          tasks.add(generateHelpMeReply());
        }

        // 3. Run tasks and clear state in a finally block
        if (tasks.isNotEmpty) {
          try {
            await Future.wait(tasks);
            debugPrint("ChatStateNotifier($chatId): Async processing tasks completed.");
            // Show completion message only on success and if not cancelled
            // The "Completed" message is now shown by the caller contexts
            // (_finalizeStreamedMessage or _handleSingleResponse) after this whole process finishes.
          } catch (e) {
            if (!state.isCancelled) { // Only show error if not cancelled by user
              debugPrint("ChatStateNotifier($chatId): Error during async processing tasks: $e");
              if (mounted) {
                showTopMessage("后台处理任务出错: $e", backgroundColor: Colors.red.withAlpha(204));
              }
            }
          } finally {
            if (mounted) {
              // Clear all processing states together, including the master isLoading flag.
              state = state.copyWith(
                isLoading: false, // Master lock OFF
                isPrimaryResponseLoading: false, // Ensure this is also off
                isProcessingInBackground: false,
                // Do not clear the message object itself, just hide the UI element.
                // The main message list will show the final version from the database stream.
                isStreamingMessageVisible: false,
              );
              stopUpdateTimer();
              debugPrint("ChatStateNotifier($chatId): All processing finished. isLoading is now false.");
            }
          }
        } else {
          // If there are no tasks, ensure all loading states are cleared immediately.
          if (mounted) {
            state = state.copyWith(
              isLoading: false, // Master lock OFF
              isPrimaryResponseLoading: false, // Ensure this is also off
              isProcessingInBackground: false,
              isStreamingMessageVisible: false, // Just hide it
            );
            stopUpdateTimer();
          }
        }
    }

    // A helper to contain the logic of _executePostGenerationProcessing but return the final message
    Future<Message> getFinalProcessedMessage(Chat chat, Message initialMessage) async {
      final originalRawText = initialMessage.rawText;
      final displayText = XmlProcessor.stripXmlContent(originalRawText);
      final initialXml = XmlProcessor.extractXmlContent(originalRawText);

      String? newSecondaryXmlContent;

      if (chat.enableSecondaryXml && (chat.secondaryXmlPrompt?.isNotEmpty ?? false)) {
        try {
          if (state.isCancelled) return initialMessage; // Early exit
          // 重构：直接获取配置对象
          final apiConfig = getEffectiveApiConfig(specificConfigId: chat.secondaryXmlApiConfigId);
          final generatedText = await executeSpecialAction(
            prompt: chat.secondaryXmlPrompt!,
            apiConfig: apiConfig,
            actionType: SpecialActionType.secondaryXml,
            targetMessage: initialMessage,
          );
          debugPrint("ChatStateNotifier($chatId): ========== Secondary XML Raw Content START ==========");
          debugPrint(generatedText);
          debugPrint("ChatStateNotifier($chatId): ========== Secondary XML Raw Content END ==========");
          newSecondaryXmlContent = generatedText;
        } catch (e) {
          // If it fails, we log it but don't stop the whole finalization process.
          // The error is already logged inside _executeSpecialAction.
          // We rethrow to let the caller (_runAsyncProcessingTasks) know something failed.
          debugPrint("ChatStateNotifier($chatId): Secondary XML generation failed and will not be included.");
          rethrow;
        }
      }

      final newParts = [MessagePart.text(displayText)];

      // Return a new message object with all final values, ready to be saved.
      return initialMessage.copyWith(
        parts: newParts,
        originalXmlContent: initialXml,
        secondaryXmlContent: newSecondaryXmlContent,
      );
    }

    /// Executes the new, robust summarization process for dropped messages.
    /// Implements a robust, "intelligent merge" incremental summarization algorithm.
    Future<void> executePreprocessing(Chat chat) async {
      if (state.isCancelled) return;
      debugPrint("ChatStateNotifier($chatId): Executing intelligent merge summarization...");

      final contextXmlService = ref.read(contextXmlServiceProvider);
      final chatRepo = ref.read(chatRepositoryProvider);
      final messageRepo = ref.read(messageRepositoryProvider);

      // 1. Get the complete, current message history.
      final allMessages = await messageRepo.getMessagesForChat(chatId);
      if (allMessages.length < 2) {
        debugPrint("ChatStateNotifier($chatId): Not enough messages for context diff, skipping.");
        return;
      }

      // 2. Simulate context "AFTER" the latest turn to find all currently dropped messages.
      final contextAfter = await contextXmlService.buildApiRequestContext(
        chatId: chatId,
        currentUserMessage: Message(chatId: chatId, role: MessageRole.user, parts: [MessagePart.text("after")]),
      );
      final droppedMessagesAfter = contextAfter.droppedMessages;

      // If nothing is dropped now, there's nothing to do.
      if (droppedMessagesAfter.isEmpty) {
        debugPrint("ChatStateNotifier($chatId): No messages are dropped. Clearing summary if it exists.");
        if (chat.contextSummary != null) {
          await chatRepo.saveChat(chat.copyWith(contextSummary: null));
        }
        return;
      }

      // 3. Simulate context "BEFORE" the latest turn.
      final historyBefore = allMessages.sublist(0, allMessages.length - 2);
      final contextBefore = await contextXmlService.buildApiRequestContext(
        chatId: chatId,
        currentUserMessage: Message(chatId: chatId, role: MessageRole.user, parts: [MessagePart.text("before")]),
        historyOverride: historyBefore,
      );
      final droppedMessagesBefore = contextBefore.droppedMessages;

      // 4. Determine the messages to summarize based on whether a summary already exists.
      final List<Message> messagesToSummarize;

      if (chat.contextSummary == null || chat.contextSummary!.isEmpty) {
        // SCENARIO A: No existing summary. We must summarize ALL currently dropped messages
        // to build the summary from scratch.
        messagesToSummarize = droppedMessagesAfter;
        debugPrint("ChatStateNotifier($chatId): No existing summary. Summarizing all ${messagesToSummarize.length} dropped messages.");
      } else {
        // SCENARIO B: Existing summary found. We only need to summarize the "diff" -
        // the messages that were newly dropped in this turn.
        final droppedIdsBefore = droppedMessagesBefore.map((m) => m.id).toSet();
        messagesToSummarize = droppedMessagesAfter
            .where((msg) => !droppedIdsBefore.contains(msg.id))
            .toList();
        debugPrint("ChatStateNotifier($chatId): Existing summary found. Summarizing diff of ${messagesToSummarize.length} messages.");
      }

      if (messagesToSummarize.isEmpty) {
        debugPrint("ChatStateNotifier($chatId): Context diff is empty. No new messages to summarize.");
        return; // Nothing new was dropped, so the existing summary is still valid.
      }

      debugPrint("ChatStateNotifier($chatId): Found ${messagesToSummarize.length} new messages to summarize.");
      if (state.isCancelled) return;

      // 5. Chunking & Summarization
      // The logic now takes the existing summary and merges it with the new "diff".
      final List<List<Message>> chunks = [];
      List<Message> remainingToChunk = List.from(messagesToSummarize);

      while (remainingToChunk.isNotEmpty) {
        if (state.isCancelled) return;
        final chunkingContext = await contextXmlService.buildApiRequestContext(
            chatId: chatId,
            currentUserMessage: Message(chatId: chatId, role: MessageRole.user, parts: [MessagePart.text("chunking")]),
            historyOverride: remainingToChunk,
            chatSystemPromptOverride: chat.preprocessingPrompt);
        
        final List<Message> droppedInThisChunk = chunkingContext.droppedMessages;
        final Set<int> droppedIds = droppedInThisChunk.map((m) => m.id).toSet();
        final List<Message> currentChunk = remainingToChunk.where((m) => !droppedIds.contains(m.id)).toList();

        if (currentChunk.isEmpty) {
          debugPrint("Warning: Chunking produced an empty chunk. Discarding remaining ${remainingToChunk.length} messages.");
          break;
        }
        chunks.add(currentChunk);
        remainingToChunk = droppedInThisChunk;
      }

      if (chunks.isEmpty) {
        debugPrint("ChatStateNotifier($chatId): Chunking of diff resulted in no chunks to process.");
        return;
      }

      // 6. Parallel Intelligent Merge Execution
      // **CRITICAL FIX**: Reverse the chunks so they are processed from OLDEST to NEWEST.
      // This ensures the existing summary is merged with the oldest part of the new diff.
      final reversedChunks = chunks.reversed.toList();
      final existingSummary = chat.contextSummary;
      final List<Future<String>> summaryFutures = [];

      for (int i = 0; i < reversedChunks.length; i++) {
        final chunk = reversedChunks[i];
        // The very first chunk (which is now the OLDEST part of the history)
        // gets the existing summary to perform the intelligent merge.
        final summaryForThisChunk = (i == 0) ? existingSummary : null;
        summaryFutures.add(summarizeChunkWithRetry(chat, chunk, summaryForThisChunk));
      }

      final summaryResults = await Future.wait(summaryFutures);
      if (state.isCancelled) return;

      // 7. Aggregation & Full Replacement
      // The result from the first future is the new, fully-merged summary.
      // Subsequent results are summaries of any further chunks, which we join.
      final finalSummary = summaryResults.where((s) => s.isNotEmpty).join('\n\n---\n\n');

      if (finalSummary.isNotEmpty) {
        // We are performing a full replacement of the old summary with the new one.
        await chatRepo.saveChat(chat.copyWith(contextSummary: finalSummary));
        debugPrint("ChatStateNotifier($chatId): Intelligent merge summarization successful. New summary saved.");
      } else {
        debugPrint("ChatStateNotifier($chatId): Summarization resulted in an empty summary. Nothing to save.");
        throw Exception("Summarization failed: All chunks resulted in empty content.");
      }
    }

    /// A robust helper to summarize a single chunk of messages with a retry mechanism.
    Future<String> summarizeChunkWithRetry(Chat chat, List<Message> chunk, String? previousSummary) async {
      const maxRetries = 3;
      final llmService = ref.read(llmServiceProvider);
      final summaryPrompt = chat.preprocessingPrompt!;

      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        if (state.isCancelled) return ""; // Check for cancellation before each attempt

        try {
          // Manually construct the context for this specific chunk.
          List<LlmContent> summaryContext = [
            LlmContent("system", [LlmTextPart(summaryPrompt)])
          ];

          // If a previous summary is provided (only for the first chunk), add it.
          if (previousSummary != null && previousSummary.isNotEmpty) {
            final previousSummaryText = XmlProcessor.wrapWithTag('previous_summary', previousSummary);
            summaryContext.add(LlmContent("user", [LlmTextPart(previousSummaryText)]));
          }

          // Add each message from the chunk.
          for (final message in chunk) {
            summaryContext.add(LlmContent.fromMessage(message));
          }

          // Add the guiding prompt at the end.
          summaryContext.add(LlmContent("user", [LlmTextPart(summaryPrompt)]));

          // 重构：直接获取配置对象
          final apiConfig = getEffectiveApiConfig(specificConfigId: chat.preprocessingApiConfigId);
          final response = await llmService.sendMessageOnce(
            llmContext: summaryContext,
            apiConfig: apiConfig,
          );

          if (response.isSuccess && response.parts.isNotEmpty) {
            final summaryText = response.parts.map((p) => p.text ?? "").join("\n").trim();
            debugPrint("ChatStateNotifier($chatId): Chunk summarization successful on attempt $attempt.");
            return summaryText; // Success
          } else {
            throw Exception("API Error: ${response.error ?? 'Empty response'}");
          }
        } catch (e) {
          debugPrint("ChatStateNotifier($chatId): Chunk summarization attempt $attempt/$maxRetries failed: $e");
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

    Future<void> executeAutoTitleGeneration(Chat chat, Message currentModelMessage) async {
      if (state.isCancelled) return;
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted || state.isCancelled) return;

      final globalSettings = ref.read(globalSettingsProvider);
      if (!globalSettings.enableAutoTitleGeneration ||
          globalSettings.titleGenerationPrompt.isEmpty ||
          globalSettings.titleGenerationApiConfigId == null) {
        return;
      }

      final allMessages = ref.read(chatMessagesProvider(chatId)).value ?? [];
      final modelMessagesCount = allMessages.where((m) => m.role == MessageRole.model).length;

      if (modelMessagesCount != 1) {
        debugPrint("ChatStateNotifier($chatId): Skipping auto title generation. Model messages count: $modelMessagesCount");
        return;
      }

      debugPrint("ChatStateNotifier($chatId): Starting auto title generation...");

      try {
        if (state.isCancelled) return;
        final apiConfig = getEffectiveApiConfig(specificConfigId: globalSettings.titleGenerationApiConfigId);
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
            debugPrint("ChatStateNotifier($chatId): Auto title generation successful. New title: $newTitle");
          }
        } else {
          debugPrint("ChatStateNotifier($chatId): Auto title generation resulted in an empty title. Skipping update.");
        }
      } catch (e) {
        if (!state.isCancelled) {
          debugPrint("ChatStateNotifier($chatId): Error during auto title generation after retries: $e");
          // We rethrow the error so Future.wait in _runAsyncProcessingTasks can catch it
          // and show a generic background error message.
          rethrow;
        }
      }
    }
}

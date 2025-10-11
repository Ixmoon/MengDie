// 本文件包含 ContextXmlService，一个核心服务，负责构建与大语言模型 (LLM) API 交互所需的最终上下文。
//
// 主要功能:
// 1.  精确的上下文构建:
//     - `buildApiRequestContext` 是核心方法，它负责整合所有上下文部分，包括系统提示词、被降级的系统提示词（用于特殊操作）、
//       上下文摘要以及从历史消息中计算出的合成XML。
//     - 它实现了“先计算固定开销，后用剩余预算截断历史”的精确模式，确保最终发送的上下文严格遵守用户设置的 `maxTokens` 和 `maxTurns` 限制。
// 2.  高性能的 Token 计算:
//     - 利用 `Future.wait` 并行计算所有非历史记录部分（如系统提示、摘要等）的 Token 数量，以减少延迟。
// 3.  历史记录截断:
//     - `_limitHistoryForPrompt` 辅助方法根据 `buildApiRequestContext` 计算出的精确预算（Token 和轮次），对历史消息进行截断。
// 4.  合成 XML 计算:
//     - `_calculateCurrentCarriedOverXml` 方法遍历完整的消息历史，根据聊天中定义的 XML 规则（保存/更新），计算出在当前轮次需要合成的累积 XML 状态。
// 5.  灵活性:
//     - `buildApiRequestContext` 支持 `historyOverride` 参数，允许调用者传入自定义的消息列表进行上下文构建，
//       这对于实现如“分块摘要”等高级功能至关重要，因为它复用了服务的精确截断逻辑。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xml/xml.dart'
    as xml_pkg; // For XmlDocument, XmlElement, XmlName during recalculation

import '../../domain/models/chat.dart';
import '../../domain/models/message.dart';
import '../../domain/models/xml_rule.dart';
import '../../domain/enums.dart';
import '../repositories/message_repository.dart'; // For MessageRepository
import 'xml_processor.dart';
import '../../data/llmapi/llm_models.dart'; // For LlmContent, LlmTextPart
import '../../data/llmapi/llm_service.dart'; // For LlmService
import 'package:collection/collection.dart'; // For lastWhereOrNull
import '../providers/repository_providers.dart';
import '../providers/chat_state_providers.dart';

class ContextPredictionResult {
  final bool willExceed;
  final List<Message> keptMessages;
  final List<Message> droppedMessages;

  ContextPredictionResult({
    required this.willExceed,
    required this.keptMessages,
    required this.droppedMessages,
  });
}

class ApiRequestContext {
  final List<LlmContent> contextParts;
  final String? carriedOverXml;
  final List<Message> droppedMessages;
  final List<Message> keptMessages;

  ApiRequestContext({
    required this.contextParts,
    this.carriedOverXml,
    required this.droppedMessages,
    required this.keptMessages,
  });
}

// Helper class for partitioning history
class _HistoryLimitResult {
  final List<Message> kept;
  final List<Message> dropped;
  _HistoryLimitResult(this.kept, this.dropped);
}

// Helper class for carried-over XML result
class _CarriedOverXmlResult {
  final String? xmlString;
  final int contributingMessageCount;
  _CarriedOverXmlResult(this.xmlString, this.contributingMessageCount);
}

// Provider for the new service
final contextXmlServiceProvider = Provider<ContextXmlService>((ref) {
  return ContextXmlService(ref);
});

class ContextXmlService {
  final Ref _ref;

  ContextXmlService(this._ref);

  /// Calculates the current carried-over XML based on the full message history and chat rules.
  /// This method DOES NOT persist anything.
  _CarriedOverXmlResult _calculateCurrentCarriedOverXml(
    Chat chat,
    List<Message> fullHistory,
  ) {
    if (fullHistory.isEmpty) {
      return _CarriedOverXmlResult(null, 0);
    }

    final tagRuleInfoMap = <String, XmlRule>{};
    for (final rule in chat.xmlRules) {
      if (rule.tagName != null &&
          (rule.action == XmlAction.update || rule.action == XmlAction.save)) {
        tagRuleInfoMap[rule.tagName!.toLowerCase()] = rule;
      }
    }

    Map<String, String> cumulativeStateMap = {};
    final Set<int> contributingMessageIds = {};

    for (int i = 0; i < fullHistory.length; i++) {
      final msg = fullHistory[i];
      // FIX: Construct the full XML text for parsing by respecting the chat setting.
      // If secondary XML is enabled, use it; otherwise, use the original.
      // This ensures that the context calculation uses the correct, separated XML fields.
      final xmlContent = chat.enableSecondaryXml
          ? msg.secondaryXmlContent
          : msg.originalXmlContent;

      // Combine the display text with the appropriate XML content.
      // The rawText (which is now just modelsText) might contain other things,
      // but for XML calculation, we prioritize the dedicated fields.
      final fullTextForXmlParsing = '${msg.rawText}\n${xmlContent ?? ''}'
          .trim();

      if (fullTextForXmlParsing.isEmpty ||
          !fullTextForXmlParsing.contains('<')) {
        continue;
      }

      // --- 使用健壮的XML处理器来安全地提取有效的XML块 ---
      // 这确保了不完整的标签不会导致整个消息被跳过。
      final postProcessResult = XmlProcessor.processPostStream(
        fullTextForXmlParsing,
        chat.xmlRules,
      );
      final safeXmlContent = postProcessResult.extractedXml;

      if (safeXmlContent == null || safeXmlContent.isEmpty) {
        continue;
      }

      xml_pkg.XmlDocument? doc;
      try {
        // 现在只解析被验证为结构完整的XML。
        doc = xml_pkg.XmlDocument.parse('<root>$safeXmlContent</root>');
      } catch (e) {
        // 这个catch现在只会在极特殊情况下触发，例如processPostStream的逻辑有bug。
        continue;
      }

      for (final element
          in doc.rootElement.children.whereType<xml_pkg.XmlElement>()) {
        final originalTagNameFromElement = element.name.local;
        final tagNameLower = originalTagNameFromElement.toLowerCase();
        final rule = tagRuleInfoMap[tagNameLower];

        if (rule != null) {
          contributingMessageIds.add(msg.id);
          final action = rule.action;
          final currentOuterXml = element.toXmlString(pretty: false).trim();
          final identifier = XmlProcessor.getElementIdentifier(element);

          if (action == XmlAction.save) {
            if (currentOuterXml.isNotEmpty) {
              cumulativeStateMap[identifier] = currentOuterXml;
            } else {
              cumulativeStateMap.remove(identifier);
            }
          } else if (action == XmlAction.update) {
            final previousOuterXml = cumulativeStateMap[identifier];
            if (previousOuterXml != null && previousOuterXml.isNotEmpty) {
              if (currentOuterXml.isNotEmpty) {
                try {
                  final baseElement = xml_pkg.XmlDocument.parse(
                    previousOuterXml,
                  ).rootElement;
                  final updateElement =
                      element; // The current element is the update
                  final mergedElement = XmlProcessor.mergeElements(
                    baseElement,
                    updateElement,
                  );
                  final mergedOuterXml = mergedElement
                      .toXmlString(pretty: false)
                      .trim();

                  if (mergedOuterXml.isNotEmpty) {
                    cumulativeStateMap[identifier] = mergedOuterXml;
                  } else {
                    cumulativeStateMap.remove(identifier);
                  }
                } catch (e) {
                  // In case of merge failure, retain the previous valid XML state.
                  cumulativeStateMap[identifier] = previousOuterXml;
                }
              } else {
                // If the new content is empty, it signifies removal.
                cumulativeStateMap.remove(identifier);
              }
            } else {
              // No previous state, treat as a simple save.
              if (currentOuterXml.isNotEmpty) {
                cumulativeStateMap[identifier] = currentOuterXml;
              } else {
                cumulativeStateMap.remove(identifier);
              }
            }
          }
        }
      }
    }
    return _CarriedOverXmlResult(
      XmlProcessor.serializeCarriedOver(cumulativeStateMap),
      contributingMessageIds.length,
    );
  }

  /// Helper to limit history based on chat configuration. Operates on a pre-fetched list.
  /// This refactored version respects the `ContextManagementMode` to apply EITHER token OR turn limits.
  Future<_HistoryLimitResult> _limitHistoryForPrompt({
    required int chatId,
    required List<Message> fullHistory,
    required int historyTokenBudget,
    required int historyTurnBudget,
  }) async {
    if (fullHistory.isEmpty) return _HistoryLimitResult([], []);

    final chat = _ref.read(currentChatProvider(chatId)).value;
    if (chat == null) {
      // Failsafe: if chat is gone, drop all history.
      return _HistoryLimitResult([], fullHistory);
    }

    switch (chat.contextConfig.mode) {
      // --- A) Limit by Turns ---
      case ContextManagementMode.turns:
        final turnLimit = historyTurnBudget * 2;
        if (turnLimit <= 0) {
          return _HistoryLimitResult([], fullHistory);
        }
        if (fullHistory.length > turnLimit) {
          final kept = fullHistory.sublist(fullHistory.length - turnLimit);
          final dropped = fullHistory.sublist(
            0,
            fullHistory.length - turnLimit,
          );
          return _HistoryLimitResult(kept, dropped);
        }
        return _HistoryLimitResult(fullHistory, []);

      // --- B) Limit by Tokens ---
      case ContextManagementMode.tokens:
        if (historyTokenBudget <= 0) {
          return _HistoryLimitResult([], fullHistory);
        }

        final llmService = _ref.read(llmServiceProvider);

        try {
          final apiConfig = _ref
              .read(chatStateNotifierProvider(chatId).notifier)
              .getEffectiveApiConfig();
          final tokenFutures = fullHistory.map((msg) {
            return llmService
                .countTokens(
                  llmContext: [LlmContent.fromMessage(msg)],
                  apiConfig: apiConfig,
                )
                .then((count) => {'message': msg, 'tokens': count})
                .catchError((e) {
                  return {'message': msg, 'tokens': 0};
                });
          });
          final messageTokenPairs = await Future.wait(tokenFutures);

          int currentTotalTokens = 0;
          final List<Message> keptHistory = [];

          for (var i = messageTokenPairs.length - 1; i >= 0; i--) {
            final pair = messageTokenPairs[i];
            final messageTokens = pair['tokens'] as int;

            if (currentTotalTokens + messageTokens <= historyTokenBudget) {
              currentTotalTokens += messageTokens;
              keptHistory.insert(0, pair['message'] as Message);
            } else {
              break;
            }
          }

          final Set<int> keptIds = keptHistory.map((m) => m.id).toSet();
          final List<Message> droppedHistory = fullHistory
              .where((m) => !keptIds.contains(m.id))
              .toList();

          return _HistoryLimitResult(keptHistory, droppedHistory);
        } catch (e) {
          return _HistoryLimitResult([], fullHistory);
        }
      // No default needed as all enum cases are handled.
    }
  }

  /// Builds the list of LlmContent to be sent to the LLM API, respecting all context rules.
  /// This is the primary method for constructing the prompt.
  Future<ApiRequestContext> buildApiRequestContext({
    required int chatId,
    required Message currentUserMessage,
    String? lastMessageOverride,
    int? messageIdToPreserveXml,
    String? chatSystemPromptOverride,
    bool? keepAsSystemPrompt,
    List<Message>? historyOverride,
    bool isPrediction =
        false, // FINAL FIX: Add a flag to control pre-emptive checks
  }) async {
    final messageRepo = _ref.read(messageRepositoryProvider);
    final llmService = _ref.read(llmServiceProvider);
    final notifier = _ref.read(chatStateNotifierProvider(chatId).notifier);
    final chat = (await _ref.read(chatRepositoryProvider).getChat(chatId))!;
    final apiConfig = notifier.getEffectiveApiConfig();

    // 1. 始终获取完整历史记录以确保XML计算的准确性。
    final List<Message> fullHistory =
        historyOverride ?? await messageRepo.getMessagesForChat(chat.id);

    // 2. 基于完整历史计算合成XML (此结果用于函数返回值和最终状态)。
    final totalCarriedOverResult = _calculateCurrentCarriedOverXml(
      chat,
      fullHistory,
    );
    final String? calculatedCarriedOverXml = totalCarriedOverResult.xmlString;

    // --- 新逻辑：计算用于注入到提示词中的、经过特殊处理的XML ---
    String? mergedXmlForInjection;
    // 寻找*完整*历史记录中的最后一条模型消息，以决定要排除什么。
    final lastModelMessageInFullHistory = fullHistory.lastWhereOrNull(
      (m) => m.role == MessageRole.model,
    );

    // 条件：有2条或更多消息贡献了XML状态。
    if (totalCarriedOverResult.contributingMessageCount >= 2) {
      // 创建一个不包含最后一条模型消息的历史记录列表（如果存在）。
      final historyForMergeCalculation = lastModelMessageInFullHistory != null
          ? fullHistory
                .where((m) => m.id != lastModelMessageInFullHistory.id)
                .toList()
          : fullHistory;

      // 使用缩减后的历史记录重新计算合并的XML。
      // 这个结果仅用于注入到提示词中。
      final partialCarriedOverResult = _calculateCurrentCarriedOverXml(
        chat,
        historyForMergeCalculation,
      );
      mergedXmlForInjection = partialCarriedOverResult.xmlString;
    }

    // --- 1. Prepare all "fixed" (non-history) context parts ---
    final List<LlmContent> fixedContextParts = [];
    final effectiveSystemPrompt = chatSystemPromptOverride ?? chat.systemPrompt;
    final bool systemPromptExists =
        effectiveSystemPrompt != null &&
        effectiveSystemPrompt.trim().isNotEmpty;
    final bool xmlExists =
        calculatedCarriedOverXml != null && calculatedCarriedOverXml.isNotEmpty;

    if (systemPromptExists) {
      fixedContextParts.add(
        LlmContent("system", [LlmTextPart(effectiveSystemPrompt)]),
      );
    }

    final bool shouldDemoteSystemPrompt =
        !(keepAsSystemPrompt ?? (chatSystemPromptOverride == null));
    if (shouldDemoteSystemPrompt &&
        (chat.systemPrompt != null && chat.systemPrompt!.trim().isNotEmpty)) {
      fixedContextParts.add(
        LlmContent("user", [LlmTextPart(chat.systemPrompt!)]),
      );
    }

    // --- 2. Calculate budget for history ---
    int fixedTokens = 0;
    int fixedTurns = 0;
    int historyTokenBudget = chat.contextConfig.maxContextTokens ?? 256000;
    int historyTurnBudget = chat.contextConfig.maxTurns;

    if (fixedContextParts.isNotEmpty) {
      try {
        final tokenFutures = fixedContextParts.map(
          (part) =>
              llmService.countTokens(llmContext: [part], apiConfig: apiConfig),
        );
        final tokenCounts = await Future.wait(tokenFutures);
        fixedTokens = tokenCounts.sum;
      } catch (e) {
        return ApiRequestContext(
          contextParts: [],
          carriedOverXml: calculatedCarriedOverXml,
          droppedMessages: fullHistory,
          keptMessages: const [],
        );
      }
    }

    // Carried-over XML counts as one turn if it exists. Summary is now part of history.
    if (xmlExists) {
      // fixedTurns = 1; // Per user feedback, XML should not reduce the turn limit.
    }

    historyTokenBudget =
        (chat.contextConfig.maxContextTokens ?? 256000) - fixedTokens;
    historyTurnBudget = chat.contextConfig.maxTurns - fixedTurns;

    // 3. 在内存中应用总结锚点，为上下文窗口准备历史记录。
    // 这确保了XML计算不受影响，但上下文窗口从正确的点开始。
    List<Message> historyForWindowing;
    if (chat.lastSummarizedMessageId != null &&
        chat.lastSummarizedMessageId! > 0) {
      // FINAL FIX: The most robust method. Find the index of the boundary message
      // in the chronologically sorted full history, and take all messages after it.
      // This handles both timestamp collisions and user-inserted messages correctly.
      final boundaryIndex = fullHistory.indexWhere(
        (m) => m.id == chat.lastSummarizedMessageId!,
      );
      if (boundaryIndex != -1) {
        historyForWindowing = fullHistory.sublist(boundaryIndex + 1);
      } else {
        // Fallback: If the boundary message was deleted, use the full history to avoid breaking the chat.
        historyForWindowing = fullHistory;
      }
    } else {
      // No boundary set, use the full history.
      historyForWindowing = fullHistory;
    }

    // --- 4. Limit history using the calculated budget ---
    final historyResult = await _limitHistoryForPrompt(
      chatId: chatId,
      fullHistory: historyForWindowing, // 使用经过锚点过滤后的历史
      historyTokenBudget: historyTokenBudget,
      historyTurnBudget: historyTurnBudget,
    );
    final List<Message> limitedHistoryForPrompt = historyResult.kept;
    final List<Message> droppedMessages = historyResult.dropped;

    // Final check: Pre-emptively calculate if the current user message will cause
    // the context to exceed the budget. If so, drop the oldest messages from the
    // kept history and add them to the dropped list. This ensures the trigger
    // logic in `executePreprocessing` fires at the correct time (when the budget
    // is full), not one turn later.
    // FINAL FIX: This entire block should ONLY run during a prediction, not during
    // a normal context build for sending a message or viewing debug info.
    if (isPrediction) {
      switch (chat.contextConfig.mode) {
        case ContextManagementMode.turns:
          final turnLimit = (chat.contextConfig.maxTurns - fixedTurns) * 2;
          // The +1 represents the incoming user message.
          if (limitedHistoryForPrompt.length + 1 > turnLimit &&
              limitedHistoryForPrompt.isNotEmpty) {
            final oldestKeptMessage = limitedHistoryForPrompt.removeAt(0);
            // FIX: Append to the end to maintain chronological order.
            droppedMessages.add(oldestKeptMessage);
          }
          break;
        case ContextManagementMode.tokens:
          // For token mode, we must perform a more expensive check.
          final tokensForCurrentUserMessage = await llmService.countTokens(
            llmContext: [LlmContent.fromMessage(currentUserMessage)],
            apiConfig: apiConfig,
          );

          // We must recalculate the total tokens of the kept history to see if adding the new message fits.
          final tokenFutures = limitedHistoryForPrompt.map(
            (msg) => llmService.countTokens(
              llmContext: [LlmContent.fromMessage(msg)],
              apiConfig: apiConfig,
            ),
          );
          final historyTokenCounts = await Future.wait(tokenFutures);
          final currentHistoryTokens = historyTokenCounts.sum;

          if (currentHistoryTokens + tokensForCurrentUserMessage >
              historyTokenBudget) {
            int excessTokens =
                (currentHistoryTokens + tokensForCurrentUserMessage) -
                historyTokenBudget;
            int tokensAccountedForDrop = 0;
            int messagesToDropCount = 0;

            // Iterate from oldest to newest, accumulating tokens to drop.
            for (final tokenCount in historyTokenCounts) {
              tokensAccountedForDrop += tokenCount;
              messagesToDropCount++;
              if (tokensAccountedForDrop >= excessTokens) {
                break;
              }
            }

            if (messagesToDropCount > 0) {
              final messagesToDrop = limitedHistoryForPrompt.sublist(
                0,
                messagesToDropCount,
              );
              // FIX: Append to the end to maintain chronological order.
              droppedMessages.addAll(messagesToDrop);
              limitedHistoryForPrompt.removeRange(0, messagesToDropCount);
            }
          }
          break;
      }
    }

    // --- 4. Assemble the final context ---
    final List<LlmContent> finalContextParts = List.from(fixedContextParts);
    final bool summaryExists =
        chat.contextSummary != null && chat.contextSummary!.trim().isNotEmpty;

    // NEW: Handle summary injection before processing history
    if (summaryExists && limitedHistoryForPrompt.isNotEmpty) {
      final firstMessage = limitedHistoryForPrompt.first;
      // If the first message is NOT a model, we inject a new model message here.
      if (firstMessage.role != MessageRole.model) {
        finalContextParts.add(
          LlmContent("model", [LlmTextPart(chat.contextSummary!)]),
        );
      }
    }

    // 在*有限*历史记录中找到最后两个用户消息，以便注入XML。
    final userMessagesInHistory = limitedHistoryForPrompt
        .where((m) => m.role == MessageRole.user)
        .toList();
    final lastUserMessageInHistory = userMessagesInHistory.lastOrNull;
    final previousUserMessageInHistory = userMessagesInHistory.length > 1
        ? userMessagesInHistory[userMessagesInHistory.length - 2]
        : null;
    final lastModelMessageInHistory = limitedHistoryForPrompt.lastWhereOrNull(
      (m) => m.role == MessageRole.model,
    );

    for (final message in limitedHistoryForPrompt) {
      final isFirstMessageInHistory =
          message.id == limitedHistoryForPrompt.firstOrNull?.id;

      if (message.role == MessageRole.model) {
        final List<LlmPart> modelParts = [];

        // NEW: Prepend summary if this is the first message and it's a model message
        if (summaryExists &&
            isFirstMessageInHistory &&
            message.role == MessageRole.model) {
          modelParts.add(LlmTextPart("${chat.contextSummary!}\n"));
        }

        // Add text parts, stripping ignored XML
        // 抽象统一转换
        final allParts = LlmContent.toLlmParts(message.parts);
        for (final part in allParts) {
          if (part is LlmTextPart) {
            final filteredText = (message.id == messageIdToPreserveXml)
                ? part.text
                : XmlProcessor.stripIgnoredXmlContent(part.text, chat.xmlRules);
            if (filteredText.isNotEmpty) {
              modelParts.add(LlmTextPart(filteredText));
            }
          } else {
            modelParts.add(part);
          }
        }

        // ONLY for the last model message, append its original XML
        if (message.id == lastModelMessageInHistory?.id) {
          final originalXml = chat.enableSecondaryXml
              ? message.secondaryXmlContent
              : message.originalXmlContent;
          if (originalXml != null && originalXml.isNotEmpty) {
            modelParts.add(LlmTextPart(originalXml));
          }
        }

        if (modelParts.isNotEmpty) {
          finalContextParts.add(
            LlmContent("model", modelParts, messageId: message.id),
          );
        }
      } else if (message.role == MessageRole.user) {
        // --- 用户消息处理逻辑重构 ---
        final isLastUserMessage = message.id == lastUserMessageInHistory?.id;
        final isPreviousUserMessage =
            message.id == previousUserMessageInHistory?.id;

        // 1. 对于倒数第二条用户消息：附加合并后的XML（如果存在）
        if (isPreviousUserMessage &&
            mergedXmlForInjection != null &&
            mergedXmlForInjection.isNotEmpty) {
          final userParts = LlmContent.toLlmParts(message.parts);
          userParts.add(LlmTextPart('\n$mergedXmlForInjection'));
          finalContextParts.add(
            LlmContent("user", userParts, messageId: message.id),
          );

          // 2. 对于最后一条用户消息：应用覆盖并附加其自身的原始XML
        } else if (isLastUserMessage) {
          final List<LlmPart> combinedUserParts = [];
          // 添加当前用户消息文本（或覆盖文本）
          final userText = lastMessageOverride ?? message.rawText;
          if (userText.isNotEmpty) {
            combinedUserParts.add(LlmTextPart(userText));
          }
          // 抽象统一转换
          combinedUserParts.addAll(
            LlmContent.toLlmParts(
              message.parts
                  .where((p) => p.type != MessagePartType.text)
                  .toList(),
            ),
          );
          // 添加当前用户消息自身的原始XML
          final originalUserXml = chat.enableSecondaryXml
              ? message.secondaryXmlContent
              : message.originalXmlContent;
          if (originalUserXml != null && originalUserXml.isNotEmpty) {
            combinedUserParts.add(LlmTextPart(originalUserXml));
          }
          if (combinedUserParts.isNotEmpty) {
            finalContextParts.add(
              LlmContent("user", combinedUserParts, messageId: message.id),
            );
          }

          // 3. 对于所有其他历史用户消息：正常添加
        } else {
          finalContextParts.add(LlmContent.fromMessage(message));
        }
      }
    }

    // Handle case where there's no user message in history but an override is present
    if (lastUserMessageInHistory == null &&
        lastMessageOverride != null &&
        lastMessageOverride.isNotEmpty) {
      finalContextParts.add(
        LlmContent("user", [LlmTextPart(lastMessageOverride)]),
      );
    } else if (lastMessageOverride != null && lastMessageOverride.isNotEmpty) {
      // NEW LOGIC: If an override is provided, always append it as the very last user message.
      // This is crucial for special actions like "Secondary XML" or "Help Me Reply"
      // which need to add a final instruction after the full context.
      finalContextParts.add(
        LlmContent("user", [LlmTextPart(lastMessageOverride)]),
      );
    }

    final mergedContext = _mergeConsecutiveMessages(finalContextParts);

    return ApiRequestContext(
      contextParts: mergedContext,
      carriedOverXml: calculatedCarriedOverXml,
      droppedMessages: droppedMessages,
      keptMessages: limitedHistoryForPrompt,
    );
  }

  /// A final processing step to merge consecutive LlmContent parts with the same role.
  /// This ensures the final context sent to the API adheres to the alternating user/model format.
  List<LlmContent> _mergeConsecutiveMessages(List<LlmContent> originalParts) {
    if (originalParts.length < 2) {
      return originalParts;
    }

    final List<LlmContent> mergedParts = [];
    final List<LlmContent> processingQueue = List.from(originalParts);

    LlmContent accumulator = processingQueue.removeAt(0);

    while (processingQueue.isNotEmpty) {
      final current = processingQueue.removeAt(0);

      if (accumulator.role == current.role) {
        // Roles are the same, merge them.
        final List<LlmPart> combinedParts = List.from(accumulator.parts);

        // Smart text merging: if the last part of the accumulator and the first part
        // of the current content are both text, merge them with a newline.
        if (combinedParts.isNotEmpty &&
            combinedParts.last is LlmTextPart &&
            current.parts.isNotEmpty &&
            current.parts.first is LlmTextPart) {
          final lastTextPart = combinedParts.removeLast() as LlmTextPart;
          final firstTextPart = current.parts.first as LlmTextPart;

          final mergedText = '${lastTextPart.text}\n${firstTextPart.text}'
              .trim();
          if (mergedText.isNotEmpty) {
            combinedParts.add(LlmTextPart(mergedText));
          }

          // Add remaining parts from current, skipping the one we just merged
          combinedParts.addAll(current.parts.skip(1));
        } else {
          // Simple concatenation for non-text or non-adjacent text parts
          combinedParts.addAll(current.parts);
        }

        // Create a new LlmContent with the merged parts.
        // We keep the messageId of the first message in the sequence.
        accumulator = LlmContent(
          accumulator.role,
          combinedParts,
          messageId: accumulator.messageId,
        );
      } else {
        // Roles are different, push the accumulator and start a new one.
        mergedParts.add(accumulator);
        accumulator = current;
      }
    }

    // Add the last accumulated part
    mergedParts.add(accumulator);

    return mergedParts;
  }

  /// Predicts future context usage to proactively trigger summarization.
  Future<ContextPredictionResult> predictContextUsage({
    required int chatId,
  }) async {
    final chat = (await _ref.read(chatRepositoryProvider).getChat(chatId))!;
    final config = chat.contextConfig;

    // Use a placeholder message for prediction.
    final placeholderMessage = Message(
      chatId: chatId,
      role: MessageRole.user,
      parts: [MessagePart.text("prediction")],
    );

    // Build the context as if a new message arrived.
    final contextResult = await buildApiRequestContext(
      chatId: chatId,
      currentUserMessage: placeholderMessage,
      isPrediction:
          true, // FINAL FIX: Explicitly tell the builder this is a prediction call
    );

    bool willExceed = false;
    switch (config.mode) {
      case ContextManagementMode.turns:
        // For turns, if any message was dropped by the pre-emptive check in buildApiRequestContext,
        // it means we are at capacity and the next turn will exceed.
        if (contextResult.droppedMessages.isNotEmpty) {
          willExceed = true;
        }
        break;
      case ContextManagementMode.tokens:
        // For tokens, we check if the current kept context + predicted tokens exceeds the budget.
        final llmService = _ref.read(llmServiceProvider);
        final apiConfig = _ref
            .read(chatStateNotifierProvider(chatId).notifier)
            .getEffectiveApiConfig();

        final tokenFutures = contextResult.keptMessages.map(
          (msg) => llmService.countTokens(
            llmContext: [LlmContent.fromMessage(msg)],
            apiConfig: apiConfig,
          ),
        );
        final historyTokenCounts = await Future.wait(tokenFutures);
        final currentHistoryTokens = historyTokenCounts.sum;

        final predictedTokens = config.predictedTurnTokens ?? 1024;

        if (currentHistoryTokens + predictedTokens >
            (config.maxContextTokens ?? 256000)) {
          willExceed = true;
        }
        break;
    }

    return ContextPredictionResult(
      willExceed: willExceed,
      keptMessages: contextResult.keptMessages,
      droppedMessages: contextResult.droppedMessages,
    );
  }
}

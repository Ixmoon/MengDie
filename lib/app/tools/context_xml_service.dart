// 本文件包含 ContextXmlService，一个核心服务，负责构建与大语言模型 (LLM) API 交互所需的最终上下文。
//
// 主要功能:
// 1.  精确的上下文构建:
//     - `buildApiRequestContext` 是核心方法，它负责整合所有上下文部分，包括系统提示词、被降级的系统提示词（用于特殊操作）、
//       上下文摘要以及从历史消息中计算出的“携带”XML。
//     - 它实现了“先计算固定开销，后用剩余预算截断历史”的精确模式，确保最终发送的上下文严格遵守用户设置的 `maxTokens` 和 `maxTurns` 限制。
// 2.  高性能的 Token 计算:
//     - 利用 `Future.wait` 并行计算所有非历史记录部分（如系统提示、摘要等）的 Token 数量，以减少延迟。
// 3.  历史记录截断:
//     - `_limitHistoryForPrompt` 辅助方法根据 `buildApiRequestContext` 计算出的精确预算（Token 和轮次），对历史消息进行截断。
// 4.  携带 XML 计算:
//     - `_calculateCurrentCarriedOverXml` 方法遍历完整的消息历史，根据聊天中定义的 XML 规则（保存/更新），计算出在当前轮次需要“携带”的累积 XML 状态。
// 5.  灵活性:
//     - `buildApiRequestContext` 支持 `historyOverride` 参数，允许调用者传入自定义的消息列表进行上下文构建，
//       这对于实现如“分块摘要”等高级功能至关重要，因为它复用了服务的精确截断逻辑。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart' as xml_pkg; // For XmlDocument, XmlElement, XmlName during recalculation

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

class ApiRequestContext {
  final List<LlmContent> contextParts;
  final String? carriedOverXml;
  final List<Message> droppedMessages;

  ApiRequestContext({
    required this.contextParts,
    this.carriedOverXml,
    required this.droppedMessages,
  });
}

// Helper class for partitioning history
class _HistoryLimitResult {
  final List<Message> kept;
  final List<Message> dropped;
  _HistoryLimitResult(this.kept, this.dropped);
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
  String? _calculateCurrentCarriedOverXml(Chat chat, List<Message> fullHistory) {
    if (fullHistory.isEmpty) {
      return null;
    }

    final tagRuleInfoMap = <String, XmlRule>{};
    for (final rule in chat.xmlRules) {
      if (rule.tagName != null && (rule.action == XmlAction.update || rule.action == XmlAction.save)) {
        tagRuleInfoMap[rule.tagName!.toLowerCase()] = rule;
      }
    }

    Map<String, String> cumulativeStateMap = {};

    for (int i = 0; i < fullHistory.length; i++) {
      final msg = fullHistory[i];
      // XML calculation should only consider model messages.
      if (msg.role != MessageRole.model) {
        continue;
      }

      // FIX: Construct the full XML text for parsing by respecting the chat setting.
      // If secondary XML is enabled, use it; otherwise, use the original.
      // This ensures that the context calculation uses the correct, separated XML fields.
      final xmlContent = chat.enableSecondaryXml
          ? msg.secondaryXmlContent
          : msg.originalXmlContent;

      // Combine the display text with the appropriate XML content.
      // The rawText (which is now just displayText) might contain other things,
      // but for XML calculation, we prioritize the dedicated fields.
      final fullTextForXmlParsing = '${msg.rawText}\n${xmlContent ?? ''}'.trim();

      if (fullTextForXmlParsing.isEmpty || !fullTextForXmlParsing.contains('<')) {
        continue;
      }

      xml_pkg.XmlDocument? doc;
      try {
        // Attempt to parse the combined text.
        doc = xml_pkg.XmlDocument.parse('<root>$fullTextForXmlParsing</root>');
      } catch (e) {
        debugPrint("ContextXmlService:_calculateCurrentCarriedOverXml - Failed to parse XML in message ID ${msg.id}: $e. Skipping message for XML calculation.");
        continue;
      }

      for (final element in doc.rootElement.children.whereType<xml_pkg.XmlElement>()) {
        final originalTagNameFromElement = element.name.local;
        final tagNameLower = originalTagNameFromElement.toLowerCase();
        final rule = tagRuleInfoMap[tagNameLower];

        if (rule != null) {
          final action = rule.action;
          final currentInnerXmlTrimmed = element.innerXml.trim();
          final String? existingKeyInCumulativeMap = cumulativeStateMap.keys.firstWhereOrNull((k) => k.toLowerCase() == tagNameLower);
          final String keyToUseForCumulativeMap = existingKeyInCumulativeMap ?? originalTagNameFromElement;

          if (action == XmlAction.save) {
            if (currentInnerXmlTrimmed.isNotEmpty) {
              cumulativeStateMap[keyToUseForCumulativeMap] = currentInnerXmlTrimmed;
            } else {
              cumulativeStateMap.remove(keyToUseForCumulativeMap);
            }
          } else if (action == XmlAction.update) {
            final previousInnerXmlFromCumulative = cumulativeStateMap[keyToUseForCumulativeMap];
            if (previousInnerXmlFromCumulative != null && previousInnerXmlFromCumulative.isNotEmpty) {
              if (currentInnerXmlTrimmed.isNotEmpty) {
                try {
                  final baseDoc = xml_pkg.XmlDocument.parse('<root>$previousInnerXmlFromCumulative</root>');
                  final updateDoc = xml_pkg.XmlDocument.parse('<root>$currentInnerXmlTrimmed</root>');
                  final mergedChildren = XmlProcessor.mergeNodeLists(baseDoc.rootElement.children, updateDoc.rootElement.children);
                  final tempMergedElement = xml_pkg.XmlElement(xml_pkg.XmlName('temp'), [], mergedChildren);
                  final mergedInnerXmlTrimmed = tempMergedElement.innerXml.trim();

                  if (mergedInnerXmlTrimmed.isNotEmpty) {
                    cumulativeStateMap[keyToUseForCumulativeMap] = mergedInnerXmlTrimmed;
                  } else {
                    cumulativeStateMap.remove(keyToUseForCumulativeMap);
                  }
                } catch (e) {
                  debugPrint("  ContextXmlService:_calculateCurrentCarriedOverXml - Merge failed for <$originalTagNameFromElement> (key '$keyToUseForCumulativeMap'): $e. Retaining previous.");
                }
              } else {
                cumulativeStateMap.remove(keyToUseForCumulativeMap); // Current is empty, so remove.
              }
            } else { // No previous state or previous was empty.
              if (currentInnerXmlTrimmed.isNotEmpty) {
                cumulativeStateMap[keyToUseForCumulativeMap] = currentInnerXmlTrimmed; // Treat as save.
              } else {
                cumulativeStateMap.remove(keyToUseForCumulativeMap); // Both empty, ensure removed.
              }
            }
          }
        }
      }
    }
    return XmlProcessor.serializeCarriedOver(cumulativeStateMap);
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
        final dropped = fullHistory.sublist(0, fullHistory.length - turnLimit);
        return _HistoryLimitResult(kept, dropped);
      }
      return _HistoryLimitResult(fullHistory, []);

    // --- B) Limit by Tokens ---
    case ContextManagementMode.tokens:
      if (historyTokenBudget <= 0) {
        return _HistoryLimitResult([], fullHistory);
      }
      
      final llmService = _ref.read(llmServiceProvider);
      debugPrint("ContextXmlService: Limiting history by tokens. Budget: $historyTokenBudget");

      try {
        final apiConfig = _ref.read(chatStateNotifierProvider(chatId).notifier).getEffectiveApiConfig();
        final tokenFutures = fullHistory.map((msg) {
          return llmService.countTokens(llmContext: [LlmContent.fromMessage(msg)], apiConfig: apiConfig)
            .then((count) => {'message': msg, 'tokens': count})
            .catchError((e) {
              debugPrint("  - Token counting failed for message ID ${msg.id}: $e. Counting as 0.");
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

        debugPrint("  - Token count is within budget. Kept ${keptHistory.length} messages with $currentTotalTokens tokens.");
        final Set<int> keptIds = keptHistory.map((m) => m.id).toSet();
        final List<Message> droppedHistory = fullHistory.where((m) => !keptIds.contains(m.id)).toList();

        return _HistoryLimitResult(keptHistory, droppedHistory);
      } catch (e) {
        debugPrint("  - Token counting process failed during history limitation: $e. Aborting safely.");
        return _HistoryLimitResult([], fullHistory);
      }
    // No default needed as all enum cases are handled.
  }
}

/// Builds the list of LlmContent to be sent to the LLM API, respecting all context rules.
/// This is the primary method for constructing the prompt.
///
/// The new logic is:
/// 1. Concurrently calculate tokens for all "fixed" context parts (system prompt, summary, XML).
/// 2. Calculate the remaining token and turn budget for the message history.
/// 3. Call a helper to truncate the message history within this specific budget.
/// 4. Assemble all parts into the final context.
Future<ApiRequestContext> buildApiRequestContext({
  required int chatId, // 重构：传入 chatId
  required Message currentUserMessage,
  String? lastMessageOverride,
  int? messageIdToPreserveXml,
  String? chatSystemPromptOverride,
  bool? keepAsSystemPrompt,
  List<Message>? historyOverride, // New: Allows providing a custom history list, skipping DB fetch.
}) async {
  final messageRepo = _ref.read(messageRepositoryProvider);
  final llmService = _ref.read(llmServiceProvider);
  // 重构：从 Notifier 获取 chat 和 apiConfig
  final notifier = _ref.read(chatStateNotifierProvider(chatId).notifier);
  final chat = (await _ref.read(chatRepositoryProvider).getChat(chatId))!;
  final apiConfig = notifier.getEffectiveApiConfig();

  // Use the historyOverride if provided, otherwise fetch from the database.
  final List<Message> fullHistory = historyOverride ?? await messageRepo.getMessagesForChat(chat.id);

  final String? calculatedCarriedOverXml = _calculateCurrentCarriedOverXml(chat, fullHistory);

  // --- 1. Prepare all "fixed" (non-history) context parts ---
  final List<LlmContent> fixedContextParts = [];
  final effectiveSystemPrompt = chatSystemPromptOverride ?? chat.systemPrompt;
  final bool systemPromptExists = effectiveSystemPrompt != null && effectiveSystemPrompt.trim().isNotEmpty;
  final bool summaryExists = chat.contextSummary != null && chat.contextSummary!.trim().isNotEmpty;
  final bool xmlExists = calculatedCarriedOverXml != null && calculatedCarriedOverXml.isNotEmpty;

  if (systemPromptExists) {
    fixedContextParts.add(LlmContent("system", [LlmTextPart(effectiveSystemPrompt)]));
  }

  final bool shouldDemoteSystemPrompt = !(keepAsSystemPrompt ?? (chatSystemPromptOverride == null));
  if (shouldDemoteSystemPrompt && (chat.systemPrompt != null && chat.systemPrompt!.trim().isNotEmpty)) {
     fixedContextParts.add(LlmContent("user", [LlmTextPart(chat.systemPrompt!)]));
  }

  if (summaryExists) {
    fixedContextParts.add(LlmContent("user", [LlmTextPart(chat.contextSummary!)]));
  }
  if (xmlExists) {
    fixedContextParts.add(LlmContent("user", [LlmTextPart(calculatedCarriedOverXml)]));
  }

  // --- 2. Calculate budget for history ---
  int fixedTokens = 0;
  int fixedTurns = 0; // Summary and/or XML count as one turn
  int historyTokenBudget = chat.contextConfig.maxContextTokens ?? 256000;
  int historyTurnBudget = chat.contextConfig.maxTurns;

  // Concurrently calculate tokens for all fixed parts
  if (fixedContextParts.isNotEmpty) {
    try {
      final tokenFutures = fixedContextParts.map((part) => llmService.countTokens(llmContext: [part], apiConfig: apiConfig));
      final tokenCounts = await Future.wait(tokenFutures);
      fixedTokens = tokenCounts.sum;
      debugPrint("ContextXmlService: Calculated fixed tokens: $fixedTokens");
    } catch (e) {
      debugPrint("ContextXmlService: Error calculating fixed tokens: $e. Aborting.");
      // If we can't calculate fixed tokens, we can't safely build context.
      return ApiRequestContext(contextParts: [], carriedOverXml: calculatedCarriedOverXml, droppedMessages: fullHistory);
    }
  }

  if (summaryExists || xmlExists) {
    fixedTurns = 1;
  }

  historyTokenBudget = (chat.contextConfig.maxContextTokens ?? 256000) - fixedTokens;
  historyTurnBudget = chat.contextConfig.maxTurns - fixedTurns;

  // --- 3. Limit history using the calculated budget ---
  final historyResult = await _limitHistoryForPrompt(
    chatId: chatId,
    fullHistory: fullHistory,
    historyTokenBudget: historyTokenBudget,
    historyTurnBudget: historyTurnBudget,
  );
  final List<Message> limitedHistoryForPrompt = historyResult.kept;
  final List<Message> droppedMessages = historyResult.dropped;

  // --- 4. Assemble the final context ---
  final List<LlmContent> finalContextParts = List.from(fixedContextParts);

  for (final message in limitedHistoryForPrompt) {
    if (message.role == MessageRole.model) {
      // For model messages, we manually build the LlmContent to handle XML stripping.
      final List<LlmPart> modelParts = [];
      for (final part in message.parts) {
        if (part.type == MessagePartType.text && part.text != null) {
          // Apply XML stripping only to the text part of model messages.
          final filteredText = (message.id == messageIdToPreserveXml)
              ? part.text!
              : XmlProcessor.stripXmlContent(part.text!);
          if (filteredText.isNotEmpty) {
            modelParts.add(LlmTextPart(filteredText));
          }
        } else {
          // For non-text parts (like generated images), convert them directly.
          final llmPart = LlmContent.fromMessage(Message(chatId: chatId, role: MessageRole.model, parts: [part])).parts.firstOrNull;
          if (llmPart != null) {
            modelParts.add(llmPart);
          }
        }
      }
      if (modelParts.isNotEmpty) {
        finalContextParts.add(LlmContent("model", modelParts));
      }
    } else {
      // For user messages, the standard conversion is sufficient.
      finalContextParts.add(LlmContent.fromMessage(message));
    }
  }

  if (lastMessageOverride != null && lastMessageOverride.isNotEmpty) {
    finalContextParts.add(LlmContent("user", [LlmTextPart(lastMessageOverride)]));
  }
  
  debugPrint("ContextXmlService:buildApiRequestContext - Returning context with ${finalContextParts.length} parts. Kept ${limitedHistoryForPrompt.length} history messages, dropped ${droppedMessages.length}.");

  return ApiRequestContext(
    contextParts: finalContextParts,
    carriedOverXml: calculatedCarriedOverXml,
    droppedMessages: droppedMessages,
  );
}
}

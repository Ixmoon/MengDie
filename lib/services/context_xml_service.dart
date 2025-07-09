import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart'; 
import 'package:xml/xml.dart' as xml_pkg; // For XmlDocument, XmlElement, XmlName during recalculation

import '../models/models.dart';
import '../data/database/drift/models/drift_xml_rule.dart'; // Import DriftXmlRule
import '../data/database/drift/common_enums.dart' as drift_enums; // For XmlAction during recalculation
import '../repositories/message_repository.dart'; // For MessageRepository
import 'xml_processor.dart';
import 'llm_service.dart'; // For LlmContent, LlmTextPart
import 'package:collection/collection.dart'; // For lastWhereOrNull

// Define a return type for buildApiRequestContext
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

    final tagRuleInfoMap = <String, DriftXmlRule>{};
    for (final rule in chat.xmlRules) {
      if (rule.tagName != null && (rule.action == drift_enums.XmlAction.update || rule.action == drift_enums.XmlAction.save)) {
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

          if (action == drift_enums.XmlAction.save) {
            if (currentInnerXmlTrimmed.isNotEmpty) {
              cumulativeStateMap[keyToUseForCumulativeMap] = currentInnerXmlTrimmed;
            } else {
              cumulativeStateMap.remove(keyToUseForCumulativeMap);
            }
          } else if (action == drift_enums.XmlAction.update) {
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
  Future<_HistoryLimitResult> _limitHistoryForPrompt(Chat chat, List<Message> fullHistory) async {
    if (fullHistory.isEmpty) return _HistoryLimitResult([], []);

    try {
      if (chat.contextConfig.mode == ContextManagementMode.turns) {
        final limit = chat.contextConfig.maxTurns * 2;
        if (limit <= 0) return _HistoryLimitResult([], fullHistory);
        if (fullHistory.length > limit) {
          return _HistoryLimitResult(
            fullHistory.sublist(fullHistory.length - limit),
            fullHistory.sublist(0, fullHistory.length - limit),
          );
        }
        return _HistoryLimitResult(fullHistory, []);
      } else if (chat.contextConfig.mode == ContextManagementMode.tokens && chat.contextConfig.maxContextTokens != null) {
        final llmService = _ref.read(llmServiceProvider);
        final maxTokens = chat.contextConfig.maxContextTokens!;
        debugPrint("ContextXmlService: Limiting context by tokens. Budget: $maxTokens");
        
        // Start with the full history and iteratively remove oldest messages until token count is within budget.
        List<Message> keptHistory = List.from(fullHistory);
        List<Message> droppedHistory = [];

        while (keptHistory.isNotEmpty) {
          final contextParts = keptHistory.map(LlmContent.fromMessage).toList();
          final currentTokens = await llmService.countTokens(llmContext: contextParts, chat: chat);
          debugPrint("  - Checking ${keptHistory.length} messages... Current Tokens: $currentTokens");

          if (currentTokens > 0 && currentTokens <= maxTokens) {
            // Token count is within budget, we're done.
            debugPrint("  - Token count is within budget. Kept ${keptHistory.length}, Dropped ${droppedHistory.length}.");
            return _HistoryLimitResult(keptHistory, droppedHistory.reversed.toList());
          } else if (currentTokens <= 0) {
            debugPrint("  - Token count is invalid ($currentTokens). Cannot proceed with token-based limiting. Aborting.");
            // If token counting fails, it's safer to drop everything than to send a potentially huge context.
            return _HistoryLimitResult([], fullHistory);
          }
          else {
            // Token count exceeds budget, remove the oldest message and try again.
            final droppedMessage = keptHistory.removeAt(0);
            droppedHistory.add(droppedMessage);
            debugPrint("  - Token count exceeds budget. Dropping oldest message (ID: ${droppedMessage.id}).");
          }
        }

        // If the loop finishes, it means even a single message exceeds the budget,
        // or the history was empty to begin with. Return everything as dropped.
        debugPrint("ContextXmlService: Token limiting resulted in dropping all messages.");
        return _HistoryLimitResult([], fullHistory);
      } else {
        // Fallback to default turn-based limiting
        final limit = chat.contextConfig.maxTurns * 2;
        if (limit <= 0) return _HistoryLimitResult([], fullHistory);
        if (fullHistory.length > limit) {
          return _HistoryLimitResult(
            fullHistory.sublist(fullHistory.length - limit),
            fullHistory.sublist(0, fullHistory.length - limit),
          );
        }
        return _HistoryLimitResult(fullHistory, []);
      }
    } catch (e) {
      debugPrint("ContextXmlService:_limitHistoryForPrompt - Error limiting history: $e");
      return _HistoryLimitResult([], fullHistory); // On error, drop everything to be safe
    }
  }


  /// Builds the list of LlmContent to be sent to the LLM API and the determined carriedOverXml.
  Future<ApiRequestContext> buildApiRequestContext({
    required Chat chat,
    required Message currentUserMessage,
    String? lastMessageOverride,
    int? messageIdToPreserveXml, // New parameter for resuming generation
  }) async {
    final messageRepo = _ref.read(messageRepositoryProvider);
    final List<Message> fullHistory = await messageRepo.getMessagesForChat(chat.id);

    final String? calculatedCarriedOverXml = _calculateCurrentCarriedOverXml(chat, fullHistory);
    
    // Now an async method
    final historyResult = await _limitHistoryForPrompt(chat, fullHistory);
    final List<Message> limitedHistoryForPrompt = historyResult.kept;
    final List<Message> droppedMessages = historyResult.dropped;

    final List<LlmContent> contextParts = [];
    final bool systemPromptExists = chat.systemPrompt != null && chat.systemPrompt!.trim().isNotEmpty;
    final bool summaryExists = chat.contextSummary != null && chat.contextSummary!.trim().isNotEmpty;
    final bool xmlExists = calculatedCarriedOverXml != null && calculatedCarriedOverXml.isNotEmpty;

    if (systemPromptExists) {
      contextParts.add(LlmContent("system", [LlmTextPart(chat.systemPrompt!)]));
    }

    // Add summary and carried-over XML as the first user messages
    if (summaryExists) {
      contextParts.add(LlmContent("user", [LlmTextPart(XmlProcessor.wrapWithTag("context_summary", chat.contextSummary!))]));
    }
    if (xmlExists) {
      contextParts.add(LlmContent("user", [LlmTextPart(calculatedCarriedOverXml)]));
    }

    for (final message in limitedHistoryForPrompt) {
      // For model messages, strip XML. For user messages, include all parts.
      if (message.role == MessageRole.model) {
        // For resume generation, we must not strip the XML from the target message.
        if (message.id == messageIdToPreserveXml) {
          if (message.rawText.isNotEmpty) {
            contextParts.add(LlmContent("model", [LlmTextPart(message.rawText)]));
          }
        } else {
          final filteredText = XmlProcessor.stripXmlContent(message.rawText);
          if (filteredText.isNotEmpty) {
            contextParts.add(LlmContent("model", [LlmTextPart(filteredText)]));
          }
        }
      } else {
        // For user messages, convert the whole message with all its parts
        contextParts.add(LlmContent.fromMessage(message));
      }
    }

    // Add the override as the very last user message if it exists
    if (lastMessageOverride != null && lastMessageOverride.isNotEmpty) {
      contextParts.add(LlmContent("user", [LlmTextPart(lastMessageOverride)]));
    }

    if (kDebugMode) {
      int userMessages = 0;
      int modelMessages = 0;
      int systemPrompts = 0;
      for(var part in contextParts) {
        if (part.role == "user") {
          userMessages++;
        } else if (part.role == "model") {
          modelMessages++;
        } else if (part.role == "system") {
          systemPrompts++;
        }
      }
      debugPrint("ContextXmlService:buildApiRequestContext - Returning context with: $systemPrompts system, $userMessages user, $modelMessages model parts. Total: ${contextParts.length}.");
    }

    return ApiRequestContext(
      contextParts: contextParts,
      carriedOverXml: calculatedCarriedOverXml,
      droppedMessages: droppedMessages,
    );
  }

}

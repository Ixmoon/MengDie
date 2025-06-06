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
import 'dart:math'; // for min

// Define a return type for buildApiRequestContext
class ApiRequestContext {
  final List<LlmContent> contextParts;
  final String? carriedOverXml; 

  ApiRequestContext({required this.contextParts, this.carriedOverXml});
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
      // XML calculation should only consider model messages as they are the source of <carry_over_xml_content>
      // and other XML tags defined by rules.
      if (msg.role != MessageRole.model || msg.rawText.isEmpty || !msg.rawText.contains('<')) {
        continue;
      }

      xml_pkg.XmlDocument? doc;
      try {
        // Attempt to parse the rawText. If it's not well-formed XML (e.g. just plain text with a stray '<'),
        // this might fail. We wrap it in a root element to handle multiple top-level elements or text nodes.
        doc = xml_pkg.XmlDocument.parse('<root>${msg.rawText.trim()}</root>');
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
  List<Message> _limitHistoryForPrompt(Chat chat, List<Message> fullHistory, String currentUserInput) {
    // currentUserInput is passed for context (e.g., token estimation) but should already be in fullHistory if saved prior.
    // The filtering logic here should mainly focus on turns or tokens of the 'fullHistory'.
    
    if (fullHistory.isEmpty) return [];

    try {
      if (chat.contextConfig.mode == ContextManagementMode.turns) {
        final limit = chat.contextConfig.maxTurns * 2;
        if (limit <= 0) return [];
        return fullHistory.length > limit ? fullHistory.sublist(fullHistory.length - limit) : fullHistory;
      } else if (chat.contextConfig.mode == ContextManagementMode.tokens && chat.contextConfig.maxContextTokens != null) {
        final maxTokens = chat.contextConfig.maxContextTokens!;
        int currentTokens = 0;
        final List<Message> tokenLimitedHistory = [];
        // Estimate tokens for the current user input if it's not already the last message in fullHistory
        // However, ChatStateNotifier saves it first, so it should be the last one.
        // For safety, let's assume a small budget for the prompt elements themselves (system, xml).
        const int promptOverheadTokens = 50; // Rough estimate for system prompt, XML, and other formatting
        
        int budget = maxTokens - promptOverheadTokens;
        if (currentUserInput.isNotEmpty && (fullHistory.isEmpty || fullHistory.last.rawText != currentUserInput)) {
           // This case should ideally not happen if ChatStateNotifier saves user input first.
           // If it does, we need to account for currentUserInput's tokens separately.
           int currentUserInputTokens = (currentUserInput.length / 3.5).ceil();
           budget -= currentUserInputTokens;
        }


        for (int i = fullHistory.length - 1; i >= 0; i--) {
          final message = fullHistory[i];
          final textToCount = XmlProcessor.stripXmlContent(message.rawText);
          int messageTokens = (textToCount.length / 3.5).ceil();

          if (currentTokens + messageTokens <= budget) {
            currentTokens += messageTokens;
            tokenLimitedHistory.add(message);
          } else {
            break;
          }
        }
        return tokenLimitedHistory.reversed.toList();
      } else { // Default or fallback to turns-based if config is unclear
        final limit = chat.contextConfig.maxTurns * 2;
        if (limit <= 0) return [];
        return fullHistory.length > limit ? fullHistory.sublist(fullHistory.length - limit) : fullHistory;
      }
    } catch (e) {
      debugPrint("ContextXmlService:_limitHistoryForPrompt - Error limiting history: $e");
      return []; // Return empty on error to prevent issues
    }
  }


  /// Builds the list of LlmContent to be sent to the LLM API and the determined carriedOverXml.
  Future<ApiRequestContext> buildApiRequestContext({
    required Chat chat,
    required String currentUserInput, // This is the actual text from user input field
  }) async {
    final messageRepo = _ref.read(messageRepositoryProvider);
    // Assuming currentUserInput has ALREADY been saved as the latest message by ChatStateNotifier
    // So, fullHistory will include it.
    final List<Message> fullHistory = await messageRepo.getMessagesForChat(chat.id);

    final String? calculatedCarriedOverXml = _calculateCurrentCarriedOverXml(chat, fullHistory);
    
    // Limit the history for the prompt AFTER calculating XML from full history
    final List<Message> limitedHistoryForPrompt = _limitHistoryForPrompt(chat, fullHistory, currentUserInput);

    final List<LlmContent> contextParts = [];
    final bool systemPromptExists = chat.systemPrompt != null && chat.systemPrompt!.trim().isNotEmpty;
    final bool xmlExists = calculatedCarriedOverXml != null && calculatedCarriedOverXml.isNotEmpty;

    // 1. Add System Prompt (if exists)
    if (systemPromptExists) {
      contextParts.add(LlmContent("system", [LlmTextPart(chat.systemPrompt!)]));
    }

    // 2. Add XML as a new, independent user message (if it exists)
    if (xmlExists) {
      contextParts.add(LlmContent("user", [LlmTextPart(calculatedCarriedOverXml!)]));
    }

    // 3. Add all history messages from the limited set
    // currentUserInput is assumed to be the last message in limitedHistoryForPrompt if it was saved.
    for (final message in limitedHistoryForPrompt) {
      final role = message.role == MessageRole.user ? "user" : "model";
      final filteredText = XmlProcessor.stripXmlContent(message.rawText);
      // Ensure not to add empty user/model messages.
      if (filteredText.isNotEmpty) {
        contextParts.add(LlmContent(role, [LlmTextPart(filteredText)]));
      }
    }
    
    // Note: currentUserInput is NOT added separately here because it's assumed to be part of 'fullHistory'
    // and consequently part of 'limitedHistoryForPrompt' if it fits the criteria.
    // ChatStateNotifier is responsible for saving the user message to the repository *before* calling this.

    if (kDebugMode) {
      int userMessages = 0;
      int modelMessages = 0;
      int systemPrompts = 0;
      for(var part in contextParts) {
        if (part.role == "user") userMessages++;
        else if (part.role == "model") modelMessages++;
        else if (part.role == "system") systemPrompts++;
      }
      debugPrint("ContextXmlService:buildApiRequestContext - Returning context with: $systemPrompts system, $userMessages user, $modelMessages model parts. Total: ${contextParts.length}.");
      if (contextParts.isNotEmpty) {
        final lastPart = contextParts.last;
        String lastPartPreview = "N/A";
        if (lastPart.parts.isNotEmpty && lastPart.parts.first is LlmTextPart) {
          final text = (lastPart.parts.first as LlmTextPart).text;
          lastPartPreview = text.substring(0, min(text.length, 70));
        }
      } 
    }

    return ApiRequestContext(contextParts: contextParts, carriedOverXml: calculatedCarriedOverXml);
  }

}

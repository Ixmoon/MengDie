// coverage:ignore-file
// 本文件包含 LlmCoordinatorService，它作为所有 LLM 相关操作的中心协调器。
// 它实现了 LLM API 调用的中心化和内聚化，将业务逻辑与 UI 状态管理分离。
// 所有对 LlmService 的调用都应通过此类进行。

import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:xml/xml.dart' as xml_pkg;

import '../../data/llmapi/llm_service.dart';
import '../../domain/models/api_config.dart';
import '../../domain/models/message.dart';
import '../../data/llmapi/llm_models.dart';
import '../../domain/models/chat.dart';
import '../../domain/models/xml_rule.dart';
import '../../domain/enums.dart';
import '../providers/repository_providers.dart'; // FIX: Added missing import
import '../providers/chat_state_providers.dart';
import '../tools/xml_processor.dart';

// --- Coordinator Service Provider ---
final llmCoordinatorProvider = Provider<LlmCoordinatorService>((ref) {
  return LlmCoordinatorService(ref);
});

// --- Helper Classes (merged from context_xml_service) ---
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

class _HistoryLimitResult {
  final List<Message> kept;
  final List<Message> dropped;
  _HistoryLimitResult(this.kept, this.dropped);
}


// --- Centralized Coordinator Service ---
class LlmCoordinatorService {
  final Ref _ref;
  final LlmService _llmService;

  LlmCoordinatorService(this._ref) : _llmService = _ref.read(llmServiceProvider);

  // --- Public API ---

  Stream<LlmStreamChunk> generateStreamResponse({
    required int chatId,
    required ApiConfig apiConfig,
    required Message currentUserMessage,
    String? lastMessageOverride,
  }) async* {
    final apiRequestContext = await buildApiRequestContext(
      chatId: chatId,
      currentUserMessage: currentUserMessage,
      apiConfig: apiConfig,
      lastMessageOverride: lastMessageOverride,
      keepAsSystemPrompt: true,
    );
    
    yield* _llmService.sendMessageStream(
      llmContext: apiRequestContext.contextParts,
      apiConfig: apiConfig,
    );
  }

  Future<LlmResponse> generateSingleResponse({
    required int chatId,
    required ApiConfig apiConfig,
    required Message currentUserMessage,
    String? lastMessageOverride,
  }) async {
    final apiRequestContext = await buildApiRequestContext(
      chatId: chatId,
      currentUserMessage: currentUserMessage,
      apiConfig: apiConfig,
      lastMessageOverride: lastMessageOverride,
      keepAsSystemPrompt: true,
    );

    return _llmService.sendMessageOnce(
      llmContext: apiRequestContext.contextParts,
      apiConfig: apiConfig,
    );
  }

  Future<List<MessagePart>> generateImage({
    required int chatId,
    required Message userMessage,
    required ApiConfig apiConfig,
  }) async {
    final apiRequestContext = await buildApiRequestContext(
      chatId: chatId,
      currentUserMessage: userMessage,
      apiConfig: apiConfig,
      keepAsSystemPrompt: true,
    );

    final response = await _llmService.generateImage(
      llmContext: apiRequestContext.contextParts,
      apiConfig: apiConfig,
    );

    if (response.isSuccess && (response.base64Images.isNotEmpty || (response.text?.isNotEmpty ?? false))) {
      List<MessagePart> parts = [];
      if (response.text != null && response.text!.isNotEmpty) {
        parts.add(MessagePart.text(response.text!));
      }
      if (response.base64Images.isNotEmpty) {
        parts.addAll(response.base64Images.map(
          (base64) => MessagePart.generatedImage(
            base64Data: base64,
            prompt: userMessage.rawText,
          ),
        ));
      }
      return parts;
    } else {
      throw Exception(response.error ?? "Image generation failed with an unknown error.");
    }
  }

  Future<String> executeSpecialAction({
    required int chatId,
    required String prompt,
    required ApiConfig apiConfig,
    required Message targetMessage,
  }) async {
    const maxRetries = 3;

    final apiRequestContext = await buildApiRequestContext(
      chatId: chatId,
      currentUserMessage: targetMessage,
      apiConfig: apiConfig,
      chatSystemPromptOverride: prompt,
      lastMessageOverride: prompt,
      keepAsSystemPrompt: false,
    );

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final response = await _llmService.sendMessageOnce(
          llmContext: apiRequestContext.contextParts,
          apiConfig: apiConfig,
        );

        if (response.isSuccess && response.parts.isNotEmpty) {
          final generatedText = response.parts.map((p) => p.text ?? "").join("\n");
          return generatedText;
        } else {
          throw Exception("API Error: ${response.error ?? 'Empty response'}");
        }
      } catch (e) {
        if (e is DioException && e.type == DioExceptionType.cancel) {
          rethrow;
        }
        debugPrint("LlmCoordinatorService: Special action attempt $attempt/$maxRetries failed: $e");
        if (attempt == maxRetries) {
          rethrow;
        }
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
    throw Exception("Special action failed after $maxRetries attempts.");
  }

  Future<String> summarizeChunk({
    required int chatId, // FIX: Added missing chatId
    required List<Message> chunk,
    required String? previousSummary,
    required String summaryPrompt,
    required ApiConfig apiConfig,
  }) async {
    List<LlmContent> summaryContext = [
      LlmContent("system", [LlmTextPart(summaryPrompt)])
    ];

    if (previousSummary != null && previousSummary.isNotEmpty) {
      final previousSummaryText = XmlProcessor.wrapWithTag('previous_summary', previousSummary);
      summaryContext.add(LlmContent("user", [LlmTextPart(previousSummaryText)]));
    }

    for (final message in chunk) {
      summaryContext.add(LlmContent.fromMessage(message));
    }

    summaryContext.add(LlmContent("user", [LlmTextPart(summaryPrompt)]));

    final response = await _llmService.sendMessageOnce(
      llmContext: summaryContext,
      apiConfig: apiConfig,
    );

    if (response.isSuccess && response.parts.isNotEmpty) {
      return response.parts.map((p) => p.text ?? "").join("\n").trim();
    } else {
      throw Exception("API Error: ${response.error ?? 'Empty response'}");
    }
  }

  Future<List<OpenAIModel>> fetchAvailableModels(ApiConfig config) async {
    if (config.baseUrl == null || config.apiKey == null) {
      throw Exception("Base URL and API Key are required to fetch models.");
    }
    return _llmService.fetchModels(
      baseUrl: config.baseUrl!,
      apiKey: config.apiKey!,
    );
  }

  Future<void> cancelGeneration() {
    return _llmService.cancelActiveRequest();
  }

  // FIX: Added missing countTokens method
  Future<int> countTokens({
    required List<LlmContent> llmContext,
    required ApiConfig apiConfig,
  }) {
    return _llmService.countTokens(
      llmContext: llmContext,
      apiConfig: apiConfig,
    );
  }

  // --- Context Building Logic (merged from context_xml_service) ---

  Future<ApiRequestContext> buildApiRequestContext({
    required int chatId,
    required Message currentUserMessage,
    required ApiConfig apiConfig,
    String? lastMessageOverride,
    int? messageIdToPreserveXml,
    String? chatSystemPromptOverride,
    bool? keepAsSystemPrompt,
    List<Message>? historyOverride,
  }) async {
    final messageRepo = _ref.read(messageRepositoryProvider);
    final chat = (await _ref.read(chatRepositoryProvider).getChat(chatId))!;
    
    final List<Message> fullHistory = historyOverride ?? await messageRepo.getMessagesForChat(chat.id);
    final String? calculatedCarriedOverXml = _calculateCurrentCarriedOverXml(chat, fullHistory);

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

    int fixedTokens = 0;
    int fixedTurns = 0;
    int historyTokenBudget = chat.contextConfig.maxContextTokens ?? 256000;
    int historyTurnBudget = chat.contextConfig.maxTurns;

    if (fixedContextParts.isNotEmpty) {
      try {
        final tokenFutures = fixedContextParts.map((part) => _llmService.countTokens(llmContext: [part], apiConfig: apiConfig));
        final tokenCounts = await Future.wait(tokenFutures);
        fixedTokens = tokenCounts.cast<int>().sum;
        debugPrint("LlmCoordinatorService: Calculated fixed tokens: $fixedTokens");
      } catch (e) {
        debugPrint("LlmCoordinatorService: Error calculating fixed tokens: $e. Aborting.");
        return ApiRequestContext(contextParts: [], carriedOverXml: calculatedCarriedOverXml, droppedMessages: fullHistory);
      }
    }

    if (summaryExists || xmlExists) {
      fixedTurns = 1;
    }

    historyTokenBudget = (chat.contextConfig.maxContextTokens ?? 256000) - fixedTokens;
    historyTurnBudget = chat.contextConfig.maxTurns - fixedTurns;

    final historyResult = await _limitHistoryForPrompt(
      chatId: chatId,
      fullHistory: fullHistory,
      historyTokenBudget: historyTokenBudget,
      historyTurnBudget: historyTurnBudget,
      apiConfig: apiConfig,
    );
    final List<Message> limitedHistoryForPrompt = historyResult.kept;
    final List<Message> droppedMessages = historyResult.dropped;

    final List<LlmContent> finalContextParts = List.from(fixedContextParts);

    for (final message in limitedHistoryForPrompt) {
      if (message.role == MessageRole.model) {
        final List<LlmPart> modelParts = [];
        for (final part in message.parts) {
          if (part.type == MessagePartType.text && part.text != null) {
            final filteredText = (message.id == messageIdToPreserveXml)
                ? part.text!
                : XmlProcessor.stripXmlContent(part.text!);
            if (filteredText.isNotEmpty) {
              modelParts.add(LlmTextPart(filteredText));
            }
          } else {
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
        finalContextParts.add(LlmContent.fromMessage(message));
      }
    }

    if (lastMessageOverride != null && lastMessageOverride.isNotEmpty) {
      finalContextParts.add(LlmContent("user", [LlmTextPart(lastMessageOverride)]));
    }
    
    // Add the current user message to the very end of the context
    finalContextParts.add(LlmContent.fromMessage(currentUserMessage));

    debugPrint("LlmCoordinatorService:buildApiRequestContext - Returning context with ${finalContextParts.length} parts. Kept ${limitedHistoryForPrompt.length} history messages, dropped ${droppedMessages.length}.");

    return ApiRequestContext(
      contextParts: finalContextParts,
      carriedOverXml: calculatedCarriedOverXml,
      droppedMessages: droppedMessages,
    );
  }

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
      if (msg.role != MessageRole.model) {
        continue;
      }

      final xmlContent = chat.enableSecondaryXml
          ? msg.secondaryXmlContent
          : msg.originalXmlContent;

      final fullTextForXmlParsing = '${msg.rawText}\n${xmlContent ?? ''}'.trim();

      if (fullTextForXmlParsing.isEmpty || !fullTextForXmlParsing.contains('<')) {
        continue;
      }

      xml_pkg.XmlDocument? doc;
      try {
        doc = xml_pkg.XmlDocument.parse('<root>$fullTextForXmlParsing</root>');
      } catch (e) {
        debugPrint("LlmCoordinatorService:_calculateCurrentCarriedOverXml - Failed to parse XML in message ID ${msg.id}: $e. Skipping.");
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
                  debugPrint("  LlmCoordinatorService:_calculateCurrentCarriedOverXml - Merge failed for <$originalTagNameFromElement> (key '$keyToUseForCumulativeMap'): $e. Retaining previous.");
                }
              } else {
                cumulativeStateMap.remove(keyToUseForCumulativeMap);
              }
            } else {
              if (currentInnerXmlTrimmed.isNotEmpty) {
                cumulativeStateMap[keyToUseForCumulativeMap] = currentInnerXmlTrimmed;
              } else {
                cumulativeStateMap.remove(keyToUseForCumulativeMap);
              }
            }
          }
        }
      }
    }
    return XmlProcessor.serializeCarriedOver(cumulativeStateMap);
  }

  Future<_HistoryLimitResult> _limitHistoryForPrompt({
    required int chatId,
    required List<Message> fullHistory,
    required int historyTokenBudget,
    required int historyTurnBudget,
    required ApiConfig apiConfig,
  }) async {
    if (fullHistory.isEmpty) return _HistoryLimitResult([], []);

    final chat = _ref.read(currentChatProvider(chatId)).value;
    if (chat == null) {
      return _HistoryLimitResult([], fullHistory);
    }

    switch (chat.contextConfig.mode) {
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

      case ContextManagementMode.tokens:
        if (historyTokenBudget <= 0) {
          return _HistoryLimitResult([], fullHistory);
        }
        
        debugPrint("LlmCoordinatorService: Limiting history by tokens. Budget: $historyTokenBudget");

        try {
          final tokenFutures = fullHistory.map((msg) {
            return _llmService.countTokens(llmContext: [LlmContent.fromMessage(msg)], apiConfig: apiConfig)
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
    }
  }
}
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiktoken/tiktoken.dart' as tiktoken;

import '../../data/models/models.dart';
import 'llm_models.dart';
import '../../ui/providers/api_key_provider.dart';
import 'base_llm_service.dart';
import 'llm_request_handler.dart';
import 'token_calculator.dart';

// --- Provider ---
final geminiServiceProvider = Provider<GeminiService>((ref) {
  final apiKeyNotifier = ref.watch(apiKeyNotifierProvider.notifier);
  final dio = Dio();
  final requestHandler = LlmRequestHandler(dio);
  return GeminiService(apiKeyNotifier, requestHandler);
});


// --- Service Definition ---
class GeminiService implements BaseLlmService {
  final ApiKeyNotifier _apiKeyNotifier;
  final LlmRequestHandler _requestHandler;
  CancelToken? _cancelToken;

  GeminiService(this._apiKeyNotifier, this._requestHandler);

  @override
  Stream<LlmStreamChunk> sendMessageStream({
    required List<LlmContent> llmContext,
    required ApiConfig apiConfig,
    required Map<String, dynamic> generationParams,
  }) {
    _cancelToken = CancelToken();
    _requestHandler.setCancelToken(_cancelToken);
    
    final apiKey = _apiKeyNotifier.getNextGeminiApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return Stream.value(LlmStreamChunk.error("没有可用的 Gemini API Key。", ''));
    }

    final payload = GeminiChatPayload(
      apiKey: apiKey,
      apiConfig: apiConfig,
      generationParams: generationParams,
      llmContext: llmContext,
      stream: true,
    );
    
    return _requestHandler.executeStream(payload, textExtractor: _extractTextFromChunk);
  }

  @override
  Future<LlmResponse> sendMessageOnce({
    required List<LlmContent> llmContext,
    required ApiConfig apiConfig,
    required Map<String, dynamic> generationParams,
  }) {
    _cancelToken = CancelToken();
    _requestHandler.setCancelToken(_cancelToken);

    final apiKey = _apiKeyNotifier.getNextGeminiApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return Future.value(const LlmResponse.error("没有可用的 Gemini API Key。"));
    }

    final payload = GeminiChatPayload(
      apiKey: apiKey,
      apiConfig: apiConfig,
      generationParams: generationParams,
      llmContext: llmContext,
      stream: false,
    );
    
    // Note: The generic executeOnce in handler might need adjustment
    // if Gemini's response structure differs significantly.
    return _requestHandler.executeOnce(payload);
  }

  @override
  Future<LlmImageResponse> generateImage({
    required String prompt,
    required ApiConfig apiConfig,
    int n = 1,
  }) {
     _cancelToken = CancelToken();
    _requestHandler.setCancelToken(_cancelToken);

    final apiKey = _apiKeyNotifier.getNextGeminiApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return Future.value(const LlmImageResponse.error("没有可用的 Gemini API Key。"));
    }
    
    final payload = GeminiImagePayload(
      apiKey: apiKey,
      apiConfig: apiConfig,
      generationParams: {}, // n is not a standard generation param here
      prompt: prompt,
    );
    
    return _requestHandler.executeImage(payload);
  }

  @override
  Future<void> cancelRequest() async {
    _cancelToken?.cancel("Request cancelled by user.");
  }

  @override
  Future<int> countTokens({
    required List<LlmContent> llmContext,
    required ApiConfig apiConfig,
    bool useRemoteCounter = false,
  }) async {
    // Default to local calculation.
    final localCalculation = TokenCalculator.countTokens(
      llmContext: llmContext,
      apiConfig: apiConfig,
    );

    if (!useRemoteCounter) {
      return await localCalculation;
    }

    // If remote is enabled, run both local and remote concurrently.
    final apiKey = _apiKeyNotifier.getNextGeminiApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return await localCalculation; // Fallback if no key.
    }

    final payload = GeminiCountTokensPayload(
      apiKey: apiKey,
      apiConfig: apiConfig,
      llmContext: llmContext,
    );
    
    try {
      final remoteResult = await _requestHandler.executeCountTokens(payload)
          .timeout(const Duration(seconds: 3));
      return remoteResult;
    } catch (e) {
      debugPrint("Remote token count failed or timed out, returning local estimate. Error: $e");
      return await localCalculation;
    }
  }

  // --- Helpers ---
  String _extractTextFromChunk(Map<String, dynamic> json) {
    final candidates = json['candidates'] as List?;
    if (candidates != null && candidates.isNotEmpty) {
      final content = candidates.first['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List?;
      if (parts != null && parts.isNotEmpty) {
        return parts.first['text'] as String? ?? '';
      }
    }
    return '';
  }
}


// --- Payload Definitions ---

class GeminiChatPayload extends HttpRequestPayload {
  final String apiKey;
  final bool stream;

  GeminiChatPayload({
    required this.apiKey,
    required this.stream,
    required super.apiConfig,
    required super.generationParams,
    required super.llmContext,
  });

  @override
  String buildUrl() {
    const defaultBaseUrl = "https://generativelanguage.googleapis.com/v1beta";
    final baseUrl = apiConfig.baseUrl?.isNotEmpty == true ? apiConfig.baseUrl! : defaultBaseUrl;
    final action = stream ? "streamGenerateContent" : "generateContent";
    return "$baseUrl/models/${apiConfig.model}:$action?key=$apiKey${stream ? '&alt=sse' : ''}";
  }
  
  @override
  Map<String, String> buildHeaders() {
    return {'Content-Type': 'application/json'};
  }

  @override
  Map<String, dynamic> buildBody() {
    Map<String, dynamic>? systemInstruction;
    List<Map<String, dynamic>> history = [];

    for (var c in llmContext!) {
      final parts = c.parts.map((part) {
        if (part is LlmTextPart) return {'text': part.text};
        if (part is LlmDataPart) return {'inline_data': {'mime_type': part.mimeType, 'data': part.base64Data}};
        if (part is LlmFilePart) return {'file_data': {'mime_type': part.mimeType, 'file_uri': part.fileUri}};
        if (part is LlmAudioPart) return {'inline_data': {'mime_type': part.mimeType, 'data': part.base64Data}};
        return null;
      }).where((p) => p != null).toList();

      if (parts.isEmpty) continue;

      if (c.role == "system") {
        if (systemInstruction != null) debugPrint("Warning: Multiple system prompts found.");
        systemInstruction = {'parts': parts};
      } else if (c.role == "user" || c.role == "model") {
        history.add({'role': c.role, 'parts': parts});
      }
    }

    final body = <String, dynamic>{
      'contents': history,
      'generationConfig': _buildGenerationConfig(),
      'safetySettings': _defaultSafetySettingsAsJson(),
    };

    if (systemInstruction != null) {
      body['system_instruction'] = systemInstruction;
    }
    return body;
  }

  Map<String, dynamic> _buildGenerationConfig() {
    final config = <String, dynamic>{};
    if (generationParams['temperature'] != null) config['temperature'] = generationParams['temperature'];
    if (generationParams['topP'] != null) config['topP'] = generationParams['topP'];
    if (generationParams['topK'] != null) config['topK'] = generationParams['topK'];
    if (generationParams['maxOutputTokens'] != null) config['maxOutputTokens'] = generationParams['maxOutputTokens'];
    if (generationParams['stopSequences'] != null) config['stopSequences'] = generationParams['stopSequences'];
    if (generationParams['thinkingBudget'] != null) {
      config['thinkingConfig'] = {'thinkingBudget': generationParams['thinkingBudget']};
    }
    return config;
  }

  List<Map<String, String>> _defaultSafetySettingsAsJson() {
    return [
      {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'OFF'},
      {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'OFF'},
      {'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT', 'threshold': 'OFF'},
      {'category': 'HARM_CATEGORY_DANGEROUS_CONTENT', 'threshold': 'OFF'},
    ];
  }
}

class GeminiImagePayload extends HttpRequestPayload {
  final String apiKey;

  GeminiImagePayload({
    required this.apiKey,
    required super.apiConfig,
    required super.generationParams,
    required super.prompt,
  });

  @override
  String buildUrl() {
    const defaultBaseUrl = "https://generativelanguage.googleapis.com/v1beta";
    final baseUrl = apiConfig.baseUrl?.isNotEmpty == true ? apiConfig.baseUrl! : defaultBaseUrl;
    return "$baseUrl/models/${apiConfig.model}:generateContent?key=$apiKey";
  }

  @override
  Map<String, String> buildHeaders() {
    return {'Content-Type': 'application/json'};
  }

  @override
  Map<String, dynamic> buildBody() {
    return {
      "contents": [{"parts": [{"text": prompt}]}],
      "generationConfig": {"responseModalities": ["TEXT", "IMAGE"]}
    };
  }
}

class GeminiCountTokensPayload extends HttpRequestPayload {
  final String apiKey;

  GeminiCountTokensPayload({
    required this.apiKey,
    required super.apiConfig,
    required super.llmContext,
  }) : super(generationParams: {});

  @override
  String buildUrl() {
    const defaultBaseUrl = "https://generativelanguage.googleapis.com/v1beta";
    final baseUrl = apiConfig.baseUrl?.isNotEmpty == true ? apiConfig.baseUrl! : defaultBaseUrl;
    return "$baseUrl/models/${apiConfig.model}:countTokens?key=$apiKey";
  }

  @override
  Map<String, String> buildHeaders() {
    return {'Content-Type': 'application/json'};
  }

  @override
  Map<String, dynamic> buildBody() {
    // The body for countTokens is just the 'contents' part.
    List<Map<String, dynamic>> history = [];
     for (var c in llmContext!) {
      final parts = c.parts.map((part) {
        if (part is LlmTextPart) return {'text': part.text};
        if (part is LlmDataPart) return {'inline_data': {'mime_type': part.mimeType, 'data': part.base64Data}};
        if (part is LlmFilePart) return {'file_data': {'mime_type': part.mimeType, 'file_uri': part.fileUri}};
        if (part is LlmAudioPart) return {'inline_data': {'mime_type': part.mimeType, 'data': part.base64Data}};
        return null;
      }).where((p) => p != null).toList();

      if (parts.isEmpty) continue;

      // countTokens doesn't use system instructions, roles must be user/model
      if (c.role == "user" || c.role == "model") {
        history.add({'role': c.role, 'parts': parts});
      }
    }
    return {'contents': history};
  }
}

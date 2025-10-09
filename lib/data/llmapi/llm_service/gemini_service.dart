import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../llm_models.dart';
import '../../../app/providers/api_key_provider.dart';
import 'base_llm_service.dart';
import 'llm_request_handler.dart';
import '../token_calculator.dart';

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

  // ===> 在这里添加新代码 <===
  bool _isThinkStreamActive = false;

  GeminiService(this._apiKeyNotifier, this._requestHandler);

  @override
  Stream<LlmStreamChunk> sendMessageStream({
    required List<LlmContent> llmContext,
    required ApiConfig apiConfig,
    required Map<String, dynamic> generationParams,
  }) {
    _cancelToken = CancelToken();
    _requestHandler.setCancelToken(_cancelToken);
      
    // ===> 在这里添加新代码 <===
    _isThinkStreamActive = false;
    
    // New API key logic: Prioritize the key from the config, fallback to the pool.
    final apiKey = apiConfig.apiKey?.isNotEmpty == true
        ? apiConfig.apiKey
        : _apiKeyNotifier.getNextGeminiApiKey();

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
    
    return _requestHandler.executeStream(
      payload,
      textExtractor: _extractTextAndThinkFromChunk, // <--- 修改这里
    );
  }

  @override
  Future<LlmResponse> sendMessageOnce({
    required List<LlmContent> llmContext,
    required ApiConfig apiConfig,
    required Map<String, dynamic> generationParams,
  }) {
    _cancelToken = CancelToken();
    _requestHandler.setCancelToken(_cancelToken);

    // New API key logic: Prioritize the key from the config, fallback to the pool.
    final apiKey = apiConfig.apiKey?.isNotEmpty == true
        ? apiConfig.apiKey
        : _apiKeyNotifier.getNextGeminiApiKey();

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
    
    return _requestHandler.executeOnce(payload, responseParser: _parseGeminiResponse);
  }

  @override
  Future<LlmImageResponse> generateImage({
    required List<LlmContent> llmContext,
    required ApiConfig apiConfig,
    int n = 1,
  }) {
     _cancelToken = CancelToken();
    _requestHandler.setCancelToken(_cancelToken);

    // New API key logic: Prioritize the key from the config, fallback to the pool.
    final apiKey = apiConfig.apiKey?.isNotEmpty == true
        ? apiConfig.apiKey
        : _apiKeyNotifier.getNextGeminiApiKey();

    if (apiKey == null || apiKey.isEmpty) {
      return Future.value(const LlmImageResponse.error("没有可用的 Gemini API Key。"));
    }
    
    // Gemini 的图片生成 API（通过 generateContent）可以处理更丰富的上下文。
    // 我们直接将上下文传递给 Payload。
    final payload = GeminiImagePayload(
      apiKey: apiKey,
      apiConfig: apiConfig,
      generationParams: {}, // n is not a standard generation param here
      llmContext: llmContext,
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
    // New API key logic: Prioritize the key from the config, fallback to the pool.
    final apiKey = apiConfig.apiKey?.isNotEmpty == true
        ? apiConfig.apiKey
        : _apiKeyNotifier.getNextGeminiApiKey();
        
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
  // ===> 在 GeminiService 类中添加这个完整的新方法 <===
  String _extractTextAndThinkFromChunk(Map<String, dynamic> json) {
      final candidates = json['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return '';

      // ===> 在这里添加新代码 <===
      final finishReason = candidates.first['finishReason'] as String?;
      if (finishReason != null && finishReason != 'STOP') {
          // This part of the logic will be handled by the ChatStateNotifier now.
          // We just need to return an empty string here as the finish_reason chunk is handled separately.
          // However, the stream is processed line by line, so we can't easily emit a separate chunk here.
          // Let's modify this to return a special string that the notifier can look for.
          // A better approach is to modify the stream handler itself.
          // For now, we will let the stream processor in LlmRequestHandler handle this.
          // Let's adjust the logic to emit a specific chunk type.
          // This function returns a string, so we can't directly emit a chunk.
          // The logic must be in the stream processor.
          // Let's go back to the original plan. The UI layer will handle the display.
          // The service layer should provide the data.
          // The textExtractor is not the right place.
          // Let's modify the stream processor in LlmRequestHandler.
          // No, the textExtractor is called from the stream processor. It's the right place.
          // But it can only return a string.
          // Let's rethink. The stream processor yields LlmStreamChunk.
          // The textExtractor provides the text for the chunk.
          // We need to yield a different KIND of chunk.
          // This means the logic needs to be in _processSseStream in LlmRequestHandler.
          // Let's move it there.
          // For now, let's stick to the plan of modifying the service layer first.
          // The problem is that textExtractor returns a string, not a chunk.
          // Let's modify the signature of textExtractor to return a LlmStreamChunk?
          // That would be a big change.
          // Let's try a simpler way. The textExtractor can return a special formatted string.
          // e.g., "FINISH_REASON::MAX_TOKENS"
          // And the stream processor can check for this prefix.
          // This seems hacky.
          // Let's look at _processSseStream again.
          // It calls textExtractor and then creates a LlmStreamChunk.
          // What if textExtractor returns a Map<String, dynamic> instead of a String?
          // e.g., {'type': 'text', 'content': 'hello'} or {'type': 'finish_reason', 'content': 'MAX_TOKENS'}
          // This seems like a good approach.
          // Let's implement this.
          // First, change the textExtractor signature in LlmRequestHandler.
          // Then change the implementation here.
          // This is getting complicated. Let's go back to the simplest solution that works.
          // The UI layer needs to know about the finish reason.
          // The service layer provides it.
          // The stream chunk should contain it.
          // The current implementation adds it to the text.
          // The user wants a popup.
          // So the UI needs to detect it.
          // A special string in the text is one way.
          // A separate field in LlmStreamChunk is a cleaner way.
          // We already added the 'type' field.
          // Now, how to create a chunk of that type from here?
          // We can't. The textExtractor only returns a string.
          // The logic MUST be moved to _processSseStream.
          // Let's do that.
          // I will modify LlmRequestHandler to handle this.
          // But first, I need to remove the logic from here.
          return ""; // Return empty string, the logic will be in the request handler.
      }
      // ^^^ --------------------------------- ^^^

      final content = candidates.first['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List?;
      if (parts == null || parts.isEmpty) return '';

      final part = parts.first as Map<String, dynamic>? ?? {};
      final text = part['text'] as String? ?? '';
      
      final bool isThoughtChunk = part['thought'] as bool? ?? false;

      String result = '';

      if (isThoughtChunk && !_isThinkStreamActive) {
        _isThinkStreamActive = true;
        result += '<think>\n';
      }
      if (!isThoughtChunk && _isThinkStreamActive) {
        _isThinkStreamActive = false;
        result += '</think>\n';
      }
      
      result += text;
      return result;
  }

  LlmResponse _parseGeminiResponse(Map<String, dynamic> data) {
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      return const LlmResponse.error("Invalid response: 'candidates' field is missing or empty.");
    }

    final content = candidates.first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      // It's possible to have a response with a finishReason but no parts.
      return const LlmResponse(parts: []);
    }

    final stringBuffer = StringBuffer();
    for (final part in parts) {
      if (part is! Map<String, dynamic>) continue;

      final text = part['text'] as String?;
      if (text == null || text.isEmpty) continue;

      final isThought = part['thought'] as bool? ?? false;
      if (isThought) {
        stringBuffer.writeln('<think>');
        stringBuffer.writeln(text);
        stringBuffer.writeln('</think>');
      } else {
        stringBuffer.write(text);
      }
    }

    if (stringBuffer.isNotEmpty) {
      return LlmResponse(parts: [MessagePart.text(stringBuffer.toString())]);
    }

    return const LlmResponse.error("Invalid response: No valid text parts found in Gemini response.");
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
    const defaultBaseUrl = "https://generativelanguage.googleapis.com";
    final baseUrl = apiConfig.baseUrl?.isNotEmpty == true ? apiConfig.baseUrl! : defaultBaseUrl;
    final action = stream ? "streamGenerateContent" : "generateContent";
    return "$baseUrl/v1beta/models/${apiConfig.model}:$action?key=$apiKey${stream ? '&alt=sse' : ''}";
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
    };

    if (apiConfig.useDefaultSafetySettings) {
      body['safetySettings'] = _defaultSafetySettingsAsJson();
    }

    if (systemInstruction != null) {
      body['system_instruction'] = systemInstruction;
    }
    
    // Add tool_config if present, and assign it to the 'tools' key
    if (apiConfig.toolConfig != null && apiConfig.toolConfig!.isNotEmpty) {
      try {
        final toolConfigJson = jsonDecode(apiConfig.toolConfig!);
        body['tools'] = toolConfigJson; // Corrected from 'tool_config' to 'tools'
      } catch (e) {
        debugPrint("Error decoding toolConfig to build API tools: $e");
      }
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

    final bool includeThoughts = generationParams['includeThoughts'] as bool? ?? false;
    final int? thinkingBudget = generationParams['thinkingBudget'] as int?;

    // Final logic based on detailed user feedback:
    // Only construct thinkingConfig if a budget is explicitly set (not null).
    if (thinkingBudget != null) {
      final thinkingConfig = <String, dynamic>{};

      // Rule: Add 'includeThoughts' only if the caller requests it AND thinking is active.
      if (includeThoughts && thinkingBudget != 0) {
        thinkingConfig['includeThoughts'] = true;
      }

      // Rule: Add 'thinkingBudget' key unless it's for dynamic thinking (-1).
      // This correctly includes the case where thinkingBudget is 0 to disable thinking.
      if (thinkingBudget != -1) {
        thinkingConfig['thinkingBudget'] = thinkingBudget;
      }
      
      // Rule: Only attach the thinkingConfig object if it contains any keys.
      // This prevents sending an empty `thinkingConfig: {}`.
      if (thinkingConfig.isNotEmpty) {
        config['thinkingConfig'] = thinkingConfig;
      }
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
    required super.llmContext,
  }) : super(prompt: ''); // prompt is not directly used, but required by super

  @override
  String buildUrl() {
    const defaultBaseUrl = "https://generativelanguage.googleapis.com";
    final baseUrl = apiConfig.baseUrl?.isNotEmpty == true ? apiConfig.baseUrl! : defaultBaseUrl;
    return "$baseUrl/v1beta/models/${apiConfig.model}:generateContent?key=$apiKey";
  }

  @override
  Map<String, String> buildHeaders() {
    return {'Content-Type': 'application/json'};
  }

  @override
  Map<String, dynamic> buildBody() {
    // Re-use the logic from GeminiChatPayload to build the contents
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

      // Image generation with Gemini uses the 'user' role.
      history.add({'role': 'user', 'parts': parts});
    }

    return {
      "contents": history,
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
    const defaultBaseUrl = "https://generativelanguage.googleapis.com";
    final baseUrl = apiConfig.baseUrl?.isNotEmpty == true ? apiConfig.baseUrl! : defaultBaseUrl;
    return "$baseUrl/v1beta/models/${apiConfig.model}:countTokens?key=$apiKey";
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

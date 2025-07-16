import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiktoken/tiktoken.dart' as tiktoken;

import '../../data/models/models.dart';
import 'base_llm_service.dart';
import 'llm_models.dart';
import 'llm_request_handler.dart';
import 'token_calculator.dart';

// --- Provider ---
final openaiServiceProvider = Provider<OpenAIService>((ref) {
  final dio = Dio();
  final requestHandler = LlmRequestHandler(dio);
  return OpenAIService(requestHandler);
});

// --- Service Definition ---
class OpenAIService implements BaseLlmService {
  final LlmRequestHandler _requestHandler;
  CancelToken? _cancelToken;

  OpenAIService(this._requestHandler);

  @override
  Stream<LlmStreamChunk> sendMessageStream({
    required List<LlmContent> llmContext,
    required ApiConfig apiConfig,
    required Map<String, dynamic> generationParams,
  }) {
    _cancelToken = CancelToken();
    _requestHandler.setCancelToken(_cancelToken);

    final payload = OpenAIChatPayload(
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

    final payload = OpenAIChatPayload(
      apiConfig: apiConfig,
      generationParams: generationParams,
      llmContext: llmContext,
      stream: false,
    );
    
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

    final payload = OpenAIImagePayload(
      apiConfig: apiConfig,
      generationParams: {'n': n}, // Pass n via generationParams
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
    bool useRemoteCounter = false, // Parameter is present to match the interface, but not used.
  }) {
    // OpenAI calculation is always local via tiktoken.
    return TokenCalculator.countTokens(llmContext: llmContext, apiConfig: apiConfig);
  }

  // --- Helpers ---
  String _extractTextFromChunk(Map<String, dynamic> json) {
    final choices = json['choices'] as List?;
    if (choices != null && choices.isNotEmpty) {
      final delta = choices.first['delta'] as Map<String, dynamic>?;
      return delta?['content'] as String? ?? '';
    }
    return '';
  }

  // This method is kept separate as it's a distinct 'GET' utility
  // and doesn't fit the POST-based payload pattern.
  Future<List<OpenAIModel>> fetchModels({
    required String baseUrl,
    required String apiKey,
  }) async {
    final dio = Dio(); // Use a local Dio instance for this one-off call
    final correctedBaseUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final modelsUrl = Uri.parse(correctedBaseUrl).resolve('models').toString();

    try {
      final response = await dio.get(
        modelsUrl,
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && response.data?['data'] is List) {
        final data = response.data['data'] as List;
        final models = data
            .map((modelJson) => OpenAIModel.fromJson(modelJson))
            .toList();
        models.sort((a, b) => a.id.compareTo(b.id));
        return models;
      } else {
        throw Exception('Failed to load models: Status ${response.statusCode}');
      }
    } on DioException catch (e) {
      debugPrint('Error fetching OpenAI models: $e');
      throw Exception('Failed to fetch models: ${e.message}');
    } catch (e) {
      debugPrint('An unexpected error occurred: $e');
      throw Exception('An unexpected error occurred while fetching models.');
    }
  }
}

// --- Payload Definitions ---

abstract class OpenAIPayload extends HttpRequestPayload {
  OpenAIPayload({
    required super.apiConfig,
    required super.generationParams,
    super.llmContext,
    super.prompt,
  });

  @override
  Map<String, String> buildHeaders() {
    return {
      'Authorization': 'Bearer ${apiConfig.apiKey}',
      'Content-Type': 'application/json',
    };
  }

  String _buildApiUrl(String endpoint) {
    final baseUrl = apiConfig.baseUrl;
    if (baseUrl == null || baseUrl.isEmpty) {
      throw Exception("API Base URL is not set.");
    }
    final correctedBaseUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    return Uri.parse(correctedBaseUrl).resolve(endpoint).toString();
  }
}

class OpenAIChatPayload extends OpenAIPayload {
  final bool stream;

  OpenAIChatPayload({
    required this.stream,
    required super.apiConfig,
    required super.generationParams,
    required super.llmContext,
  });

  @override
  String buildUrl() => _buildApiUrl('chat/completions');
  
  @override
  Map<String, dynamic> buildBody() {
    final requestBody = <String, dynamic>{
      "model": apiConfig.model,
      "messages": _buildOpenAIMessages(),
      "stream": stream,
    };

    final config = <String, dynamic>{};
    if (generationParams['temperature'] != null) config['temperature'] = generationParams['temperature'];
    if (generationParams['topP'] != null) config['top_p'] = generationParams['topP'];
    if (generationParams['maxOutputTokens'] != null) config['max_tokens'] = generationParams['maxOutputTokens'];
    if (generationParams['stopSequences'] != null) config['stop'] = generationParams['stopSequences'];
    if (generationParams['reasoning_effort'] != null) config['reasoning_effort'] = generationParams['reasoning_effort'];

    requestBody.addAll(config);
    return requestBody;
  }

  List<Map<String, dynamic>> _buildOpenAIMessages() {
    final openAIMessages = <Map<String, dynamic>>[];
    LlmContent? systemPrompt;

    final otherContent = <LlmContent>[];
    for (var content in llmContext!) {
      if (content.role == "system") {
        systemPrompt = content;
      } else {
        otherContent.add(content);
      }
    }

    if (systemPrompt != null) {
      final systemText = systemPrompt.parts.whereType<LlmTextPart>().map((p) => p.text).join("\n");
      if (systemText.isNotEmpty) openAIMessages.add({"role": "system", "content": systemText});
    }

    for (var content in otherContent) {
      final role = content.role == 'model' ? 'assistant' : content.role;
      final contentParts = <Map<String, dynamic>>[];
      String textBuffer = "";

      for (var part in content.parts) {
        if (part is LlmTextPart) {
          textBuffer += "${part.text}\n";
        } else if (part is LlmDataPart) {
          contentParts.add({"type": "image_url", "image_url": {"url": "data:${part.mimeType};base64,${part.base64Data}"}});
        } else if (part is LlmAudioPart) {
           contentParts.add({"type": "input_audio", "input_audio": {"data": part.base64Data, "format": part.mimeType.split('/').last}});
        } else if (part is LlmFilePart) {
           debugPrint("Warning: LlmFilePart is currently not supported by OpenAIService.");
        }
      }

      if (textBuffer.isNotEmpty) {
        contentParts.insert(0, {"type": "text", "text": textBuffer.trim()});
      }

      if (contentParts.isNotEmpty) {
        final messageContent = (contentParts.length == 1 && contentParts.first['type'] == 'text')
            ? contentParts.first['text']
            : contentParts;
        openAIMessages.add({"role": role, "content": messageContent});
      }
    }
    return openAIMessages;
  }
}

class OpenAIImagePayload extends OpenAIPayload {
  OpenAIImagePayload({
    required super.apiConfig,
    required super.generationParams,
    required super.prompt,
  });

  @override
  String buildUrl() => _buildApiUrl('images/generations');

  @override
  Map<String, dynamic> buildBody() {
    return {
      "model": apiConfig.model,
      "prompt": prompt,
      "n": generationParams['n'] ?? 1,
      "response_format": "b64_json",
    };
  }
}

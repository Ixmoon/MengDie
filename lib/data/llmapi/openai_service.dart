import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiktoken/tiktoken.dart' as tiktoken;
import 'package:collection/collection.dart';

import '../../domain/models/models.dart';
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
    
    return _requestHandler.executeOnce(payload, responseParser: _parseOpenAIResponse);
  }

  @override
  Future<LlmImageResponse> generateImage({
    required List<LlmContent> llmContext,
    required ApiConfig apiConfig,
    int n = 1,
  }) {
    _cancelToken = CancelToken();
    _requestHandler.setCancelToken(_cancelToken);

    // OpenAI 的 DALL-E API 只接受一个简单的文本提示。
    // 为了构建一个干净、准确的提示，我们只合并来自'user'角色的文本部分。
    // 这可以防止模型的历史回复污染最终的生成指令。
    final prompt = llmContext
        .where((content) => content.role == 'user')
        .expand((content) => content.parts)
        .whereType<LlmTextPart>()
        .map((part) => part.text)
        .join('\n');
    if (prompt.isEmpty) {
      return Future.value(const LlmImageResponse.error("Image generation requires a text prompt."));
    }

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

  LlmResponse _parseOpenAIResponse(Map<String, dynamic> data) {
    final choices = data['choices'] as List?;
    if (choices != null && choices.isNotEmpty) {
      final message = choices.first['message'] as Map<String, dynamic>?;
      final content = message?['content'] as String?;
      if (content != null) {
        return LlmResponse(parts: [MessagePart.text(content)]);
      }
    }
    return const LlmResponse.error("Invalid response format from OpenAI.");
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

    if (apiConfig.toolChoice != null && apiConfig.toolChoice!.isNotEmpty) {
      // It could be a simple string like "auto" or a JSON object.
      try {
        final toolChoiceJson = jsonDecode(apiConfig.toolChoice!);
        requestBody['tool_choice'] = toolChoiceJson;
      } catch (e) {
        // If it's not a valid JSON, treat it as a plain string (e.g., "auto", "none").
        requestBody['tool_choice'] = apiConfig.toolChoice;
      }
    }

    return requestBody;
  }

  List<Map<String, dynamic>> _buildOpenAIMessages() {
    final openAIMessages = <Map<String, dynamic>>[];
    if (llmContext == null || llmContext!.isEmpty) {
      return openAIMessages;
    }

    // First, extract system prompt if it exists.
    final systemPrompt = llmContext!.firstWhereOrNull((c) => c.role == "system");
    if (systemPrompt != null) {
      final systemText = systemPrompt.parts
          .whereType<LlmTextPart>()
          .map((p) => p.text)
          .join("\n");
      if (systemText.isNotEmpty) {
        openAIMessages.add({"role": "system", "content": systemText});
      }
    }

    // Process the rest of the messages (user and model).
    final messages = llmContext!.where((c) => c.role != "system").toList();
    
    for (final currentMsg in messages) {
      final role = currentMsg.role == 'model' ? 'assistant' : currentMsg.role;

      if (role == 'assistant') {
        // Special handling for assistant messages as per user's request
        final textParts = currentMsg.parts.whereType<LlmTextPart>().toList();
        final imageParts = currentMsg.parts.whereType<LlmDataPart>().toList();

        // 1. Add the text part as an assistant message
        if (textParts.isNotEmpty) {
          final assistantContent = _convertParts(textParts);
          final messageContent = (assistantContent.length == 1 && assistantContent.first['type'] == 'text')
              ? assistantContent.first['text']
              : assistantContent;
          openAIMessages.add({"role": "assistant", "content": messageContent});
        }

        // 2. Add the image part as a new user message to circumvent API limitations
        if (imageParts.isNotEmpty) {
          final userContent = _convertParts(imageParts);
           openAIMessages.add({"role": "user", "content": userContent});
        }
      } else { // role == 'user'
        // Standard handling for user messages
        final contentParts = _convertParts(currentMsg.parts);
        if (contentParts.isNotEmpty) {
          final messageContent = (contentParts.length == 1 && contentParts.first['type'] == 'text')
              ? contentParts.first['text']
              : contentParts;
          openAIMessages.add({"role": "user", "content": messageContent});
        }
      }
    }

    return openAIMessages;
  }

  /// Helper to convert a list of LlmPart into a list of OpenAI-compatible content maps.
  List<Map<String, dynamic>> _convertParts(List<LlmPart> parts) {
    final contentParts = <Map<String, dynamic>>[];
    for (var part in parts) {
      if (part is LlmTextPart) {
        contentParts.add({"type": "text", "text": part.text});
      } else if (part is LlmDataPart) {
        contentParts.add({"type": "image_url", "image_url": {"url": "data:${part.mimeType};base64,${part.base64Data}"}});
      } else if (part is LlmAudioPart) {
         contentParts.add({"type": "input_audio", "input_audio": {"data": part.base64Data, "format": part.mimeType.split('/').last}});
      } else if (part is LlmFilePart) {
         debugPrint("Warning: LlmFilePart is currently not supported by OpenAIService.");
      }
    }
    return contentParts;
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

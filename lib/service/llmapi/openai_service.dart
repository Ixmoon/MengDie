import 'dart:async';
import 'dart:convert'; // For jsonEncode/Decode

import 'package:dio/dio.dart'; // HTTP client
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiktoken/tiktoken.dart' as tiktoken; // For token counting

import '../../data/models/models.dart';
import 'base_llm_service.dart'; // 导入抽象基类
import 'llm_models.dart';

// 本文件实现了与OpenAI及其兼容API进行交互的服务。
//
// 主要功能包括：
// 1. 发送聊天消息并以流式（sendMessageStream）或一次性（sendMessageOnce）方式接收响应。
// 2. 支持多模态内容，包括文本和图片。
// 3. 封装了请求构建、参数处理和错误处理的逻辑。
// 4. 提供Token计算（countTokens）和模型列表获取（fetchModels）功能。
// 5. 支持请求取消（cancelRequest）。

// --- OpenAI API Specific Data Models ---

/// Represents the data structure for a single model returned by the OpenAI `/models` endpoint.
class OpenAIModel {
  final String id;
  final String object;
  final int created;
  final String ownedBy;

  OpenAIModel({
    required this.id,
    required this.object,
    required this.created,
    required this.ownedBy,
  });

  factory OpenAIModel.fromJson(Map<String, dynamic> json) {
    return OpenAIModel(
      id: json['id'] ?? '',
      object: json['object'] ?? '',
      created: json['created'] ?? 0,
      ownedBy: json['owned_by'] ?? '',
    );
  }
}

// --- OpenAI Service Provider ---
final openaiServiceProvider = Provider<OpenAIService>((ref) {
  final dio = Dio(); // Create a Dio instance
  return OpenAIService(ref, dio);
});

// --- OpenAI Service Implementation ---
class OpenAIService implements BaseLlmService {
  // ignore: unused_field
  final Ref _ref;
  final Dio _dio;

  // --- Cancellation ---
  CancelToken? _cancelToken;

  OpenAIService(this._ref, this._dio);

  /// Builds the list of messages in the format expected by the OpenAI API.
  List<Map<String, dynamic>> _buildOpenAIMessages(List<LlmContent> llmContext) {
    final openAIMessages = <Map<String, dynamic>>[];
    LlmContent? systemPrompt;

    // Separate system prompt, as it must be the first message if present.
    final otherContent = <LlmContent>[];
    for (var content in llmContext) {
      if (content.role == "system") {
        systemPrompt = content;
      } else {
        otherContent.add(content);
      }
    }

    // Add system prompt first if it exists
    if (systemPrompt != null) {
      final systemTextContent = systemPrompt.parts
          .whereType<LlmTextPart>()
          .map((part) => part.text)
          .join("\n");
      if (systemTextContent.isNotEmpty) {
        openAIMessages.add({"role": "system", "content": systemTextContent});
      }
    }

    // Add other messages
    for (var content in otherContent) {
      final role = content.role == 'model' ? 'assistant' : content.role;

      // Vision API format: content can be a string OR an array of parts
      final contentParts = [];
      String textPartBuffer = "";

      for (var part in content.parts) {
        if (part is LlmTextPart) {
          textPartBuffer += "${part.text}\n";
        } else if (part is LlmDataPart) {
          contentParts.add({
            "type": "image_url",
            "image_url": {
              "url": "data:${part.mimeType};base64,${part.base64Data}"
            }
          });
        }
      }

      if (textPartBuffer.isNotEmpty) {
        contentParts.insert(0, {"type": "text", "text": textPartBuffer.trim()});
      }

      if (contentParts.isNotEmpty) {
        // If there's only one text part, send as a simple string for wider compatibility.
        // Otherwise, send as an array.
        final messageContent =
            (contentParts.length == 1 && contentParts.first['type'] == 'text')
                ? contentParts.first['text']
                : contentParts;
        openAIMessages.add({"role": role, "content": messageContent});
      }
    }
    return openAIMessages;
  }

  /// Constructs the request body for the API call.
  Map<String, dynamic> _buildRequestBody({
    required ApiConfig apiConfig,
    required List<Map<String, dynamic>> messages,
    required Map<String, dynamic> generationParams,
    required bool stream,
  }) {
    final requestBody = {
      "model": apiConfig.model,
      "messages": messages,
      "stream": stream,
    };

    // Add optional generation parameters
    if (generationParams['temperature'] != null) {
      requestBody["temperature"] = generationParams['temperature'];
    }
    if (generationParams['maxOutputTokens'] != null) {
      requestBody["max_tokens"] = generationParams['maxOutputTokens'];
    }
    if (generationParams['topP'] != null) {
      requestBody["top_p"] = generationParams['topP'];
    }
    if (generationParams['stopSequences'] != null &&
        (generationParams['stopSequences'] as List).isNotEmpty) {
      requestBody["stop"] = generationParams['stopSequences'];
    }
    // Pass through any other non-standard parameters
    if (generationParams['reasoning_effort'] != null) {
      requestBody["reasoning_effort"] = generationParams['reasoning_effort'];
    }
    return requestBody;
  }

  /// Validates and constructs the full API URL.
  String _buildApiUrl(ApiConfig apiConfig) {
    final baseUrl = apiConfig.baseUrl;
    if (baseUrl == null || baseUrl.isEmpty) {
      throw Exception("API Base URL is not set in the configuration.");
    }
    // Ensure the base URL has a trailing slash for proper resolution
    final correctedBaseUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    return Uri.parse(correctedBaseUrl).resolve('chat/completions').toString();
  }

  @override
  Stream<LlmStreamChunk> sendMessageStream({
    required List<LlmContent> llmContext,
    required ApiConfig apiConfig,
    required Map<String, dynamic> generationParams,
  }) async* {
    _cancelToken = CancelToken();
    String accumulatedText = "";
    DateTime lastTimestamp = DateTime.now();

    final String apiUrl;
    final Map<String, dynamic> requestBody;

    try {
      apiUrl = _buildApiUrl(apiConfig);
      final messages = _buildOpenAIMessages(llmContext);
      requestBody = _buildRequestBody(
        apiConfig: apiConfig,
        messages: messages,
        generationParams: generationParams,
        stream: true,
      );
    } catch (e) {
      debugPrint("Error preparing OpenAI request: $e");
      yield LlmStreamChunk.error("Error preparing request: $e", "");
      return;
    }

    debugPrint("Requesting OpenAI stream from URL: $apiUrl");

    try {
      final response = await _dio.post<ResponseBody>(
        apiUrl,
        data: jsonEncode(requestBody),
        options: Options(
          headers: {
            'Authorization': 'Bearer ${apiConfig.apiKey}',
            'Content-Type': 'application/json',
            'Accept': 'text/event-stream',
          },
          responseType: ResponseType.stream,
        ),
        cancelToken: _cancelToken,
      );

      final stringStream = utf8.decoder.bind(response.data!.stream);
      String carryOverBuffer = '';

      await for (var stringChunk in stringStream) {
        lastTimestamp = DateTime.now();
        final rawChunk = carryOverBuffer + stringChunk;
        var lines = rawChunk.split('\n');

        if (!rawChunk.endsWith('\n')) {
          carryOverBuffer = lines.removeLast();
        } else {
          carryOverBuffer = '';
        }

        for (var line in lines) {
          if (!line.startsWith('data: ')) continue;

          final jsonData = line.substring('data: '.length).trim();
          if (jsonData == '[DONE]') {
            debugPrint("OpenAI stream finished with [DONE]");
            yield LlmStreamChunk(
              textChunk: '',
              accumulatedText: accumulatedText,
              isFinished: true,
              timestamp: lastTimestamp,
            );
            return;
          }

          try {
            final Map<String, dynamic> chunkMap = jsonDecode(jsonData);
            final choices = chunkMap['choices'] as List?;
            if (choices != null && choices.isNotEmpty) {
              final delta = choices[0]['delta'] as Map<String, dynamic>?;
              final textChunk = delta?['content'] as String?;
              if (textChunk != null) {
                accumulatedText += textChunk;
                yield LlmStreamChunk(
                  textChunk: textChunk,
                  accumulatedText: accumulatedText,
                  timestamp: lastTimestamp,
                );
              }
            }
          } catch (e) {
            debugPrint("Error parsing OpenAI stream chunk: $jsonData. Error: $e");
          }
        }
      }

      debugPrint("OpenAI stream finished without [DONE]. Finalizing...");
      yield LlmStreamChunk(
          textChunk: '',
          accumulatedText: accumulatedText,
          isFinished: true,
          timestamp: lastTimestamp,
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        debugPrint("OpenAI stream request was cancelled by user.");
        return;
      }
      String errorMessage = "OpenAI API DioException: ${e.message}";
      if (e.response != null) {
        errorMessage += "\nStatus: ${e.response?.statusCode} - ${e.response?.statusMessage}";
        try {
          final errorBody = jsonEncode(e.response?.data);
          errorMessage += "\nBody: $errorBody";
        } catch (_) {
          errorMessage += "\nBody: (Could not parse error body)";
        }
      }
      debugPrint(errorMessage);
      yield LlmStreamChunk.error(errorMessage, accumulatedText);
    } catch (e) {
      debugPrint("Unexpected error in OpenAI sendMessageStream: $e");
      yield LlmStreamChunk.error("Unexpected OpenAI Error: $e", accumulatedText);
    } finally {
      _cancelToken = null;
    }
  }

  @override
  Future<LlmResponse> sendMessageOnce({
    required List<LlmContent> llmContext,
    required ApiConfig apiConfig,
    required Map<String, dynamic> generationParams,
  }) async {
    _cancelToken = CancelToken();

    final String apiUrl;
    final Map<String, dynamic> requestBody;

    try {
      apiUrl = _buildApiUrl(apiConfig);
      final messages = _buildOpenAIMessages(llmContext);
      requestBody = _buildRequestBody(
        apiConfig: apiConfig,
        messages: messages,
        generationParams: generationParams,
        stream: false,
      );
    } catch (e) {
      debugPrint("Error preparing OpenAI request: $e");
      return LlmResponse.error("Error preparing request: $e");
    }

    debugPrint("Requesting OpenAI (once) from URL: $apiUrl");

    try {
      final response = await _dio.post(
        apiUrl,
        data: jsonEncode(requestBody),
        options: Options(
          headers: {
            'Authorization': 'Bearer ${apiConfig.apiKey}',
            'Content-Type': 'application/json',
          },
        ),
        cancelToken: _cancelToken,
      );

      if (response.statusCode == 200 && response.data != null) {
        final responseData = response.data as Map<String, dynamic>;
        final choices = responseData['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          final messageData = choices[0]['message'] as Map<String, dynamic>?;
          final rawText = messageData?['content'] as String?;
          if (rawText != null) {
            return LlmResponse(parts: [MessagePart.text(rawText)], isSuccess: true);
          }
        }
        return const LlmResponse.error("OpenAI response format unexpected (no content).");
      } else {
        String errorMsg = "OpenAI API Error: ${response.statusCode} ${response.statusMessage}";
        if (response.data != null) {
          errorMsg += "\nBody: ${jsonEncode(response.data)}";
        }
        return LlmResponse.error(errorMsg);
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        debugPrint("OpenAI single request was cancelled by user.");
        return const LlmResponse.error("Request cancelled by user.");
      }
      String errorMessage = "OpenAI API DioException: ${e.message}";
      if (e.response != null) {
        errorMessage += "\nStatus: ${e.response?.statusCode} - ${e.response?.statusMessage}";
        try {
          final errorBody = jsonEncode(e.response?.data);
          errorMessage += "\nBody: $errorBody";
        } catch (_) {
          errorMessage += "\nBody: (Could not parse error body)";
        }
      }
      debugPrint(errorMessage);
      return LlmResponse.error(errorMessage);
    } catch (e) {
      debugPrint("Unexpected error in OpenAI sendMessageOnce: $e");
      return LlmResponse.error("Unexpected OpenAI Error: $e");
    } finally {
      _cancelToken = null;
    }
  }

  @override
  Future<int> countTokens({
    required List<LlmContent> llmContext,
    required ApiConfig apiConfig,
  }) async {
    final encoding = (() {
      try {
        return tiktoken.encodingForModel(apiConfig.model);
      } catch (_) {
        // Fallback to a common encoding if the model-specific one isn't found.
        return tiktoken.getEncoding('cl100k_base');
      }
    })();

    int totalTokens = 0;
    for (final message in llmContext) {
      final textContent = message.parts
          .whereType<LlmTextPart>()
          .map((part) => part.text)
          .join(); // No need for newline, just concatenate text parts.

      if (textContent.isNotEmpty) {
        totalTokens += encoding.encode(textContent).length;
      }
    }
    return totalTokens;
  }

  Future<List<OpenAIModel>> fetchModels({
    required String baseUrl,
    required String apiKey,
  }) async {
    try {
      final correctedBaseUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
      final modelsUrl = Uri.parse(correctedBaseUrl).resolve('models').toString();

      debugPrint("Fetching OpenAI models from: $modelsUrl");

      final response = await _dio.get(
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
        throw Exception(
            'Failed to load models: Status code ${response.statusCode}');
      }
    } on DioException catch (e) {
      debugPrint('Error fetching OpenAI models: $e');
      throw Exception('Failed to fetch models: ${e.message}');
    } catch (e) {
      debugPrint('An unexpected error occurred while fetching models: $e');
      throw Exception('An unexpected error occurred while fetching models.');
    }
  }

  @override
  Future<void> cancelRequest() async {
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      debugPrint("OpenAIService: Cancelling active Dio request...");
      _cancelToken!.cancel("Request cancelled by user.");
    }
  }
}

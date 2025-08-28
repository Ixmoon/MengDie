// coverage:ignore-file
// 本文件包含 LlmService 类，它作为与各种大型语言模型 (LLM) API 交互的中心枢纽。
// 它实现了扁平化和中心化的设计，直接处理与 langchain_dart 的交互，
// 避免了多层抽象，提高了代码的清晰度和可维护性。

import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as google_ai;
import 'package:langchain_core/chat_models.dart';
import 'package:langchain_core/prompts.dart';
import 'package:langchain_google/langchain_google.dart';
import 'package:langchain_openai/langchain_openai.dart';

import '../../domain/models/models.dart';
import 'llm_models.dart';

// --- LLM Service Provider ---
final llmServiceProvider = Provider<LlmService>((ref) {
  return LlmService(ref);
});

// --- Centralized LLM Service Implementation ---
class LlmService {
  final Ref _ref;

  LlmService(this._ref);

  /// 发送消息并获取流式响应。
  Stream<LlmStreamChunk> sendMessageStream({
    required List<LlmContent> llmContext,
    required ApiConfig apiConfig,
  }) async* {
    try {
      final chatModel = _createChatModel(apiConfig);
      final messages = _toChatMessages(llmContext);
      final prompt = PromptValue.chat(messages);

      final stream = chatModel.stream(prompt);
      String accumulatedText = "";

      await for (final chunk in stream) {
        final streamChunk = _toLlmStreamChunk(chunk, accumulatedText);
        accumulatedText = streamChunk.accumulatedText;
        yield streamChunk;
      }
    } catch (e) {
      debugPrint("Error in LlmService.sendMessageStream for ${apiConfig.apiType}: $e");
      yield LlmStreamChunk.error("${apiConfig.apiType} API Error: $e", '');
    }
  }

  /// 发送消息并获取一次性完整响应。
  Future<LlmResponse> sendMessageOnce({
    required List<LlmContent> llmContext,
    required ApiConfig apiConfig,
  }) async {
    try {
      final chatModel = _createChatModel(apiConfig);
      final messages = _toChatMessages(llmContext);
      final prompt = PromptValue.chat(messages);

      final result = await chatModel.invoke(prompt);
      return _toLlmResponse(result);
    } catch (e) {
      debugPrint("Error in LlmService.sendMessageOnce for ${apiConfig.apiType}: $e");
      return LlmResponse.error("${apiConfig.apiType} API Error: $e");
    }
  }

  /// 根据上下文生成图片。
  Future<LlmImageResponse> generateImage({
    required List<LlmContent> llmContext,
    required ApiConfig apiConfig,
    int n = 1,
  }) async {
    // Note: Image generation cancellation is not implemented via CancelToken in the same way.
    try {
      if (apiConfig.apiType == LlmType.openai) {
        return _generateImageOpenAI(llmContext, apiConfig, n);
      } else if (apiConfig.apiType == LlmType.gemini) {
        return _generateImageGemini(llmContext, apiConfig);
      } else {
        return LlmImageResponse.error("Image generation is not supported for ${apiConfig.apiType}.");
      }
    } catch (e) {
      debugPrint("Error during ${apiConfig.apiType} generateImage: $e");
      return LlmImageResponse.error("${apiConfig.apiType} API Error: $e");
    }
  }

  /// 为给定的上下文计算 token 数量。
  Future<int> countTokens({
    required List<LlmContent> llmContext,
    required ApiConfig apiConfig,
  }) async {
    try {
      final chatModel = _createChatModel(apiConfig);
      final messages = _toChatMessages(llmContext);
      final prompt = PromptValue.chat(messages);
      return await chatModel.countTokens(prompt);
    } catch (e) {
      debugPrint("Error in LlmService.countTokens for ${apiConfig.apiType}: $e");
      rethrow;
    }
  }

  /// 获取 OpenAI 兼容 API 的可用模型列表。
  Future<List<OpenAIModel>> fetchModels({
    required String baseUrl,
    required String apiKey,
  }) async {
    final dio = Dio();
    final String? correctedBaseUrl = _normalizeBaseUrl(baseUrl);
    if (correctedBaseUrl == null) {
      throw Exception('Invalid Base URL format.');
    }
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

  /// Cancels the ongoing request.
  Future<void> cancelActiveRequest() async {
    // TODO: Cancellation is not directly supported in the same way without Dio.
    // Langchain's http client usage would need to be investigated for a new cancellation strategy.
    // For now, we can't cancel requests.
    debugPrint("LlmService: Request cancellation is currently not implemented.");
  }

  // --- Private Helper Methods ---

  /// 根据 ApiConfig 创建相应的 langchain ChatModel 实例。
  BaseChatModel _createChatModel(ApiConfig apiConfig) {
    debugPrint('--- LlmService --- Creating chat model for ${apiConfig.apiType} with baseUrl: "${apiConfig.baseUrl}"');

    switch (apiConfig.apiType) {
      case LlmType.openai:
        // OpenAI's baseUrl works as expected.
        return ChatOpenAI(
          apiKey: apiConfig.apiKey,
          baseUrl: _normalizeBaseUrl(apiConfig.baseUrl) ?? 'https://api.openai.com/v1',
          defaultOptions: ChatOpenAIOptions(
            model: apiConfig.model,
            temperature: apiConfig.temperature,
            topP: apiConfig.topP,
            maxTokens: apiConfig.maxOutputTokens,
            stop: apiConfig.stopSequences,
          ),
        );
      case LlmType.gemini:
        http.Client? client;
        // For Gemini, we need to create a custom client to handle the proxy.
        if (apiConfig.baseUrl != null && apiConfig.baseUrl!.isNotEmpty) {
          final dio = Dio(BaseOptions(baseUrl: _normalizeBaseUrl(apiConfig.baseUrl)!));
          
          // DANGER: This should only be used for debugging purposes.
          // It allows Dio to accept bad SSL certificates, which is useful for proxies like Charles/Fiddler.
          (dio.httpClientAdapter as IOHttpClientAdapter).onHttpClientCreate = (client) {
            client.badCertificateCallback = (cert, host, port) => true;
            return client;
          };

          client = _DioHttpClient(dio);
        }
        
        return ChatGoogleGenerativeAI(
          apiKey: apiConfig.apiKey,
          defaultOptions: ChatGoogleGenerativeAIOptions(
            model: apiConfig.model,
            temperature: apiConfig.temperature,
            topP: apiConfig.topP,
            topK: apiConfig.topK,
            maxOutputTokens: apiConfig.maxOutputTokens,
            stopSequences: apiConfig.stopSequences,
          ),
          client: client,
        );
      default:
        throw UnimplementedError('Unsupported API type: ${apiConfig.apiType}');
    }
  }

  /// OpenAI 图像生成实现
  Future<LlmImageResponse> _generateImageOpenAI(List<LlmContent> llmContext, ApiConfig apiConfig, int n) async {
    final tool = OpenAIDallETool(
      apiKey: apiConfig.apiKey,
      baseUrl: _normalizeBaseUrl(apiConfig.baseUrl),
      defaultOptions: OpenAIDallEToolOptions(
        model: apiConfig.model,
        responseFormat: ImageResponseFormat.b64Json,
      ),
    );

    final prompt = llmContext
        .where((c) => c.role == 'user')
        .expand((c) => c.parts)
        .whereType<LlmTextPart>()
        .map((p) => p.text)
        .join('\n');

    if (prompt.isEmpty) {
      return const LlmImageResponse.error("Image generation requires a text prompt.");
    }

    // OpenAIDallETool is hardcoded to return only one image (n=1).
    // To generate n images, we must call it n times.
    final imageFutures = <Future<String>>[];
    for (int i = 0; i < n; i++) {
      imageFutures.add(tool.invoke(prompt));
    }
    
    final results = await Future.wait(imageFutures);
    final images = <String>[];
    for (final resultString in results) {
      final resultJson = jsonDecode(resultString) as Map<String, dynamic>;
      final data = resultJson['data'] as List<dynamic>?;
      if (data != null) {
        final b64Json = data.first['b64_json'] as String?;
        if (b64Json != null) {
          images.add(b64Json);
        }
      }
    }

    return LlmImageResponse(base64Images: images, isSuccess: true);
  }

  /// Gemini 图像生成实现
  Future<LlmImageResponse> _generateImageGemini(List<LlmContent> llmContext, ApiConfig apiConfig) async {
    // Use a vision-capable model for image generation.
    final visionApiConfig = apiConfig.copyWith(model: 'gemini-pro-vision');
    final chatModel = _createChatModel(visionApiConfig);
    final messages = _toChatMessages(llmContext);
    final prompt = PromptValue.chat(messages);

    final result = await chatModel.invoke(prompt);

    // The raw response is stored in the metadata.
    final rawResponse = result.metadata['raw_response'] as google_ai.GenerateContentResponse?;
    if (rawResponse == null) {
      return const LlmImageResponse.error("Could not get raw response from metadata.");
    }

    final textParts = StringBuffer();
    final imageParts = <String>[];

    for (final candidate in rawResponse.candidates) {
      for (final part in candidate.content.parts) {
        if (part is google_ai.TextPart) {
          textParts.writeln(part.text);
        } else if (part is google_ai.DataPart) {
          imageParts.add(base64.encode(part.bytes));
        }
      }
    }

    if (imageParts.isEmpty && textParts.isEmpty) {
      return const LlmImageResponse.error("No image or text content found in response.");
    }

    return LlmImageResponse(
      base64Images: imageParts,
      text: textParts.toString().trim().isNotEmpty ? textParts.toString().trim() : null,
      isSuccess: true,
    );
  }

  // --- Mappers (inlined from mappers.dart) ---

  /// Converts a list of local [LlmContent] objects to a list of LangChain [ChatMessage] objects.
  static List<ChatMessage> _toChatMessages(List<LlmContent> llmContext) {
    return llmContext.map((content) {
      final parts = content.parts.map((part) {
        if (part is LlmTextPart) {
          return ChatMessageContent.text(part.text);
        } else if (part is LlmDataPart) {
          return ChatMessageContent.image(
            mimeType: part.mimeType,
            data: part.base64Data,
          );
        }
        return null;
      }).whereType<ChatMessageContent>().toList();

      switch (content.role) {
        case 'user':
          return ChatMessage.human(ChatMessageContent.multiModal(parts));
        case 'model':
          final textContent = content.parts
              .whereType<LlmTextPart>()
              .map((p) => p.text)
              .join('\n');
          return ChatMessage.ai(textContent);
        case 'system':
          final text = content.parts
              .whereType<LlmTextPart>()
              .map((p) => p.text)
              .join('\n');
          return ChatMessage.system(text);
        default:
          final textContent = content.parts
              .whereType<LlmTextPart>()
              .map((p) => p.text)
              .join('\n');
          return ChatMessage.custom(textContent, role: content.role);
      }
    }).toList();
  }

  /// Converts a LangChain [ChatResult] to a local [LlmResponse].
  static LlmResponse _toLlmResponse(ChatResult chatResult) {
    final output = chatResult.output;
    final content = output.content;
    return LlmResponse(parts: [MessagePart.text(content)]);
  }

  /// Converts a streaming LangChain [ChatResult] to a local [LlmStreamChunk].
  static LlmStreamChunk _toLlmStreamChunk(ChatResult chatResult, String accumulatedText) {
    final output = chatResult.output;
    final chunkText = output.content;
    final newAccumulatedText = accumulatedText + chunkText;
    return LlmStreamChunk(
      textChunk: chunkText,
      accumulatedText: newAccumulatedText,
      isFinished: false,
      timestamp: DateTime.now(),
    );
  }

  String? _normalizeBaseUrl(String? baseUrl) {
    if (baseUrl == null) return null;
    var trimmedUrl = baseUrl.trim();
    if (trimmedUrl.isEmpty) {
      return null;
    }
  
    if (!trimmedUrl.startsWith('http://') && !trimmedUrl.startsWith('https://')) {
      trimmedUrl = 'https://$trimmedUrl';
    }
  
    // A trailing slash is crucial for the http client's Uri.resolve method
    // to correctly preserve the path segment of the baseUrl.
    if (!trimmedUrl.endsWith('/')) {
      trimmedUrl += '/';
    }
    
    // Final check for a valid URI
    try {
      Uri.parse(trimmedUrl);
      return trimmedUrl;
    } catch (e) {
      return null;
    }
  }
}

// --- Custom Dio HTTP Client (Top-level class) ---

/// A custom http.Client that uses a Dio instance to send requests.
/// This allows us to use Dio's features (like setting a baseUrl for a proxy)
/// while still providing a standard http.Client to langchain.
class _DioHttpClient extends http.BaseClient {
  final Dio dio;

  _DioHttpClient(this.dio);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final requestUri = request.url;
    Object? requestBody;

    if (request is http.Request) {
      final bytes = await request.finalize().toBytes();
      if (bytes.isNotEmpty) {
        try {
          final decodedBody = json.decode(utf8.decode(bytes));
          // This is the fix: some proxy servers might not expect the request to be wrapped in `generateContentRequest`.
          // We check for this key and unwrap the body if it exists.
          if (decodedBody is Map<String, dynamic> && decodedBody.containsKey('generateContentRequest')) {
            requestBody = decodedBody['generateContentRequest'];
          } else {
            requestBody = decodedBody;
          }
        } catch (e) {
          // Not a valid JSON, send as is.
          requestBody = bytes;
        }
      }
    }
    
    // Dio's baseUrl will handle the proxying. We just need to pass the path.
    // The request's URL will be absolute (e.g., https://generativelanguage.googleapis.com/...),
    // but Dio's baseUrl will replace the host and scheme.
    final response = await dio.request(
      requestUri.path, // Pass the path and query to Dio
      queryParameters: requestUri.queryParameters,
      data: requestBody,
      options: Options(
        method: request.method,
        headers: request.headers,
        responseType: ResponseType.stream, // Important for streaming responses
      ),
    );

    final stream = response.data?.stream as Stream<List<int>>;
    
    return http.StreamedResponse(
      stream,
      response.statusCode!,
      headers: response.headers.map.map((key, value) => MapEntry(key, value.join(', '))),
      reasonPhrase: response.statusMessage,
    );
  }
}

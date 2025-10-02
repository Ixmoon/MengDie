// coverage:ignore-file
// 本文件包含 LlmService 类，它作为与各种大型语言模型 (LLM) API 交互的中心枢纽。
// 它实现了扁平化和中心化的设计，直接处理与 langchain_dart 的交互，
// 避免了多层抽象，提高了代码的清晰度和可维护性。

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  CancelToken? _cancelToken;

  LlmService(this._ref);

  /// 发送消息并获取流式响应。
  Stream<LlmStreamChunk> sendMessageStream({
    required List<LlmContent> llmContext,
    required ApiConfig apiConfig,
  }) async* {
    try {
      final chatModel = _createChatModel(apiConfig);
      final messages = _toChatMessages(llmContext, apiConfig: apiConfig);
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
      final messages = _toChatMessages(llmContext, apiConfig: apiConfig);
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
      final messages = _toChatMessages(llmContext, apiConfig: apiConfig);
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
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel("Request cancelled by user.");
      debugPrint("LlmService: Active request cancellation triggered.");
    }
    // Discard the token after cancellation. A new one will be created for the next request.
    _cancelToken = null;
  }

  // --- Private Helper Methods ---

  /// 根据 ApiConfig 创建相应的 langchain ChatModel 实例。
  BaseChatModel _createChatModel(ApiConfig apiConfig) {
    debugPrint('--- LlmService --- Creating chat model for ${apiConfig.apiType} with baseUrl: "${apiConfig.baseUrl}"');
    
    // Create a new cancel token for this request.
    _cancelToken = CancelToken();

    // Create a custom Dio-backed HTTP client to handle requests, enabling cancellation and proxying.
    final httpClient = _createHttpClient(apiConfig, _cancelToken!);

    switch (apiConfig.apiType) {
      case LlmType.openai:
        return ChatOpenAI(
          apiKey: apiConfig.apiKey,
          // The baseUrl is handled by the custom client, so we don't set it here.
          defaultOptions: ChatOpenAIOptions(
            model: apiConfig.model,
            temperature: apiConfig.temperature,
            topP: apiConfig.topP,
            maxTokens: apiConfig.maxOutputTokens,
            stop: apiConfig.stopSequences,
          ),
          client: httpClient,
        );
      case LlmType.gemini:
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
          client: httpClient,
        );
      default:
        throw UnimplementedError('Unsupported API type: ${apiConfig.apiType}');
    }
  }

  /// Creates a custom http.Client backed by Dio to support cancellation and proxying.
  http.Client _createHttpClient(ApiConfig apiConfig, CancelToken cancelToken) {
    final String? normalizedBaseUrl = _normalizeBaseUrl(apiConfig.baseUrl);

    // If a baseUrl is provided, we assume it's a proxy and set it as Dio's base.
    // Otherwise, Dio will work with the full URLs passed to it by the langchain library.
    final dio = Dio(BaseOptions(baseUrl: normalizedBaseUrl ?? ''));

    // Special handling for Gemini proxy debugging (allowing bad SSL certificates).
    if (apiConfig.apiType == LlmType.gemini && normalizedBaseUrl != null) {
      (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient();
        client.badCertificateCallback = (cert, host, port) => true;
        return client;
      };
    }

    return _DioHttpClient(dio, cancelToken: cancelToken);
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
    final messages = _toChatMessages(llmContext, apiConfig: visionApiConfig);
    final prompt = PromptValue.chat(messages);

    final result = await chatModel.invoke(prompt);

    // The raw response is stored in the metadata.
    final rawResponse = result.metadata['raw_response'];
    if (rawResponse == null) {
      return const LlmImageResponse.error("Could not get raw response from metadata.");
    }

    final textParts = StringBuffer();
    final imageParts = <String>[];

    for (final candidate in (rawResponse as dynamic).candidates) {
      for (final part in (candidate as dynamic).content.parts) {
        // As we cannot use type checks without the import, we resort to duck typing.
        // We try to access properties that are unique to each part type.
        try {
          // This will succeed for TextPart and throw for DataPart.
          textParts.writeln((part as dynamic).text);
        } catch (_) {
          try {
            // This will succeed for DataPart and throw for TextPart.
            imageParts.add(base64.encode((part as dynamic).bytes));
          } catch (e) {
            // This part is neither TextPart nor DataPart that we can handle.
            debugPrint('Unknown part type in Gemini response: $e');
          }
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
  static List<ChatMessage> _toChatMessages(
    List<LlmContent> llmContext, {
    required ApiConfig apiConfig,
  }) {
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
          final textContent = content.parts.whereType<LlmTextPart>().map((p) => p.text).join('\n');
          return ChatMessage.ai(textContent);
        case 'system':
          final text = content.parts.whereType<LlmTextPart>().map((p) => p.text).join('\n');
          // This is a workaround for the incompatibility between langchain_google (which targets the standard Gemini API)
          // and Vertex AI API endpoints. By treating the system prompt as a human prompt, we force the library
          // to construct a request payload that is compatible with the Vertex AI proxy, avoiding a 400 error.
          if (apiConfig.apiType == LlmType.gemini) {
            return ChatMessage.human(ChatMessageContent.text(text));
          }
          return ChatMessage.system(text);
        default:
          final textContent = content.parts.whereType<LlmTextPart>().map((p) => p.text).join('\n');
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
  final CancelToken? cancelToken;

  _DioHttpClient(this.dio, {this.cancelToken});

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
    
    // If Dio's baseUrl is set, it acts as a proxy, and we should only send the path.
    // Otherwise, send the full URI to make a direct request.
    final String url = dio.options.baseUrl.isEmpty ? requestUri.toString() : requestUri.path;

    final response = await dio.request(
      url,
      queryParameters: requestUri.queryParameters,
      data: requestBody,
      cancelToken: cancelToken,
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

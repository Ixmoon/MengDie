import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
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
  bool _isThinkStreamActive = false;

  GeminiService(this._apiKeyNotifier, this._requestHandler);

  /// Fetches the list of available Gemini models from the API.
  Future<List<GeminiModel>> fetchModels({
    required String baseUrl,
    required String apiKey,
  }) async {
    final payload = GeminiListModelsPayload(
      apiKey: apiKey,
      apiConfig: ApiConfig.empty().copyWith(baseUrl: baseUrl, apiKey: apiKey),
    );
    final dio = Dio();
    try {
      final response = await dio.get(
        payload.buildUrl(),
        options: Options(headers: payload.buildHeaders()),
      );

      if (response.statusCode == 200 && response.data?['models'] is List) {
        final data = response.data['models'] as List;
        final models = data
            .map((modelJson) => GeminiModel.fromJson(modelJson))
            .where((m) {
              return m.supportedGenerationMethods.contains('generateContent');
            })
            .toList();
        models.sort(
          (a, b) =>
              (a.displayName ?? a.name).compareTo(b.displayName ?? b.name),
        );
        return models;
      } else {
        throw Exception('Failed to load models: Status ${response.statusCode}');
      }
    } on DioException catch (e) {
      final handler = LlmRequestHandler(dio);
      final errorMsg = handler.formatDioError(e, 'Gemini');
      throw Exception('Failed to fetch models: $errorMsg');
    } catch (e) {
      throw Exception('An unexpected error occurred while fetching models: $e');
    }
  }

  @override
  Stream<LlmStreamChunk> sendMessageStream({
    required List<LlmContent> llmContext,
    required ApiConfig apiConfig,
    required Map<String, dynamic> generationParams,
    bool isGoogleSearchEnabled = false,
    bool isUrlContextEnabled = false,
    bool isCodeExecutionEnabled = false,
  }) {
    _cancelToken = CancelToken();
    _requestHandler.setCancelToken(_cancelToken);

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
      isGoogleSearchEnabled: isGoogleSearchEnabled,
      isUrlContextEnabled: isUrlContextEnabled,
      isCodeExecutionEnabled: isCodeExecutionEnabled,
    );

    return _requestHandler.executeStream(
      payload,
      textExtractor: (json) =>
          _extractTextAndThinkFromChunk(json, isStreaming: true),
      citationApplier: _addCitationsToText,
    );
  }

  @override
  Stream<LlmStreamChunk> sendParallelMessageStream({
    required List<LlmContent> llmContext,
    required ApiConfig apiConfig,
    required Map<String, dynamic> generationParams,
    required int parallelCount,
    bool isGoogleSearchEnabled = false,
    bool isUrlContextEnabled = false,
    bool isCodeExecutionEnabled = false,
  }) {
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
      isGoogleSearchEnabled: isGoogleSearchEnabled,
      isUrlContextEnabled: isUrlContextEnabled,
      isCodeExecutionEnabled: isCodeExecutionEnabled,
    );

    return _requestHandler.executeParallelStream(
      payload,
      count: parallelCount,
      textExtractor: (json) =>
          _extractTextAndThinkFromChunk(json, isStreaming: true),
      citationApplier: _addCitationsToText,
    );
  }

  @override
  Future<LlmResponse> sendMessageOnce({
    required List<LlmContent> llmContext,
    required ApiConfig apiConfig,
    required Map<String, dynamic> generationParams,
    bool isGoogleSearchEnabled = false,
    bool isUrlContextEnabled = false,
    bool isCodeExecutionEnabled = false,
  }) {
    _cancelToken = CancelToken();
    _requestHandler.setCancelToken(_cancelToken);

    _isThinkStreamActive = false;

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
      isGoogleSearchEnabled: isGoogleSearchEnabled,
      isUrlContextEnabled: isUrlContextEnabled,
      isCodeExecutionEnabled: isCodeExecutionEnabled,
    );

    return _requestHandler.executeOnce(
      payload,
      responseParser: _parseGeminiResponse,
    );
  }

  @override
  Future<LlmResponse> sendParallelMessageOnce({
    required List<LlmContent> llmContext,
    required ApiConfig apiConfig,
    required Map<String, dynamic> generationParams,
    required int parallelCount,
    bool isGoogleSearchEnabled = false,
    bool isUrlContextEnabled = false,
    bool isCodeExecutionEnabled = false,
  }) {
    _isThinkStreamActive = false;

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
      isGoogleSearchEnabled: isGoogleSearchEnabled,
      isUrlContextEnabled: isUrlContextEnabled,
      isCodeExecutionEnabled: isCodeExecutionEnabled,
    );

    return _requestHandler.executeParallelOnce(
      payload,
      count: parallelCount,
      responseParser: _parseGeminiResponse,
    );
  }

  @override
  Stream<LlmStreamChunk> generateImageStream({
    required List<LlmContent> llmContext,
    required ApiConfig apiConfig,
    int n = 1,
  }) {
    _cancelToken = CancelToken();
    _requestHandler.setCancelToken(_cancelToken);

    final apiKey = apiConfig.apiKey?.isNotEmpty == true
        ? apiConfig.apiKey
        : _apiKeyNotifier.getNextGeminiApiKey();

    if (apiKey == null || apiKey.isEmpty) {
      return Stream.value(LlmStreamChunk.error("没有可用的 Gemini API Key。", ''));
    }

    final payload = GeminiImagePayload(
      apiKey: apiKey,
      apiConfig: apiConfig,
      generationParams: {},
      llmContext: llmContext,
      stream: true,
    );

    return _requestHandler.executeStream(
      payload,
      textExtractor: _extractTextOrImageFromChunk,
    );
  }

  @override
  Future<LlmImageResponse> generateImageOnce({
    required List<LlmContent> llmContext,
    required ApiConfig apiConfig,
    int n = 1,
  }) {
    _cancelToken = CancelToken();
    _requestHandler.setCancelToken(_cancelToken);

    final apiKey = apiConfig.apiKey?.isNotEmpty == true
        ? apiConfig.apiKey
        : _apiKeyNotifier.getNextGeminiApiKey();

    if (apiKey == null || apiKey.isEmpty) {
      return Future.value(
        const LlmImageResponse.error("没有可用的 Gemini API Key。"),
      );
    }

    final payload = GeminiImagePayload(
      apiKey: apiKey,
      apiConfig: apiConfig,
      generationParams: {},
      llmContext: llmContext,
      stream: false,
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
      final remoteResult = await _requestHandler
          .executeCountTokens(payload)
          .timeout(const Duration(seconds: 3));
      return remoteResult;
    } catch (e) {
      return await localCalculation;
    }
  }

  // --- Helpers ---
  String _formatGroundingMetadata(Map<String, dynamic> metadata) {
    final webSearchQueries = metadata['webSearchQueries'] as List?;
    final groundingChunks = metadata['groundingChunks'] as List?;

    if ((webSearchQueries == null || webSearchQueries.isEmpty) &&
        (groundingChunks == null || groundingChunks.isEmpty)) {
      return '';
    }

    final buffer = StringBuffer();
    buffer.writeln('<grounding>');
    if (webSearchQueries != null && webSearchQueries.isNotEmpty) {
      buffer.writeln('  <queries>');
      for (final query in webSearchQueries) {
        buffer.writeln('    <query>${query.toString()}</query>');
      }
      buffer.writeln('  </queries>');
    }
    if (groundingChunks != null && groundingChunks.isNotEmpty) {
      buffer.writeln('  <sources>');
      for (final entry in groundingChunks.asMap().entries) {
        final index = entry.key;
        final chunk = entry.value;
        final source = chunk['web'] as Map?;
        if (source != null) {
          final uri = source['uri'] as String?;
          final title = source['title'] as String?;
          if (uri != null && title != null) {
            buffer.writeln('    <source>[${index + 1}] [$title]($uri)</source>');
          }
        }
      }
      buffer.writeln('  </sources>');
    }
    buffer.write('</grounding>');
    return buffer.toString();
  }

  /// 根据 grounding metadata 为文本添加内嵌引用。
  ///
  /// [text]: 模型生成的原始文本。
  /// [metadata]: 包含 `groundingSupports` 和 `groundingChunks` 的元数据。
  /// 返回带有 Markdown 格式引用的文本。
  String _addCitationsToText(String text, Map<String, dynamic> metadata) {
    final supports = metadata['groundingSupports'] as List?;
    final chunks = metadata['groundingChunks'] as List?;

    if (supports == null ||
        supports.isEmpty ||
        chunks == null ||
        chunks.isEmpty) {
      return text;
    }

    var citedText = text;

    final sortedSupports = List<Map<String, dynamic>>.from(supports);
    sortedSupports.sort((a, b) {
      final endA = a['segment']?['endIndex'] as int? ?? 0;
      final endB = b['segment']?['endIndex'] as int? ?? 0;
      return endB.compareTo(endA);
    });

    for (final support in sortedSupports) {
      final segment = support['segment'] as Map?;
      final segmentText = segment?['text'] as String?;
      final chunkIndices = support['groundingChunkIndices'] as List?;

      if (segmentText != null &&
          segmentText.isNotEmpty &&
          chunkIndices != null &&
          chunkIndices.isNotEmpty) {
        final citationLinks = <String>[];
        for (final i in chunkIndices) {
          if (i is int && i < chunks.length) {
            final chunk = chunks[i] as Map?;
            final uri = chunk?['web']?['uri'] as String?;
            if (uri != null) {
              citationLinks.add('[[${i + 1}]($uri)]');
            }
          }
        }

        if (citationLinks.isNotEmpty) {
          final citationString = citationLinks.join('');
          final lastIndex = citedText.lastIndexOf(segmentText);
          if (lastIndex != -1) {
            final insertionPoint = lastIndex + segmentText.length;
            citedText = citedText.substring(0, insertionPoint) +
                citationString +
                citedText.substring(insertionPoint);
          }
        }
      }
    }
    return citedText;
  }

  String _formatUrlContextMetadata(Map<String, dynamic> metadata) {
    final urlMetadata = metadata['url_metadata'] as List?;

    if (urlMetadata == null || urlMetadata.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    buffer.writeln('<url_context>');
    if (urlMetadata.isNotEmpty) {
      buffer.writeln('  <retrieved_urls>');
      for (final item in urlMetadata) {
        final url = item['retrieved_url'] as String?;
        final status = item['url_retrieval_status'] as String?;
        if (url != null && status != null) {
          buffer.writeln('    <url status="$status">$url</url>');
        }
      }
      buffer.writeln('  </retrieved_urls>');
    }
    buffer.write('</url_context>');
    return buffer.toString();
  }

  // Unified chunk processor for both stream and once modes
  String _extractTextAndThinkFromChunk(
    Map<String, dynamic> json, {
    bool isStreaming = false,
  }) {
    final candidates = json['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return '';

    final firstCandidate = candidates.first as Map<String, dynamic>? ?? {};

    // --- Metadata Handling ---
    final groundingMetadata =
        firstCandidate['groundingMetadata'] as Map<String, dynamic>?;
    String groundingXml = '';
    if (groundingMetadata != null) {
      groundingXml = _formatGroundingMetadata(groundingMetadata);
    }
    final urlContextMetadata =
        firstCandidate['url_context_metadata'] as Map<String, dynamic>?;
    String urlContextXml = '';
    if (urlContextMetadata != null) {
      urlContextXml = _formatUrlContextMetadata(urlContextMetadata);
    }

    final finishReason = firstCandidate['finishReason'] as String?;
    if (finishReason != null && finishReason != 'STOP') {
      return ""; // The logic is handled in the request handler.
    }

    final content = firstCandidate['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      final metadataBuffer = StringBuffer();
      if (groundingXml.isNotEmpty) metadataBuffer.write('\n$groundingXml');
      if (urlContextXml.isNotEmpty) metadataBuffer.write('\n$urlContextXml');
      return metadataBuffer.toString();
    }

    final textBuffer = StringBuffer();
    for (final part in parts) {
      final partMap = part as Map<String, dynamic>;

      // --- Thought Handling (Restored) ---
      final isThoughtChunk = partMap['thought'] as bool? ?? false;
      if (isThoughtChunk && !_isThinkStreamActive) {
        _isThinkStreamActive = true;
        textBuffer.write('<think>\n');
      }
      if (!isThoughtChunk && _isThinkStreamActive) {
        _isThinkStreamActive = false;
        textBuffer.write('</think>\n');
      }

      // --- Content Part Handling (New + Old) ---
      if (partMap.containsKey('text')) {
        textBuffer.write(partMap['text'] as String? ?? '');
      } else if (partMap.containsKey('executableCode')) {
        final codeMap = partMap['executableCode'] as Map<String, dynamic>?;
        final language = (codeMap?['language'] as String? ?? 'python')
            .toLowerCase();
        final code = codeMap?['code'] as String? ?? '';
        if (code.isNotEmpty) {
          textBuffer.writeln('```$language');
          textBuffer.writeln(code.trim());
          textBuffer.writeln('```');
        }
      } else if (partMap.containsKey('codeExecutionResult')) {
        final resultMap =
            partMap['codeExecutionResult'] as Map<String, dynamic>?;
        final output = resultMap?['output'] as String? ?? '';
        if (output.isNotEmpty) {
          textBuffer.writeln('<codeExecutionResult>');
          textBuffer.writeln(output.trim());
          textBuffer.writeln('</codeExecutionResult>');
        }
      }
    }

    // Append metadata XML at the end of the text content.
    if (groundingXml.isNotEmpty) {
      textBuffer.write('\n$groundingXml');
    }
    if (urlContextXml.isNotEmpty) {
      textBuffer.write('\n$urlContextXml');
    }

    return textBuffer.toString();
  }

  LlmResponse _parseGeminiResponse(Map<String, dynamic> data) {
    var text = _extractTextAndThinkFromChunk(data, isStreaming: false);
    final candidates = data['candidates'] as List?;
    final groundingMetadata =
        candidates?.first?['groundingMetadata'] as Map<String, dynamic>?;

    // 在返回最终响应之前应用引用
    if (groundingMetadata != null && text.isNotEmpty) {
      text = _addCitationsToText(text, groundingMetadata);
    }

    if (text.isNotEmpty) {
      return LlmResponse(
        parts: [MessagePart.text(text)],
        groundingMetadata: groundingMetadata,
      );
    }
    return const LlmResponse.error(
      "Invalid response: No valid text parts found in Gemini response.",
    );
  }

  String _extractImageFromChunk(Map<String, dynamic> json) {
    final candidates = json['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return '';

    final content = candidates.first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;
    if (parts == null || parts.isEmpty) return '';

    final part = parts.first as Map<String, dynamic>? ?? {};
    final inlineData = part['inlineData'] as Map<String, dynamic>?;
    if (inlineData != null) {
      final mimeType = inlineData['mimeType'] as String?;
      if (mimeType != null && mimeType.startsWith('image/')) {
        return inlineData['data'] as String? ?? '';
      }
    }
    return '';
  }

  String _extractTextOrImageFromChunk(Map<String, dynamic> json) {
    final candidates = json['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return '';

    final content = candidates.first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;
    if (parts == null || parts.isEmpty) return '';

    // Gemini's image generation can have multiple parts in a single response chunk
    for (final part in parts) {
      if (part is! Map<String, dynamic>) continue;

      final inlineData = part['inlineData'] as Map<String, dynamic>?;
      if (inlineData != null) {
        final mimeType = inlineData['mimeType'] as String?;
        if (mimeType != null && mimeType.startsWith('image/')) {
          final data = inlineData['data'] as String? ?? '';
          if (data.isNotEmpty) return 'IMAGE:$data';
        }
      }

      final text = part['text'] as String? ?? '';
      if (text.isNotEmpty) {
        return 'TEXT:$text';
      }
    }
    return '';
  }
}

// --- Payload Definitions ---

class GeminiChatPayload extends HttpRequestPayload {
  final String apiKey;
  final bool stream;
  final bool isGoogleSearchEnabled;
  final bool isUrlContextEnabled;
  final bool isCodeExecutionEnabled;

  GeminiChatPayload({
    required this.apiKey,
    required this.stream,
    required this.isGoogleSearchEnabled,
    required this.isUrlContextEnabled,
    required this.isCodeExecutionEnabled,
    required super.apiConfig,
    required super.generationParams,
    required super.llmContext,
  });

  @override
  String buildUrl() {
    const defaultBaseUrl = "https://generativelanguage.googleapis.com";
    final baseUrl = apiConfig.baseUrl?.isNotEmpty == true
        ? apiConfig.baseUrl!
        : defaultBaseUrl;
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
      final parts = c.parts
          .map((part) {
            if (part is LlmTextPart) return {'text': part.text};
            if (part is LlmDataPart) {
              return {
                'inline_data': {
                  'mime_type': part.mimeType,
                  'data': part.base64Data,
                },
              };
            }
            if (part is LlmFilePart) {
              return {
                'file_data': {
                  'mime_type': part.mimeType,
                  'file_uri': part.fileUri,
                },
              };
            }
            if (part is LlmAudioPart) {
              return {
                'inline_data': {
                  'mime_type': part.mimeType,
                  'data': part.base64Data,
                },
              };
            }
            return null;
          })
          .where((p) => p != null)
          .toList();

      if (parts.isEmpty) continue;

      if (c.role == "system") {
        if (systemInstruction != null) {}
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

    // --- Tools Configuration ---
    List<dynamic> tools = [];
    if (apiConfig.toolConfig != null && apiConfig.toolConfig!.isNotEmpty) {
      try {
        final toolConfigJson = jsonDecode(apiConfig.toolConfig!);
        if (toolConfigJson is List) {
          tools.addAll(toolConfigJson);
        } else if (toolConfigJson is Map) {
          // Handle cases where a single tool config is provided as a map
          tools.add(toolConfigJson);
        }
      } catch (e) {
        // Ignore invalid JSON in toolConfig
      }
    }

    if (isGoogleSearchEnabled) {
      tools.add({"google_search": {}});
    }
    if (isUrlContextEnabled) {
      tools.add({"url_context": {}});
    }
    if (isCodeExecutionEnabled) {
      tools.add({"code_execution": {}});
    }

    if (tools.isNotEmpty) {
      body['tools'] = tools;
    }

    return body;
  }

  Map<String, dynamic> _buildGenerationConfig() {
    final config = <String, dynamic>{};
    if (generationParams['temperature'] != null) {
      config['temperature'] = generationParams['temperature'];
    }
    if (generationParams['topP'] != null) {
      config['topP'] = generationParams['topP'];
    }
    if (generationParams['topK'] != null) {
      config['topK'] = generationParams['topK'];
    }
    if (generationParams['maxOutputTokens'] != null) {
      config['maxOutputTokens'] = generationParams['maxOutputTokens'];
    }
    if (generationParams['stopSequences'] != null) {
      config['stopSequences'] = generationParams['stopSequences'];
    }

    final bool includeThoughts =
        generationParams['includeThoughts'] as bool? ?? false;
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
  final bool stream;

  GeminiImagePayload({
    required this.apiKey,
    required this.stream,
    required super.apiConfig,
    required super.generationParams,
    required super.llmContext,
  }) : super(prompt: ''); // prompt is not directly used, but required by super

  @override
  String buildUrl() {
    const defaultBaseUrl = "https://generativelanguage.googleapis.com";
    final baseUrl = apiConfig.baseUrl?.isNotEmpty == true
        ? apiConfig.baseUrl!
        : defaultBaseUrl;
    final action = stream ? "streamGenerateContent" : "generateContent";
    return "$baseUrl/v1beta/models/${apiConfig.model}:$action?key=$apiKey${stream ? '&alt=sse' : ''}";
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
      final parts = c.parts
          .map((part) {
            if (part is LlmTextPart) return {'text': part.text};
            if (part is LlmDataPart) {
              return {
                'inline_data': {
                  'mime_type': part.mimeType,
                  'data': part.base64Data,
                },
              };
            }
            if (part is LlmFilePart) {
              return {
                'file_data': {
                  'mime_type': part.mimeType,
                  'file_uri': part.fileUri,
                },
              };
            }
            if (part is LlmAudioPart) {
              return {
                'inline_data': {
                  'mime_type': part.mimeType,
                  'data': part.base64Data,
                },
              };
            }
            return null;
          })
          .where((p) => p != null)
          .toList();

      if (parts.isEmpty) continue;

      // Image generation with Gemini uses the 'user' role.
      history.add({'role': 'user', 'parts': parts});
    }

    return {
      "contents": history,
      "generationConfig": {
        "responseModalities": ["TEXT", "IMAGE"],
      },
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
    final baseUrl = apiConfig.baseUrl?.isNotEmpty == true
        ? apiConfig.baseUrl!
        : defaultBaseUrl;
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
      final parts = c.parts
          .map((part) {
            if (part is LlmTextPart) return {'text': part.text};
            if (part is LlmDataPart) {
              return {
                'inline_data': {
                  'mime_type': part.mimeType,
                  'data': part.base64Data,
                },
              };
            }
            if (part is LlmFilePart) {
              return {
                'file_data': {
                  'mime_type': part.mimeType,
                  'file_uri': part.fileUri,
                },
              };
            }
            if (part is LlmAudioPart) {
              return {
                'inline_data': {
                  'mime_type': part.mimeType,
                  'data': part.base64Data,
                },
              };
            }
            return null;
          })
          .where((p) => p != null)
          .toList();

      if (parts.isEmpty) continue;

      // countTokens doesn't use system instructions, roles must be user/model
      if (c.role == "user" || c.role == "model") {
        history.add({'role': c.role, 'parts': parts});
      }
    }
    return {'contents': history};
  }
}

/// Fetches the list of available Gemini models from the API.
Future<List<GeminiModel>> fetchModels({
  required String baseUrl,
  required String apiKey,
}) async {
  final payload = GeminiListModelsPayload(
    apiKey: apiKey,
    apiConfig: ApiConfig.empty().copyWith(baseUrl: baseUrl, apiKey: apiKey),
  );
  final dio = Dio();
  try {
    final response = await dio.get(
      payload.buildUrl(),
      options: Options(headers: payload.buildHeaders()),
    );

    if (response.statusCode == 200 && response.data?['models'] is List) {
      final data = response.data['models'] as List;
      final models = data
          .map((modelJson) => GeminiModel.fromJson(modelJson))
          // Only include models that support 'generateContent'
          .where(
            (m) => m.supportedGenerationMethods.contains('generateContent'),
          )
          .toList();
      // Sort by display name or name
      models.sort(
        (a, b) => (a.displayName ?? a.name).compareTo(b.displayName ?? b.name),
      );
      return models;
    } else {
      throw Exception('Failed to load models: Status ${response.statusCode}');
    }
  } on DioException catch (e) {
    final handler = LlmRequestHandler(dio);
    final errorMsg = handler.formatDioError(e, 'Gemini');
    throw Exception('Failed to fetch models: $errorMsg');
  } catch (e) {
    throw Exception('An unexpected error occurred while fetching models: $e');
  }
}

class GeminiListModelsPayload extends HttpRequestPayload {
  final String apiKey;

  GeminiListModelsPayload({required this.apiKey, required super.apiConfig})
    : super(generationParams: {});

  @override
  String buildUrl() {
    const defaultBaseUrl = "https://generativelanguage.googleapis.com";
    final baseUrl = apiConfig.baseUrl?.isNotEmpty == true
        ? apiConfig.baseUrl!
        : defaultBaseUrl;
    return "$baseUrl/v1beta/models?key=$apiKey";
  }

  @override
  Map<String, String> buildHeaders() {
    return {'Content-Type': 'application/json'};
  }

  @override
  Map<String, dynamic> buildBody() {
    // GET request does not have a body
    return {};
  }
}

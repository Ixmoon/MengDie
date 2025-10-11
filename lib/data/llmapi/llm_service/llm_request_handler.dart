import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../llm_models.dart';
import '../../../domain/models/api_config.dart';

// --- 1. Request Payload Abstraction ---

/// Abstract base class for all API request payloads.
///
/// It forces each provider-specific payload to define how to construct
/// its own URL, headers, and body, encapsulating all platform details.
abstract class HttpRequestPayload {
  final ApiConfig apiConfig;
  final Map<String, dynamic> generationParams;
  final List<LlmContent>? llmContext; // Nullable for image generation
  final String? prompt; // For image generation

  HttpRequestPayload({
    required this.apiConfig,
    required this.generationParams,
    this.llmContext,
    this.prompt,
  });

  String buildUrl();
  Map<String, String> buildHeaders();
  Map<String, dynamic> buildBody();
}

// --- 2. Central Request Handler ---

/// Handles the execution of all LLM API requests.
///
/// This class centralizes the entire network request lifecycle, including:
/// - Dio instance management.
/// - Calling payload-specific builders for URL, body, and headers.
/// - Executing the HTTP request.
/// - Processing normal, stream, and image responses.
/// - Centralized error handling.
class LlmRequestHandler {
  final Dio _dio;
  CancelToken? _cancelToken;

  LlmRequestHandler(this._dio);

  void setCancelToken(CancelToken? token) {
    _cancelToken = token;
  }

  /// Executes a request that returns a single, complete response.
  Future<LlmResponse> executeOnce(
    HttpRequestPayload payload, {
    required LlmResponse Function(Map<String, dynamic> data) responseParser,
  }) async {
    try {
      final response = await _dio.post(
        payload.buildUrl(),
        data: jsonEncode(payload.buildBody()),
        options: Options(headers: payload.buildHeaders()),
        cancelToken: _cancelToken,
      );

      if (response.statusCode == 200 && response.data != null) {
        return responseParser(response.data as Map<String, dynamic>);
      } else {
        return LlmResponse.error(
          "API Error: ${response.statusCode} ${response.statusMessage}",
        );
      }
    } on DioException catch (e) {
      return _handleDioErrorResponse(e, payload.apiConfig.apiType.name);
    } catch (e) {
      return _handleGeneralErrorResponse(e, payload.apiConfig.apiType.name);
    }
  }

  /// Executes a request that returns a stream of responses.
  Stream<LlmStreamChunk> executeStream(
    HttpRequestPayload payload, {
    required String Function(Map<String, dynamic> json) textExtractor,
  }) async* {
    try {
      final response = await _dio.post<ResponseBody>(
        payload.buildUrl(),
        data: jsonEncode(payload.buildBody()),
        cancelToken: _cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: payload.buildHeaders(),
        ),
      );
      yield* _processSseStream(
        stream: response.data!.stream,
        textExtractor: textExtractor,
      );
    } on DioException catch (e) {
      yield* _handleStreamDioError(e, payload.apiConfig.apiType.name);
    } catch (e) {
      yield _handleGeneralErrorStream(e, payload.apiConfig.apiType.name);
    }
  }

  /// Executes an image generation request.
  Future<LlmImageResponse> executeImage(HttpRequestPayload payload) async {
    // This method would be very similar to executeOnce, but returning LlmImageResponse
    // For brevity, we'll omit the full implementation, but it follows the same pattern.
    // It would call its own specific parser for the image response.
    try {
      final response = await _dio.post(
        payload.buildUrl(),
        data: jsonEncode(payload.buildBody()),
        options: Options(headers: payload.buildHeaders()),
        cancelToken: _cancelToken,
      );

      if (response.statusCode == 200 && response.data != null) {
        final responseData = response.data as Map<String, dynamic>;
        // Generic parsing logic would go here, likely needing a parser function
        // passed from the service, similar to the stream's textExtractor.
        final data = responseData['data'] as List?;
        if (data != null && data.isNotEmpty) {
          final images = data
              .map((item) => item['b64_json'] as String?)
              .whereType<String>()
              .toList();
          return LlmImageResponse(base64Images: images, isSuccess: true);
        }
        final candidates = responseData['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final images = candidates
              .expand(
                (candidate) => (candidate['content']?['parts'] as List? ?? []),
              )
              .map((part) => part['inlineData']?['data'] as String?)
              .whereType<String>()
              .toList();
          final text = candidates
              .expand(
                (candidate) => (candidate['content']?['parts'] as List? ?? []),
              )
              .map((part) => part['text'] as String?)
              .whereType<String>()
              .join();
          if (images.isNotEmpty || text.isNotEmpty) {
            return LlmImageResponse(
              base64Images: images,
              text: text,
              isSuccess: true,
            );
          }
        }

        return const LlmImageResponse.error(
          "Image response format unexpected.",
        );
      } else {
        return LlmImageResponse.error(
          "API Error: ${response.statusCode} ${response.statusMessage}",
        );
      }
    } on DioException catch (e) {
      return _handleDioErrorImage(e, payload.apiConfig.apiType.name);
    } catch (e) {
      return _handleGeneralErrorImage(e, payload.apiConfig.apiType.name);
    }
  }

  /// Executes a request to count tokens and returns the integer count.
  Future<int> executeCountTokens(HttpRequestPayload payload) async {
    try {
      final response = await _dio.post(
        payload.buildUrl(),
        data: jsonEncode(payload.buildBody()),
        options: Options(headers: payload.buildHeaders()),
        cancelToken: _cancelToken,
      );

      if (response.statusCode == 200 && response.data != null) {
        final totalTokens = response.data['totalTokens'] as int?;
        if (totalTokens != null) {
          return totalTokens;
        } else {
          throw Exception(
            "Count tokens response format unexpected: 'totalTokens' field is missing or not an int.",
          );
        }
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          message:
              "API Error: ${response.statusCode} ${response.statusMessage}",
        );
      }
    } on DioException {
      // Re-throw to be handled by the caller, which will then fallback to local calculation.
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  // --- 3. Private Helper Methods (Moved from LlmHelper) ---

  Stream<LlmStreamChunk> _processSseStream({
    required Stream<List<int>> stream,
    required String Function(Map<String, dynamic> json) textExtractor,
  }) async* {
    String accumulatedResponse = "";
    String carryOverBuffer = '';

    try {
      await for (var chunk in stream) {
        final rawChunk =
            carryOverBuffer + utf8.decode(chunk, allowMalformed: true);
        var lines = rawChunk.split('\n');

        if (!rawChunk.endsWith('\n')) {
          carryOverBuffer = lines.removeLast();
        } else {
          carryOverBuffer = '';
        }

        for (var line in lines) {
          if (line.startsWith('data: ')) {
            final jsonData = line.substring('data: '.length).trim();

            if (jsonData == '[DONE]') {
              yield LlmStreamChunk(
                textChunk: '',
                accumulatedText: accumulatedResponse,
                isFinished: true,
                timestamp: DateTime.now(),
              );
              return;
            }

            if (jsonData.isNotEmpty) {
              try {
                final jsonMap = jsonDecode(jsonData) as Map<String, dynamic>;

                // Check for finish reason before extracting text
                final finishReason = _extractFinishReason(jsonMap);
                if (finishReason != null) {
                  yield LlmStreamChunk.finishReason(
                    finishReason,
                    accumulatedResponse,
                  );
                  return; // Stop processing the stream
                }

                final textChunk = textExtractor(jsonMap);
                if (textChunk.isNotEmpty) {
                  accumulatedResponse += textChunk;
                  yield LlmStreamChunk(
                    textChunk: textChunk,
                    accumulatedText: accumulatedResponse,
                    timestamp: DateTime.now(),
                    isFinished: false,
                  );
                }
              } catch (_) {}
            }
          }
        }
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        // Yield a final error chunk and then stop the stream.
        yield LlmStreamChunk.error(
          "Request cancelled by user.",
          accumulatedResponse,
        );
        return;
      }
      // For other Dio errors, rethrow to be handled by the caller in executeStream.
      rethrow;
    }
    yield LlmStreamChunk(
      textChunk: '',
      accumulatedText: accumulatedResponse,
      isFinished: true,
      timestamp: DateTime.now(),
    );
  }

  /// Extracts finish reason from a JSON chunk. Returns null if not found or normal.
  String? _extractFinishReason(Map<String, dynamic> json) {
    // Gemini
    final geminiCandidates = json['candidates'] as List?;
    if (geminiCandidates != null && geminiCandidates.isNotEmpty) {
      final reason = geminiCandidates.first['finishReason'] as String?;
      if (reason != null && reason != 'STOP') {
        return reason;
      }
    }

    // OpenAI
    final openaiChoices = json['choices'] as List?;
    if (openaiChoices != null && openaiChoices.isNotEmpty) {
      final reason = openaiChoices.first['finish_reason'] as String?;
      if (reason != null && reason != 'stop') {
        return reason;
      }
    }

    return null;
  }

  LlmResponse _handleDioErrorResponse(DioException e, String serviceName) {
    if (CancelToken.isCancel(e)) {
      return const LlmResponse.error("Request cancelled by user.");
    }
    final errorMessage = _formatDioError(e, serviceName);
    return LlmResponse.error(errorMessage);
  }

  Stream<LlmStreamChunk> _handleStreamDioError(
    DioException e,
    String serviceName,
  ) async* {
    if (CancelToken.isCancel(e)) {
      yield LlmStreamChunk.error("Request cancelled by user.", '');
      return;
    }

    // For stream errors, the body is in a ResponseBody stream and must be read asynchronously.
    String bodyString = "(No response body)";
    String details = "";
    final data = e.response?.data;

    if (data != null && data is ResponseBody) {
      try {
        bodyString = await utf8.decodeStream(data.stream);
        // Now that we have the string, try to parse it for a detailed message.
        final errorJson = jsonDecode(bodyString);
        details =
            errorJson['error']?['message'] ??
            errorJson['message'] ??
            errorJson.toString();
      } catch (_) {
        // If decoding or parsing fails, use the raw string (if not too long).
        details = bodyString.length > 200
            ? "${bodyString.substring(0, 200)}..."
            : bodyString;
      }
    } else if (data != null) {
      // Fallback for non-streamed error bodies
      details = data.toString();
    }

    final errorMsg =
        "$serviceName API DioException: ${e.message}\n"
        "Status: ${e.response?.statusCode} - ${e.response?.statusMessage}\n"
        "Details: $details";

    yield LlmStreamChunk.error(errorMsg, '');
  }

  LlmImageResponse _handleDioErrorImage(DioException e, String serviceName) {
    if (CancelToken.isCancel(e)) {
      return const LlmImageResponse.error("Request cancelled by user.");
    }
    final errorMessage = _formatDioError(e, serviceName);
    return LlmImageResponse.error(errorMessage);
  }

  String _formatDioError(DioException e, String serviceName) {
    String errorMsg = "$serviceName API DioException: ${e.message}";
    if (e.response != null) {
      errorMsg +=
          "\nStatus: ${e.response?.statusCode} - ${e.response?.statusMessage}";

      // vvv --- 从这里开始，替换旧的 Body 处理逻辑 --- vvv
      if (e.response?.data != null) {
        try {
          final data = e.response!.data;
          Map<String, dynamic> errorJson;

          if (data is Map<String, dynamic>) {
            errorJson = data;
          } else if (data is String && data.isNotEmpty) {
            errorJson = jsonDecode(data);
          } else {
            throw const FormatException("响应体不是一个有效的 JSON 对象或字符串");
          }

          // 尝试从常见的错误结构中提取核心消息
          final message =
              errorJson['error']?['message'] ?? // OpenAI & Gemini v1
              errorJson['message'] ?? // Generic & Gemini v1.5
              errorJson.toString(); // 如果找不到，则回退
          errorMsg += "\nDetails: $message";
        } catch (_) {
          // 如果解析 JSON 失败，则回退到打印整个 Body
          errorMsg += "\nBody: ${e.response!.data.toString()}";
        }
      } else {
        errorMsg += "\nBody: (No response body)";
      }
      // ^^^ --- 到这里结束替换 --- ^^^
    }
    return errorMsg;
  }

  LlmResponse _handleGeneralErrorResponse(Object e, String serviceName) {
    final errorMsg = "Unexpected $serviceName Error: $e";
    return LlmResponse.error(errorMsg);
  }

  LlmStreamChunk _handleGeneralErrorStream(Object e, String serviceName) {
    final errorMsg = "Unexpected $serviceName Error: $e";
    return LlmStreamChunk.error(errorMsg, '');
  }

  LlmImageResponse _handleGeneralErrorImage(Object e, String serviceName) {
    final errorMsg = "Unexpected $serviceName Error: $e";
    return LlmImageResponse.error(errorMsg);
  }
}

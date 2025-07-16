import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'llm_models.dart';
import '../../data/models/api_config.dart';
import '../../data/models/message.dart'; // Import for MessagePart

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
  Future<LlmResponse> executeOnce(HttpRequestPayload payload) async {
    try {
      final response = await _dio.post(
        payload.buildUrl(),
        data: jsonEncode(payload.buildBody()),
        options: Options(headers: payload.buildHeaders()),
        cancelToken: _cancelToken,
      );

      if (response.statusCode == 200 && response.data != null) {
        // This part is generic, but parsing the actual text is specific.
        // For simplicity in this refactor, we assume a common 'text' field.
        // A more robust solution might pass a parser function.
        final responseData = response.data as Map<String, dynamic>;
        final candidates = responseData['candidates'] as List?;
        final text = candidates?.first['content']['parts'].first['text'] as String? ?? '';
        return LlmResponse(parts: [MessagePart.text(text)], isSuccess: true);
      } else {
        return LlmResponse.error("API Error: ${response.statusCode} ${response.statusMessage}");
      }
    } on DioException catch (e) {
      return _handleDioErrorResponse(e, payload.apiConfig.apiType.name);
    } catch (e) {
      return _handleGeneralErrorResponse(e, payload.apiConfig.apiType.name);
    }
  }

  /// Executes a request that returns a stream of responses.
  Stream<LlmStreamChunk> executeStream(HttpRequestPayload payload, {required String Function(Map<String, dynamic> json) textExtractor}) async* {
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
      yield* _processSseStream(stream: response.data!.stream, textExtractor: textExtractor);
    } on DioException catch (e) {
      yield _handleDioErrorStream(e, payload.apiConfig.apiType.name);
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
               .expand((candidate) => (candidate['content']?['parts'] as List? ?? []))
               .map((part) => part['inlineData']?['data'] as String?)
               .whereType<String>()
               .toList();
            final text = candidates
               .expand((candidate) => (candidate['content']?['parts'] as List? ?? []))
               .map((part) => part['text'] as String?)
               .whereType<String>().join();
           if (images.isNotEmpty || text.isNotEmpty) {
              return LlmImageResponse(base64Images: images, text: text, isSuccess: true);
           }
         }

        return const LlmImageResponse.error("Image response format unexpected.");
      } else {
         return LlmImageResponse.error("API Error: ${response.statusCode} ${response.statusMessage}");
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
          throw Exception("Count tokens response format unexpected: 'totalTokens' field is missing or not an int.");
        }
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          message: "API Error: ${response.statusCode} ${response.statusMessage}",
        );
      }
    } on DioException catch (e) {
      // Re-throw to be handled by the caller, which will then fallback to local calculation.
      debugPrint(_formatDioError(e, payload.apiConfig.apiType.name));
      rethrow;
    } catch (e) {
      debugPrint("Unexpected error in executeCountTokens: $e");
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

    await for (var chunk in stream) {
      final rawChunk = carryOverBuffer + utf8.decode(chunk, allowMalformed: true);
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
              final jsonMap = jsonDecode(jsonData);
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
            } catch (e) {
              debugPrint("Error parsing SSE chunk JSON: $jsonData. Error: $e");
            }
          }
        }
      }
    }
    yield LlmStreamChunk(
      textChunk: '',
      accumulatedText: accumulatedResponse,
      isFinished: true,
      timestamp: DateTime.now(),
    );
  }

  LlmResponse _handleDioErrorResponse(DioException e, String serviceName) {
    if (CancelToken.isCancel(e)) {
      return const LlmResponse.error("Request cancelled by user.");
    }
    final errorMessage = _formatDioError(e, serviceName);
    debugPrint(errorMessage);
    return LlmResponse.error(errorMessage);
  }

  LlmStreamChunk _handleDioErrorStream(DioException e, String serviceName) {
    if (CancelToken.isCancel(e)) {
      return LlmStreamChunk.error("Request cancelled by user.", '');
    }
    final errorMessage = _formatDioError(e, serviceName);
    debugPrint(errorMessage);
    return LlmStreamChunk.error(errorMessage, '');
  }

  LlmImageResponse _handleDioErrorImage(DioException e, String serviceName) {
    if (CancelToken.isCancel(e)) {
      return const LlmImageResponse.error("Request cancelled by user.");
    }
    final errorMessage = _formatDioError(e, serviceName);
    debugPrint(errorMessage);
    return LlmImageResponse.error(errorMessage);
  }

  String _formatDioError(DioException e, String serviceName) {
    String errorMsg = "$serviceName API DioException: ${e.message}";
    if (e.response != null) {
      errorMsg += "\nStatus: ${e.response?.statusCode} - ${e.response?.statusMessage}";
      try {
        final errorBody = jsonEncode(e.response?.data);
        errorMsg += "\nBody: $errorBody";
      } catch (_) {
        errorMsg += "\nBody: (Could not parse error body)";
      }
    }
    return errorMsg;
  }

  LlmResponse _handleGeneralErrorResponse(Object e, String serviceName) {
    final errorMsg = "Unexpected $serviceName Error: $e";
    debugPrint(errorMsg);
    return LlmResponse.error(errorMsg);
  }

  LlmStreamChunk _handleGeneralErrorStream(Object e, String serviceName) {
    final errorMsg = "Unexpected $serviceName Error: $e";
    debugPrint(errorMsg);
    return LlmStreamChunk.error(errorMsg, '');
  }

  LlmImageResponse _handleGeneralErrorImage(Object e, String serviceName) {
    final errorMsg = "Unexpected $serviceName Error: $e";
    debugPrint(errorMsg);
    return LlmImageResponse.error(errorMsg);
  }
}
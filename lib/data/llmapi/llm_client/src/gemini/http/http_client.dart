// lib/src/gemini/http/http_client.dart
import 'package:dio/dio.dart';
import '../gemini_exception.dart';

/// Handles standard RESTful HTTP requests for the Gemini API.
class HttpClient {
  final String apiKey;
  final Dio _dio;
  final String baseUrl;

  HttpClient({required this.apiKey, required this.baseUrl, Dio? dio}) : _dio = dio ?? Dio();

  String buildUrl(String path, String apiVersion,
      [Map<String, dynamic>? queryParameters]) {
    // For custom actions, the path is structured like "models/aqa:generateAnswer".
    // The default concatenation is correct, so we just build the URL.
    final url = '$baseUrl/$apiVersion/$path';
    var uri = Uri.parse(url);
    if (queryParameters != null) {
      uri = uri.replace(queryParameters: queryParameters);
    }
    return uri.toString();
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body,
      {Map<String, dynamic>? queryParameters,
      String apiVersion = 'v1beta'}) async {
    final url = buildUrl(path, apiVersion, queryParameters);
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        url,
        data: body,
        options: Options(
          headers: {
            'x-goog-api-key': apiKey,
            'Content-Type': 'application/json',
          },
        ),
      );
      return response.data!;
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> get(String path,
      {Map<String, dynamic>? queryParameters,
      String apiVersion = 'v1beta'}) async {
    final url = buildUrl(path, apiVersion, queryParameters);
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        url,
        options: Options(
          headers: {
            'x-goog-api-key': apiKey,
            'Content-Type': 'application/json',
          },
        ),
      );
      return response.data!;
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  Future<void> delete(String path,
      {Map<String, dynamic>? queryParameters,
      String apiVersion = 'v1beta'}) async {
    final url = buildUrl(path, apiVersion, queryParameters);
    try {
      await _dio.delete<void>(
        url,
        options: Options(
          headers: {
            'x-goog-api-key': apiKey,
            'Content-Type': 'application/json',
          },
        ),
      );
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body,
      {Map<String, dynamic>? queryParameters,
      String apiVersion = 'v1beta'}) async {
    final url = buildUrl(path, apiVersion, queryParameters);
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        url,
        data: body,
        options: Options(
          headers: {
            'x-goog-api-key': apiKey,
            'Content-Type': 'application/json',
          },
        ),
      );
      return response.data!;
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  Future<List<int>> download(String url) async {
    try {
      // The download URI from the File object is a full URL and should be used directly.
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data!;
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  /// Public error handler to be shared across clients.
  Exception handleDioError(DioException e) {
    final response = e.response;
    if (response != null && response.data is Map<String, dynamic>) {
      final errorData = response.data['error'] as Map<String, dynamic>?;
      if (errorData != null) {
        return GeminiApiException(
          statusCode: response.statusCode,
          statusMessage: response.statusMessage,
          code: errorData['code']?.toString(),
          message: errorData['message'],
          status: errorData['status'],
          originalException: e,
        );
      }
      return GeminiApiException(
        statusCode: response.statusCode,
        statusMessage: response.statusMessage,
        message: response.data.toString(),
        originalException: e,
      );
    } else if (response != null) {
      return GeminiApiException(
        statusCode: response.statusCode,
        statusMessage: response.statusMessage,
        message: 'Non-JSON error response: ${response.data}',
        originalException: e,
      );
    } else {
      return GeminiApiException(
        message: 'Error sending request to Gemini API: ${e.message}',
        originalException: e,
      );
    }
  }
}
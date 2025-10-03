// lib/src/gemini/http/stream_client.dart
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'http_client.dart';

/// Handles Server-Sent Events (SSE) stream requests for the Gemini API.
class StreamClient {
  final Dio _dio;
  final HttpClient _httpClient;

  StreamClient({required Dio dio, required HttpClient httpClient})
      : _dio = dio,
        _httpClient = httpClient;

  Stream<Map<String, dynamic>> stream(
      String path, Map<String, dynamic> body) async* {
    final url = _httpClient.buildUrl(path, 'v1beta', {'alt': 'sse'});
    try {
      final response = await _dio.post<ResponseBody>(
        url,
        data: body,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'x-goog-api-key': _httpClient.apiKey,
            'Content-Type': 'application/json',
          },
        ),
      );

      yield* response.data!.stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .where((line) => line.startsWith('data: '))
          .map((line) => line.substring('data: '.length))
          .map((jsonString) => jsonDecode(jsonString) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _httpClient.handleDioError(e);
    }
  }
}
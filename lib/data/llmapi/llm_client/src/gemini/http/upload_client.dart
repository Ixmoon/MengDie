// lib/src/gemini/http/upload_client.dart
import 'package:dio/dio.dart';
import 'http_client.dart';

/// Handles the two-stage resumable upload protocol for the Gemini API.
class UploadClient {
  final String apiKey;
  final Dio _dio;
  final HttpClient _httpClient;
  final String baseUrl;

  UploadClient({required this.apiKey, required Dio dio, required HttpClient httpClient, required this.baseUrl})
      : _dio = dio,
        _httpClient = httpClient;

  Future<Map<String, dynamic>> upload(
      String path, List<int> fileBytes, String mimeType,
      {String? displayName, Function(int, int)? onProgress}) async {
    try {
      // Correctly construct the special upload URL
      final startUrl =
          _httpClient.buildUrl(path, 'upload/v1beta', {'key': apiKey});

      final response = await _dio.post<Map<String, dynamic>>(
        startUrl,
        options: Options(
          headers: {
            'X-Goog-Upload-Protocol': 'resumable',
            'X-Goog-Upload-Command': 'start',
            'X-Goog-Upload-Header-Content-Length': fileBytes.length.toString(),
            'X-Goog-Upload-Header-Content-Type': mimeType,
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'file': {
            if (displayName != null) 'display_name': displayName,
          }
        },
      );

      final uploadUrl = response.headers.value('x-goog-upload-url');
      if (uploadUrl == null) {
        throw Exception('Failed to get upload URL from initial request.');
      }

      final uploadResponse = await _dio.post<Map<String, dynamic>>(
        uploadUrl,
        options: Options(
          headers: {
            'Content-Length': fileBytes.length.toString(),
            'X-Goog-Upload-Offset': '0',
            'X-Goog-Upload-Command': 'upload, finalize',
          },
        ),
        onSendProgress: onProgress,
        data: Stream.fromIterable(fileBytes.map((b) => [b])),
      );

      return uploadResponse.data!;
    } on DioException catch (e) {
      throw _httpClient.handleDioError(e);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('An unexpected error occurred during upload: $e');
    }
  }
}
// lib/src/openai/services/audio.dart


// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'package:dio/dio.dart';

/// 处理所有与 OpenAI 音频相关的 API 调用 (Speech, Transcriptions)。
class CustomOpenAIAudioService {
  final Dio _dio;
  final String _apiKey;
  final String _baseUrl;

  CustomOpenAIAudioService({required Dio dio, required String apiKey, required String baseUrl})
      : _dio = dio,
        _apiKey = apiKey,
        _baseUrl = baseUrl;

  /// 将文本转换为语音。
  Future<dynamic> speech({
    required String model,
    required String input,
    required String voice,
  }) async {
    final url = '$_baseUrl/audio/speech';
    final headers = {
      'Authorization': 'Bearer $_apiKey',
      'Content-Type': 'application/json',
    };
    final body = {
      'model': model,
      'input': input,
      'voice': voice,
    };

    try {
      // The response is binary audio data, so we expect a ResponseBody
      final response = await _dio.post(
        url,
        data: body,
        options: Options(headers: headers, responseType: ResponseType.bytes),
      );
      return response.data; // Return the raw bytes
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// 将音频转换为文本。
  Future<String> transcriptions({
    required String model,
    required List<int> file, // Audio file bytes
    required String fileName,
  }) async {
    final url = '$_baseUrl/audio/transcriptions';
    final headers = {'Authorization': 'Bearer $_apiKey'};

    final formData = FormData.fromMap({
      'model': model,
      'file': MultipartFile.fromBytes(file, filename: fileName),
    });

    try {
      final response = await _dio.post(url, data: formData, options: Options(headers: headers));
      return response.data['text'];
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Exception _handleDioError(DioException e) {
    final response = e.response;
    if (response != null) {
      return Exception(
          'OpenAI API Error: ${response.statusCode} ${response.statusMessage}\nBody: ${response.data}');
    } else {
      return Exception('Error sending request to OpenAI API: ${e.message}');
    }
  }
}
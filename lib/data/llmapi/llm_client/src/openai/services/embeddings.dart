// lib/src/openai/services/embeddings.dart


// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'package:dio/dio.dart';
import '../models.dart';

/// 处理所有与 OpenAI 嵌入相关的 API 调用。
class CustomOpenAIEmbeddingsService {
  final Dio _dio;
  final String _apiKey;
  final String _baseUrl;

  CustomOpenAIEmbeddingsService({required Dio dio, required String apiKey, required String baseUrl})
      : _dio = dio,
        _apiKey = apiKey,
        _baseUrl = baseUrl;

  /// 创建一个嵌入向量。
  Future<OpenAIEmbeddingModel> create({
    required String model,
    required dynamic input, // Can be String or List<String>
  }) async {
    final url = '$_baseUrl/embeddings';
    final headers = {
      'Authorization': 'Bearer $_apiKey',
      'Content-Type': 'application/json',
    };
    final body = {
      'model': model,
      'input': input,
    };

    try {
      final response = await _dio.post(url, data: body, options: Options(headers: headers));
      return _parseEmbeddingModel(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  OpenAIEmbeddingModel _parseEmbeddingModel(Map<String, dynamic> json) {
    return OpenAIEmbeddingModel(
      model: json['model'],
      data: (json['data'] as List)
          .map((item) => OpenAIEmbedding(
                index: item['index'],
                embedding: (item['embedding'] as List).cast<double>(),
              ))
          .toList(),
    );
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
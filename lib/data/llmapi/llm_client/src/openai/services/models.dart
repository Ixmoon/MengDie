// lib/src/openai/services/models.dart


// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'package:dio/dio.dart';
import '../models.dart';

/// 处理所有与 OpenAI 模型管理相关的 API 调用。
class CustomOpenAIModelsService {
  final Dio _dio;
  final String _apiKey;
  final String _baseUrl;

  CustomOpenAIModelsService({required Dio dio, required String apiKey, required String baseUrl})
      : _dio = dio,
        _apiKey = apiKey,
        _baseUrl = baseUrl;

  /// 列出所有可用的模型。
  Future<List<OpenAIModelInfo>> list() async {
    final url = '$_baseUrl/models';
    final headers = {'Authorization': 'Bearer $_apiKey'};

    try {
      final response = await _dio.get(url, options: Options(headers: headers));
      final data = response.data['data'] as List;
      return data.map((item) => _parseModelInfo(item)).toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// 检索指定 ID 的模型信息。
  Future<OpenAIModelInfo> retrieve(String modelId) async {
    final url = '$_baseUrl/models/$modelId';
    final headers = {'Authorization': 'Bearer $_apiKey'};

    try {
      final response = await _dio.get(url, options: Options(headers: headers));
      return _parseModelInfo(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  OpenAIModelInfo _parseModelInfo(Map<String, dynamic> json) {
    return OpenAIModelInfo(
      id: json['id'],
      created: DateTime.fromMillisecondsSinceEpoch((json['created'] as int) * 1000),
      ownedBy: json['owned_by'],
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
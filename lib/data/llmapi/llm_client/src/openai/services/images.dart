// lib/src/openai/services/images.dart


// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:dio/dio.dart';
import '../models.dart';

/// 处理所有与 OpenAI 图像生成相关的 API 调用。
class CustomOpenAIImagesService {
  final Dio _dio;
  final String _apiKey;
  final String _baseUrl;

  CustomOpenAIImagesService({required Dio dio, required String apiKey, required String baseUrl})
      : _dio = dio,
        _apiKey = apiKey,
        _baseUrl = baseUrl;

  /// 根据文本提示创建图像。
  Future<OpenAIImageModel> create({
    required String prompt,
    String model = 'dall-e-3',
    int n = 1,
    OpenAIImageSize size = OpenAIImageSize.size1024,
    OpenAIImageResponseFormat responseFormat = OpenAIImageResponseFormat.b64Json,
  }) async {
    final url = '$_baseUrl/images/generations';
    final headers = {
      'Authorization': 'Bearer $_apiKey',
      'Content-Type': 'application/json',
    };
    final body = {
      'prompt': prompt,
      'model': model,
      'n': n,
      'size': _sizeToString(size),
      'response_format': responseFormat.name,
    };

    try {
      final response = await _dio.post(url, data: body, options: Options(headers: headers));
      return _parseImageModel(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  String _sizeToString(OpenAIImageSize size) {
    switch (size) {
      case OpenAIImageSize.size256:
        return '256x256';
      case OpenAIImageSize.size512:
        return '512x512';
      case OpenAIImageSize.size1024:
        return '1024x1024';
    }
  }

  OpenAIImageModel _parseImageModel(Map<String, dynamic> json) {
    return OpenAIImageModel(
      created: DateTime.fromMillisecondsSinceEpoch((json['created'] as int) * 1000),
      data: (json['data'] as List)
          .map((item) => OpenAIImageData(
                b64Json: item['b64_json'],
                url: item['url'],
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
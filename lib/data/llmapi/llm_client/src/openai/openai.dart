// lib/src/openai/openai.dart


// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'package:dio/dio.dart';
import 'services/audio.dart';
import 'services/chat.dart';
import 'services/embeddings.dart';
import 'services/images.dart';
import 'services/models.dart';

/// 一个模仿 `dart_openai` 库风格的 OpenAI 服务入口类。
///
/// 通过实例进行配置和访问各种服务。
class CustomOpenAI {
  /// 用于 API 验证的 API 密钥。
  final String apiKey;

  /// 用于网络请求的 Dio 实例。
  final Dio dio;

  /// API 的基础 URL。
  final String baseUrl;

  /// 创建一个 `CustomOpenAI` 实例。
  ///
  /// 需要一个 [apiKey]，并可以选择性地提供一个 [dio] 实例
  /// 和一个自定义的 [baseUrl]。
  CustomOpenAI({
    required this.apiKey,
    Dio? dio,
    this.baseUrl = 'https://api.openai.com/v1',
  }) : dio = dio ?? Dio();

  // --- 服务访问器 ---

  /// 访问聊天服务。
  CustomOpenAIChatService get chat {
    return CustomOpenAIChatService(dio: dio, apiKey: apiKey, baseUrl: baseUrl);
  }

  /// 访问图像服务。
  CustomOpenAIImagesService get images {
    return CustomOpenAIImagesService(dio: dio, apiKey: apiKey, baseUrl: baseUrl);
  }

  /// 访问音频服务。
  CustomOpenAIAudioService get audio {
    return CustomOpenAIAudioService(dio: dio, apiKey: apiKey, baseUrl: baseUrl);
  }

  /// 访问嵌入服务。
  CustomOpenAIEmbeddingsService get embeddings {
    return CustomOpenAIEmbeddingsService(dio: dio, apiKey: apiKey, baseUrl: baseUrl);
  }

  /// 访问模型服务。
  CustomOpenAIModelsService get models {
    return CustomOpenAIModelsService(dio: dio, apiKey: apiKey, baseUrl: baseUrl);
  }
}
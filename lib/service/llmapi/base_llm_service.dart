// 本文件定义了所有具体 LLM 服务 (如 Gemini, OpenAI) 必须实现的抽象基类 `BaseLlmService`。
// 通过定义一个统一的接口，我们确保了上层服务 (如 LlmService) 可以依赖于此抽象，
// 而非具体的实现，从而降低耦合度，并使得添加新的 LLM 服务变得更加容易。

import 'dart:async';

import '../../data/models/api_config.dart';
import 'llm_models.dart';

/// 所有 LLM 服务的抽象基类。
///
/// 它定义了与任何大型语言模型交互所需的核心方法，
/// 强制所有具体的服务实现都遵循统一的契约。
abstract class BaseLlmService {
  /// 发送一系列消息并以流的形式接收响应。
  ///
  /// [llmContext]: 发送给模型的上下文信息列表。
  /// [apiConfig]: 包含模型名称、API密钥等信息的配置。
  /// [generationParams]: 包含如 temperature, topP 等生成参数的映射。
  ///
  /// 返回一个 `LlmStreamChunk` 的流，每个块代表响应的一部分。
  Stream<LlmStreamChunk> sendMessageStream({
    required List<LlmContent> llmContext,
    required ApiConfig apiConfig,
    required Map<String, dynamic> generationParams,
  });

  /// 发送一系列消息并一次性获取完整的响应。
  ///
  /// [llmContext]: 发送给模型的上下文信息列表。
  /// [apiConfig]: 包含模型名称、API密钥等信息的配置。
  /// [generationParams]: 包含如 temperature, topP 等生成参数的映射。
  ///
  /// 返回一个包含完整响应的 `LlmResponse`。
  Future<LlmResponse> sendMessageOnce({
    required List<LlmContent> llmContext,
    required ApiConfig apiConfig,
    required Map<String, dynamic> generationParams,
  });

  /// 使用客户端分词器计算给定上下文的 token 数量。
  ///
  /// 这是一个纯本地操作，用于估算 token，以便进行精确的上下文管理。
  ///
  /// [llmContext]: 需要计算 token 的上下文列表。
  /// [apiConfig]: API 配置，主要用于获取模型名称以选择正确的分词器。
  ///
  /// 如果计算失败（例如，模型名称无效），将抛出异常。
  Future<int> countTokens({
    required List<LlmContent> llmContext,
    required ApiConfig apiConfig,
    bool useRemoteCounter = false,
  });

  /// 取消当前正在进行的 API 请求。
  ///
  /// 这个方法应该能够中断正在进行的流式或一次性请求。
  Future<void> cancelRequest();

  /// 根据文本提示生成图片。
  ///
  /// [prompt]: 用于生成图片的文本描述。
  /// [apiConfig]: 包含模型名称、API密钥等信息的配置。
  /// [n]: 要生成的图片数量。
  ///
  /// 返回一个包含 base64 编码图片列表的 `LlmImageResponse`。
  Future<LlmImageResponse> generateImage({
    required String prompt,
    required ApiConfig apiConfig,
    int n = 1,
  });
}
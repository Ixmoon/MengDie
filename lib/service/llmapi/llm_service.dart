// 本文件包含 LlmService 类，它作为一个统一的门面 (Facade)，用于与各种大型语言模型 (LLM) API 进行交互。
// 它抽象了底层具体 LLM 服务 (如 Gemini, OpenAI) 的实现细节，为上层业务逻辑提供一个稳定、一致的接口。

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

// 导入本地模型、服务和新的抽象数据模型
import '../../data/models/models.dart';
import 'gemini_service.dart';
import 'openai_service.dart';
import 'llm_models.dart'; // 新增：导入通用数据模型
import 'base_llm_service.dart';


// --- LLM Service Provider ---
final llmServiceProvider = Provider<LlmService>((ref) {
  // LlmService now depends on the specific service providers
  final geminiService = ref.watch(geminiServiceProvider);
  final openAIService = ref.watch(openaiServiceProvider);

  // Create a map of available services, keyed by their LlmType.
  final Map<LlmType, BaseLlmService> services = {
    LlmType.gemini: geminiService,
    LlmType.openai: openAIService,
  };

  return LlmService(ref, services);
});


// --- LLM Service Implementation ---
// This service acts as a facade, providing a generic interface
// for interacting with different LLMs.

class LlmService {
  // ignore: unused_field
  final Ref _ref;
  final Map<LlmType, BaseLlmService> _services;

  // --- Cancellation State ---
  LlmType? _activeServiceType;

  LlmService(this._ref, this._services);
  /// 【私有方法】根据传入的 ApiConfig 对象准备生成参数。
  /// 这个方法现在是纯粹的功能性辅助方法，不再包含任何配置解析逻辑。
  Map<String, dynamic> _prepareGenerationParams(ApiConfig apiConfig) {
    return {
      if (apiConfig.useCustomTemperature && apiConfig.temperature != null) 'temperature': apiConfig.temperature,
      if (apiConfig.useCustomTopP && apiConfig.topP != null) 'topP': apiConfig.topP,
      if (apiConfig.useCustomTopK && apiConfig.topK != null) 'topK': apiConfig.topK,
      if (apiConfig.maxOutputTokens != null) 'maxOutputTokens': apiConfig.maxOutputTokens,
      if (apiConfig.stopSequences != null && apiConfig.stopSequences!.isNotEmpty) 'stopSequences': apiConfig.stopSequences,
      // OpenAI specific settings
      if (apiConfig.apiType == LlmType.openai &&
          (apiConfig.enableReasoningEffort ?? false) &&
          apiConfig.reasoningEffort != null) ...{
        'reasoning_effort': apiConfig.reasoningEffort!.toApiValue,
      },
    };
  }

  /// 发送消息并获取流式响应。
  /// 【重构】此方法不再解析配置，而是直接接收一个确定的 `ApiConfig` 对象。
  Stream<LlmStreamChunk> sendMessageStream({
    required List<LlmContent> llmContext,
    required ApiConfig apiConfig, // 直接接收配置对象
  }) {
    final generationParams = _prepareGenerationParams(apiConfig);

    _activeServiceType = apiConfig.apiType;
    debugPrint("LlmService: Set active service to $_activeServiceType for potential cancellation.");

    final service = _services[apiConfig.apiType];
    if (service == null) {
      return Stream.value(LlmStreamChunk.error("Unsupported API type: ${apiConfig.apiType}", ''));
    }

    try {
      return service.sendMessageStream(
        llmContext: llmContext,
        apiConfig: apiConfig,
        generationParams: generationParams,
      );
    } catch (e) {
      debugPrint("Error setting up ${apiConfig.apiType} stream: $e");
      return Stream.value(LlmStreamChunk.error("Failed to start ${apiConfig.apiType} stream: $e", ''));
    }
  }

  /// 发送消息并获取一次性完整响应。
  /// 【重构】此方法不再解析配置，而是直接接收一个确定的 `ApiConfig` 对象。
  Future<LlmResponse> sendMessageOnce({
    required List<LlmContent> llmContext,
    required ApiConfig apiConfig, // 直接接收配置对象
  }) async {
    final generationParams = _prepareGenerationParams(apiConfig);

    _activeServiceType = apiConfig.apiType;
    debugPrint("LlmService: Set active service to $_activeServiceType for potential cancellation.");

    final service = _services[apiConfig.apiType];
    if (service == null) {
      return LlmResponse.error("Unsupported API type: ${apiConfig.apiType}");
    }

    try {
      return await service.sendMessageOnce(
        llmContext: llmContext,
        apiConfig: apiConfig,
        generationParams: generationParams,
      );
    } catch (e) {
      debugPrint("Error during ${apiConfig.apiType} sendMessageOnce: $e");
      return LlmResponse.error("${apiConfig.apiType} API Error: $e");
    }
  }

  /// Counts tokens for a given context using the appropriate local tokenizer.
  /// This method is now a direct pass-through and will throw an exception
  /// if the underlying service fails (e.g., model not found in tokenizer).
  /// 为给定的上下文计算 token 数量。
  /// 【重构】此方法不再解析配置，而是直接接收一个确定的 `ApiConfig` 对象。
  Future<int> countTokens({
    required List<LlmContent> llmContext,
    required ApiConfig apiConfig, // 直接接收配置对象
  }) async {

    final service = _services[apiConfig.apiType];
    if (service == null) {
      throw Exception("LlmService.countTokens Error: Unsupported API type: ${apiConfig.apiType}");
    }
    return await service.countTokens(llmContext: llmContext, apiConfig: apiConfig);
  }

  // --- Placeholder for future methods ---
  // Future<List<String>> listAvailableModels(LlmType type, {OpenAIAPIConfig? openAIConfig}) async { ... }
  /// Cancels the ongoing request on the currently active service.
  Future<void> cancelActiveRequest() async {
    debugPrint("LlmService: Received cancellation request for active service: $_activeServiceType");
    if (_activeServiceType == null) {
      debugPrint("LlmService: Cancellation request ignored, no active service.");
      return;
    }

    if (_activeServiceType == null) {
      debugPrint("LlmService: Cancellation request ignored, no active service.");
      return;
    }

    final service = _services[_activeServiceType];
    if (service != null) {
      await service.cancelRequest();
    }
    // Reset the active service type after cancellation to prevent dangling state
    _activeServiceType = null;
    debugPrint("LlmService: Active service has been cancelled and reset.");
  }
}

// REMOVED Enum for LLM Types as it's defined in models/enums.dart

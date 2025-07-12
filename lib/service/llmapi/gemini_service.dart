import 'dart:async'; // For Stream
import 'dart:convert'; // For base64Decode
import 'package:flutter/foundation.dart'; // for immutable, debugPrint
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as genai;
import 'package:flutter/material.dart'; // Added for debugPrint, consider removing if not needed elsewhere
import 'package:tiktoken/tiktoken.dart' as tiktoken; // Import tiktoken for fallback

// Import local models, providers, services, and the NEW generic LLM types
import '../../data/models/models.dart';
import 'llm_models.dart'; // Import LlmContent, LlmPart, LlmTextPart
import '../../ui/providers/api_key_provider.dart';
import 'base_llm_service.dart'; // 导入抽象基类

// 本文件包含 GeminiService 类，该类封装了与 Google Gemini API 交互的所有逻辑。
// 它实现了 BaseLlmService 接口，提供了一个标准化的方式来发送消息、计算 token 和取消请求。

// --- Gemini Service Provider ---
// 提供 GeminiService 实例的 Provider。
final geminiServiceProvider = Provider<GeminiService>((ref) {
  // 依赖注入：通过 Riverpod 获取其他 Provider 的实例
  final apiKeyNotifier = ref.watch(apiKeyNotifierProvider.notifier); // 获取 Notifier 用于调用方法
    // Pass ref for reading ChatRepository
    return GeminiService(apiKeyNotifier, ref);
});

// --- Gemini Service Implementation ---
// 封装与 Gemini API 交互的逻辑。
class GeminiService implements BaseLlmService {
   final ApiKeyNotifier _apiKeyNotifier; // 用于管理和获取 API Key
   // ignore: unused_field
   final Ref _ref; // Riverpod Ref，用于读取其他 Provider

  // --- Cancellation ---
  bool _isCancelled = false;

   GeminiService(this._apiKeyNotifier, this._ref);


   // --- Private Helper for Context Conversion ---
   /// Converts LlmContent list to a Gemini-specific Content object for system instructions
   /// and a list of Content objects for chat history.
   ({genai.Content? systemInstructionAsContent, List<genai.Content> chatHistory}) _buildApiContextFromLlm(List<LlmContent> llmContext) {
     genai.Content? systemInstructionAsContent;
     List<genai.Content> chatHistory = [];

     try {
       for (var c in llmContext) {
         String textContent = "";
         if (c.parts.isNotEmpty && c.parts.first is LlmTextPart) {
           textContent = (c.parts.first as LlmTextPart).text;
         } else if (c.parts.isNotEmpty) {
           debugPrint("Warning: LlmContent.parts for role '${c.role}' is empty or first part is not LlmTextPart for Gemini.");
         }

         if (c.role == "system") {
           if (textContent.isNotEmpty) {
             if (systemInstructionAsContent != null) {
               debugPrint("Warning: Multiple system prompts found. Using the last one for systemInstruction parameter.");
             }
             // Use genai.Content.system() which we know is valid for constructing system messages
             systemInstructionAsContent = genai.Content.system(textContent);
           } else {
             debugPrint("Warning: Empty system prompt text for Gemini, skipping system instruction.");
           }
         } else if (c.role == "user" || c.role == "model") {
           final genaiParts = c.parts.map((part) {
             if (part is LlmTextPart) {
               return genai.TextPart(part.text);
             } else if (part is LlmDataPart) {
               // Decode the base64 string to bytes
               return genai.DataPart(part.mimeType, base64Decode(part.base64Data));
             }
             else {
               throw UnimplementedError('Conversion for LlmPart type ${part.runtimeType} to genai.Part not implemented.');
             }
           }).toList();
           // Ensure parts are not empty before creating content, though API might handle it.
           if (genaiParts.isNotEmpty) {
            chatHistory.add(genai.Content(c.role, genaiParts));
           } else {
            debugPrint("Warning: No convertible parts found for LlmContent with role '${c.role}'. Skipping this Content.");
           }
         } else {
           // Handle unknown roles if necessary, or log
           debugPrint("Warning: Unknown role '${c.role}' encountered in LlmContent. Skipping this Content.");
         }
       }
       return (systemInstructionAsContent: systemInstructionAsContent, chatHistory: chatHistory);
     } catch (e) {
       debugPrint("Error converting LlmContent to API context within GeminiService: $e");
       rethrow;
     }
   }

   /// 使用客户端库 (tiktoken) 估算给定上下文的 Token 数量。
   /// 这是一个纯本地的、高性能的异步操作，旨在为所有模型提供一个统一的估算标准。
   /// 注意: Gemini 有其专有的分词器，使用 tiktoken 会产生估算偏差，但这对于上下文管理已足够。
   /// 如果计算失败，它将抛出异常。
   @override
   Future<int> countTokens({
     required List<LlmContent> llmContext,
     required ApiConfig apiConfig,
   }) async {
    // 我们使用 'cl100k_base' 作为通用的编码器，为所有模型提供一致的估算。
    final encoding = tiktoken.getEncoding('cl100k_base');
    int totalTokens = 0;
    for (final message in llmContext) {
      final textContent = message.parts
          .whereType<LlmTextPart>()
          .map((part) => part.text)
          .join("\n");
      if (textContent.isNotEmpty) {
        totalTokens += encoding.encode(textContent).length;
      }
    }
    return totalTokens;
   }


   // 发送消息并获取响应流 (Now accepts generic LlmContent and generationParams Map)
   @override
   Stream<LlmStreamChunk> sendMessageStream({
     required List<LlmContent> llmContext,
     required ApiConfig apiConfig,
     required Map<String, dynamic> generationParams,
   }) async* {
    _isCancelled = false;
     const int maxRetries = 3;
     int retryCount = 0;
     String? lastError;

     final (:systemInstructionAsContent, :chatHistory) = _buildApiContextFromLlm(llmContext);

     while (retryCount <= maxRetries) {
       debugPrint("sendMessageStream (尝试 ${retryCount + 1}/${maxRetries + 1}) 开始...");
       final apiKey = _apiKeyNotifier.getNextGeminiApiKey();
       if (apiKey == null || apiKey.isEmpty) {
         debugPrint("sendMessageStream 错误：没有可用的 Gemini API Key。");
         yield LlmStreamChunk.error("没有可用的 Gemini API Key。", '');
         return;
       }

       genai.GenerativeModel? model;
       try {
         final apiGenerationConfig = _createApiGenerationConfig(generationParams);
         final apiSafetySettings = _defaultSafetySettings();

         model = genai.GenerativeModel(
           model: apiConfig.model,
           apiKey: apiKey,
           generationConfig: apiGenerationConfig,
           safetySettings: apiSafetySettings,
           systemInstruction: systemInstructionAsContent,
         );
         debugPrint("sendMessageStream: Gemini 模型已初始化 (模型: ${apiConfig.model}, Key: ${apiKey.substring(0, 4)}...)。");
       } catch (e) {
         debugPrint("sendMessageStream 错误：初始化 Gemini 模型失败: $e");
         yield LlmStreamChunk.error("初始化 Gemini 模型失败: $e", '');
         return;
       }

       // 3. 生成内容流
       String accumulatedResponse = '';
       try {
         // Ensure model is not null before proceeding (it's initialized in the try-catch above)



         final stream = model.generateContentStream(chatHistory); // Use chatHistory here
         debugPrint("sendMessageStream: 开始接收 API 响应流...");
         await for (final response in stream) {
          if (_isCancelled) {
            debugPrint("Gemini stream processing halted due to cancellation flag.");
            return; // Exit the loop and the method
          }
           final textChunk = response.text ?? '';
           accumulatedResponse += textChunk;
           // 发出一个包含当前块文本和累积文本的 chunk
           yield LlmStreamChunk(
             textChunk: textChunk,
             accumulatedText: accumulatedResponse,
             timestamp: DateTime.now(), // 记录块时间戳
             isFinished: false,
           );
         }
         debugPrint("sendMessageStream: API 响应流接收完毕。总长度: ${accumulatedResponse.length}");
         if (_isCancelled) {
           debugPrint("Gemini stream finished, but request was cancelled. Discarding results.");
           return;
         }

         // REMOVED: Database saving logic from service layer.
         // This is now handled by ChatStateNotifier.

         debugPrint("sendMessageStream: 发出最终 chunk。");
         yield LlmStreamChunk(
           textChunk: '',
           accumulatedText: accumulatedResponse, // Return the full raw text
           timestamp: DateTime.now(),
           isFinished: true,
         );

         // --- 成功！退出重试循环 ---
         debugPrint("sendMessageStream (尝试 ${retryCount + 1}) 成功完成。");
         return;

       } on genai.GenerativeAIException catch (e) { // 处理 API 特定错误
         debugPrint("sendMessageStream (尝试 ${retryCount + 1}) 失败。Gemini API 错误: ${e.message}");
         // _apiKeyNotifier.reportKeyError(apiKey); // This logic is removed
         lastError = "API 错误: ${e.message}"; // 记录错误

         // --- BEGIN MODIFICATION ---
         // 尝试保存部分内容 (不在此处处理XML)
         if (accumulatedResponse.isNotEmpty) {
           debugPrint("sendMessageStream: API 错误发生，不再从此保存部分内容。");
           // REMOVED: Partial saving logic. This is now handled by the unified
           // finalization logic in ChatStateNotifier.
         }
         // --- END MODIFICATION ---

         retryCount++; // 增加重试计数

         if (retryCount > maxRetries) {
           // 达到最大重试次数，发出最终错误
           debugPrint("sendMessageStream 错误：达到最大重试次数。");
           yield LlmStreamChunk.error("API 错误 (重试 $maxRetries 次后): $lastError", accumulatedResponse);
           return; // 退出
         }
         // 否则，循环将继续，尝试下一个 Key

       } catch (e, stacktrace) { // 处理此尝试期间的意外错误
         debugPrint("sendMessageStream (尝试 ${retryCount + 1}) 发生通用错误: $e\n$stacktrace");

         // --- BEGIN MODIFICATION ---
         // 尝试保存部分内容 (不在此处处理XML)
         if (accumulatedResponse.isNotEmpty) {
           debugPrint("sendMessageStream: 通用错误发生，不再从此保存部分内容。");
           // REMOVED: Partial saving logic. This is now handled by the unified
           // finalization logic in ChatStateNotifier.
         }
         // --- END MODIFICATION ---

         // 对于非 API 错误，通常不重试，直接发出错误并退出
         yield LlmStreamChunk.error("发生意外错误: $e", accumulatedResponse);
         return; // 退出循环
       }
    } // 结束 while 循环
   }

   // 发送消息并获取单个完整响应 (Now accepts generic LlmContent and generationParams Map)
   @override
   Future<LlmResponse> sendMessageOnce({
     required List<LlmContent> llmContext,
     required ApiConfig apiConfig,
     required Map<String, dynamic> generationParams,
   }) async {
    _isCancelled = false;
     const int maxRetries = 3;
     int retryCount = 0;
     String? lastError;

     final (:systemInstructionAsContent, :chatHistory) = _buildApiContextFromLlm(llmContext);

     while (retryCount <= maxRetries) {
       debugPrint("sendMessageOnce (尝试 ${retryCount + 1}/${maxRetries + 1}) 开始...");
       final apiKey = _apiKeyNotifier.getNextGeminiApiKey();
       if (apiKey == null || apiKey.isEmpty) {
         debugPrint("sendMessageOnce 错误：没有可用的 Gemini API Key。");
         return const LlmResponse.error("没有可用的 Gemini API Key。");
       }

       genai.GenerativeModel? model;
       try {
         final apiGenerationConfig = _createApiGenerationConfig(generationParams);
         final apiSafetySettings = _defaultSafetySettings();

         model = genai.GenerativeModel(
           model: apiConfig.model,
           apiKey: apiKey,
           generationConfig: apiGenerationConfig,
           safetySettings: apiSafetySettings,
           systemInstruction: systemInstructionAsContent,
         );
         debugPrint("sendMessageOnce: Gemini 模型已初始化。");
       } catch (e) {
         debugPrint("sendMessageOnce 错误：初始化 Gemini 模型失败: $e");
         return LlmResponse.error("初始化 Gemini 模型失败: $e");
       }

       // 3. 生成内容 (单次调用)
       try {
         debugPrint("sendMessageOnce: 开始调用 generateContent API...");
         final response = await model.generateContent(chatHistory); // Use chatHistory here
         final rawResponseText = response.text ?? '';
         debugPrint("sendMessageOnce: API 调用成功。响应长度: ${rawResponseText.length}");
         if (_isCancelled) {
           debugPrint("Gemini single request finished, but was cancelled. Discarding results.");
           return const LlmResponse.error("Request cancelled by user.");
         }

         // REMOVED: Database saving logic from service layer.
         // This is now handled by ChatStateNotifier.

         final successResponse = LlmResponse(
           parts: [MessagePart.text(rawResponseText)],
           isSuccess: true,
         );
         debugPrint("sendMessageOnce (尝试 ${retryCount + 1}) 成功完成。");
         return successResponse; // 返回成功结果

       } on genai.GenerativeAIException catch (e) { // 处理 API 特定错误
         debugPrint("sendMessageOnce (尝试 ${retryCount + 1}) 失败。Gemini API 错误: ${e.message}");
         // _apiKeyNotifier.reportKeyError(apiKey); // This logic is removed
         lastError = "API 错误: ${e.message}";
         retryCount++;

         if (retryCount > maxRetries) {
           debugPrint("sendMessageOnce 错误：达到最大重试次数。");
           return LlmResponse.error("API 错误 (重试 $maxRetries 次后): ${e.message}");
         }
         // 继续循环

       } catch (e, stacktrace) { // 处理意外错误
         debugPrint("sendMessageOnce (尝试 ${retryCount + 1}) 发生通用错误: $e\n$stacktrace");
         return LlmResponse.error("发生意外错误: $e"); // 直接返回错误
       }
    } // 结束 while 循环

     // 理论上不应到达此处，作为回退返回最后记录的错误
     debugPrint("sendMessageOnce 错误：重试后仍失败。");
     return LlmResponse.error(lastError ?? "重试后未能获取响应。");
   }


     // Create genai.GenerationConfig for API calls (remains private)
     // Now takes a Map<String, dynamic> as input
     genai.GenerationConfig _createApiGenerationConfig(Map<String, dynamic> generationParams) {
      // The genai.GenerationConfig's @JsonSerializable(includeIfNull: false)
      // will handle omitting keys from the JSON payload if their values are null.
      return genai.GenerationConfig(
        temperature: generationParams['temperature'] as double?,
        topP: generationParams['topP'] as double?,
        topK: generationParams['topK'] as int?,
        maxOutputTokens: generationParams['maxOutputTokens'] as int?,
        // Ensure stopSequences is List<String> or null, then handle empty case
        stopSequences: (generationParams['stopSequences'] as List<String>?)?.isNotEmpty ?? false
            ? (generationParams['stopSequences'] as List<String>)
            : [], // Pass empty list if null or empty, genai.GenerationConfig might expect non-null
      );
    }

  // --- Private Safety Setting Mapping Helpers ---
  // These now take drift_enums directly

  
// Helper to create default safety settings
List<genai.SafetySetting> _defaultSafetySettings() {
  return [
    genai.SafetySetting(genai.HarmCategory.harassment, genai.HarmBlockThreshold.none),
    genai.SafetySetting(genai.HarmCategory.hateSpeech, genai.HarmBlockThreshold.none),
    genai.SafetySetting(genai.HarmCategory.sexuallyExplicit, genai.HarmBlockThreshold.none),
    genai.SafetySetting(genai.HarmCategory.dangerousContent, genai.HarmBlockThreshold.none),
  ];
}

@override
Future<void> cancelRequest() async {
  debugPrint("GeminiService: Setting cancellation flag.");
  _isCancelled = true;
}
}

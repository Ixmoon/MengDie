import 'dart:async'; // For Stream
import 'dart:convert'; // For base64Decode
import 'package:flutter/foundation.dart'; // for immutable, debugPrint
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as genai;
import 'package:flutter/material.dart'; // Added for debugPrint, consider removing if not needed elsewhere
import 'package:tiktoken/tiktoken.dart' as tiktoken; // Import tiktoken for fallback

// Import local models, providers, services, and the NEW generic LLM types
import '../../data/database/app_database.dart'; // For ApiConfig
import 'llm_service.dart'; // Import LlmContent, LlmPart, LlmTextPart
import '../../data/providers/api_key_provider.dart';

// 本文件包含与 Google Gemini API 交互的服务类和相关数据结构。

// --- Gemini API 响应结果类 (单次调用) ---
@immutable
class GeminiResponse {
  final String rawText; // API 返回的原始文本
  final bool isSuccess; // 调用是否成功
  final String? error; // 如果调用失败，包含错误信息

  const GeminiResponse({
    required this.rawText,
    this.isSuccess = true,
    this.error,
  });

  // 用于创建错误响应的工厂构造函数
  const GeminiResponse.error(String message) :
    rawText = '',
    isSuccess = false,
    error = message;
}

// --- Gemini API 流式响应块数据类 ---
@immutable
class GeminiStreamChunk {
  final String textChunk; // 当前块接收到的文本片段
  final String accumulatedText; // 到目前为止在此流中接收到的所有原始文本
  final bool isFinished; // 是否是流的最后一个块
  final String? error; // 如果流处理中遇到错误，包含错误信息
  final DateTime timestamp; // 块生成的时间戳

  const GeminiStreamChunk({
    required this.textChunk,
    required this.accumulatedText,
    required this.timestamp,
    this.isFinished = false,
    this.error,
  });

  // 用于创建错误块的工厂构造函数，自动设置时间戳
  factory GeminiStreamChunk.error(String message, String accumulatedText) {
    return GeminiStreamChunk(
      textChunk: '',
      accumulatedText: accumulatedText,
      error: message,
      isFinished: true, // 错误也表示流结束
      timestamp: DateTime.now(), // 错误发生的时间戳
    );
  }
}

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
class GeminiService {
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

   // 计算给定上下文的 Token 数量 (Now accepts generic LlmContent)
   Future<int> countTokens({
     required List<LlmContent> llmContext,
     required ApiConfig apiConfig,
   }) async {
     final apiKey = apiConfig.apiKey;
     if (apiKey == null || apiKey.isEmpty) {
       throw Exception("Gemini API key is missing in the provided ApiConfig.");
     }
     try {
       // Convert generic context to API-specific context
       final (:systemInstructionAsContent, :chatHistory) = _buildApiContextFromLlm(llmContext); // Destructure here

       // Initialize model with provided name, key, and systemInstruction
       final model = genai.GenerativeModel(
         model: apiConfig.model,
         apiKey: apiKey,
         systemInstruction: systemInstructionAsContent, // Pass systemInstructionAsContent here
       );

       // Call SDK's countTokens method with the chatHistory and a 3-second timeout
       final response = await model.countTokens(chatHistory).timeout(const Duration(seconds: 3));
       debugPrint("countTokens 成功：总计 ${response.totalTokens} Tokens。");
       return response.totalTokens;
     } catch (e) {
       debugPrint("Gemini countTokens API failed: $e. Falling back to local estimation.");
       // Fallback to local token counting using tiktoken
       try {
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
         debugPrint("Fallback token count successful: $totalTokens");
         return totalTokens;
       } catch (localError) {
         debugPrint("Fallback token count also failed: $localError");
         return -1;
       }
     }
   }


   // 发送消息并获取响应流 (Now accepts generic LlmContent and generationParams Map)
   Stream<GeminiStreamChunk> sendMessageStream({
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
         yield GeminiStreamChunk.error("没有可用的 Gemini API Key。", '');
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
         yield GeminiStreamChunk.error("初始化 Gemini 模型失败: $e", '');
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
           yield GeminiStreamChunk(
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
         yield GeminiStreamChunk(
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
           yield GeminiStreamChunk.error("API 错误 (重试 $maxRetries 次后): $lastError", accumulatedResponse);
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
         yield GeminiStreamChunk.error("发生意外错误: $e", accumulatedResponse);
         return; // 退出循环
       }
    } // 结束 while 循环
   }

   // 发送消息并获取单个完整响应 (Now accepts generic LlmContent and generationParams Map)
   Future<GeminiResponse> sendMessageOnce({
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
         return const GeminiResponse.error("没有可用的 Gemini API Key。");
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
         return GeminiResponse.error("初始化 Gemini 模型失败: $e");
       }

       // 3. 生成内容 (单次调用)
       try {
         debugPrint("sendMessageOnce: 开始调用 generateContent API...");
         final response = await model.generateContent(chatHistory); // Use chatHistory here
         final rawResponseText = response.text ?? '';
         debugPrint("sendMessageOnce: API 调用成功。响应长度: ${rawResponseText.length}");
         if (_isCancelled) {
           debugPrint("Gemini single request finished, but was cancelled. Discarding results.");
           return const GeminiResponse.error("Request cancelled by user.");
         }

         // REMOVED: Database saving logic from service layer.
         // This is now handled by ChatStateNotifier.

         final successResponse = GeminiResponse(
           rawText: rawResponseText, // Return the full raw text
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
           return GeminiResponse.error("API 错误 (重试 $maxRetries 次后): ${e.message}");
         }
         // 继续循环

       } catch (e, stacktrace) { // 处理意外错误
         debugPrint("sendMessageOnce (尝试 ${retryCount + 1}) 发生通用错误: $e\n$stacktrace");
         return GeminiResponse.error("发生意外错误: $e"); // 直接返回错误
       }
    } // 结束 while 循环

     // 理论上不应到达此处，作为回退返回最后记录的错误
     debugPrint("sendMessageOnce 错误：重试后仍失败。");
     return GeminiResponse.error(lastError ?? "重试后未能获取响应。");
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

Future<void> cancelRequest() async {
  debugPrint("GeminiService: Setting cancellation flag.");
  _isCancelled = true;
}
}

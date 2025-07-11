import 'dart:async';
import 'dart:convert'; // For jsonEncode/Decode if needed for request body

import 'package:dio/dio.dart'; // HTTP client
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:tiktoken/tiktoken.dart' as tiktoken; // For token counting

import '../../data/models/models.dart';
import 'llm_models.dart';
import 'base_llm_service.dart'; // 导入抽象基类

// 本文件包含与 OpenAI 兼容 API 交互的服务类和相关数据结构。

// --- OpenAI Service Provider ---
final openaiServiceProvider = Provider<OpenAIService>((ref) {
  final dio = Dio(); // Create a Dio instance
  return OpenAIService(ref, dio);
});

// --- OpenAI Service Implementation ---
class OpenAIService implements BaseLlmService {
  // ignore: unused_field
  final Ref _ref;
  final Dio _dio;

  // --- Cancellation ---
  CancelToken? _cancelToken;

  OpenAIService(this._ref, this._dio);

  /// Sends messages and gets a streaming response from an OpenAI-compatible API.
  @override
  Stream<LlmStreamChunk> sendMessageStream({
    required List<LlmContent> llmContext,
    required ApiConfig apiConfig,
    required Map<String, dynamic> generationParams,
  }) async* {
    _cancelToken = CancelToken(); // Create a new token for this request
    String accumulatedText = "";
    DateTime lastTimestamp = DateTime.now();

    // 1. Convert LlmContent to OpenAI message format
    List<Map<String, dynamic>> openAIMessages = [];
    LlmContent? systemPrompt;

    // Separate system prompt
    for (var content in llmContext) {
      if (content.role == "system") {
        systemPrompt = content;
      }
    }

    // Add system prompt first if it exists
    if (systemPrompt != null) {
      String systemTextContent = systemPrompt.parts
          .whereType<LlmTextPart>()
          .map((part) => part.text)
          .join("\n");
      if (systemTextContent.isNotEmpty) {
        openAIMessages.add({"role": "system", "content": systemTextContent});
      }
    }

    // Add other messages
    for (var content in llmContext) {
      if (content.role == "system") continue;

      final role = content.role == 'model' ? 'assistant' : content.role;
      
      // Vision API format: content can be a string OR an array of parts
      final contentParts = [];
      String textPartBuffer = "";

      for (var part in content.parts) {
        if (part is LlmTextPart) {
          textPartBuffer += "${part.text}\n";
        } else if (part is LlmDataPart) {
          contentParts.add({
            "type": "image_url",
            "image_url": {
              "url": "data:${part.mimeType};base64,${part.base64Data}"
            }
          });
        }
      }
      
      if (textPartBuffer.isNotEmpty) {
        contentParts.insert(0, {
          "type": "text",
          "text": textPartBuffer.trim()
        });
      }

      if (contentParts.isNotEmpty) {
        // If there's only one text part, send as a simple string for wider compatibility.
        // Otherwise, send as an array.
        final messageContent = (contentParts.length == 1 && contentParts.first['type'] == 'text')
                             ? contentParts.first['text']
                             : contentParts;
        openAIMessages.add({"role": role, "content": messageContent});
      }
    }

    // 2. Construct request body
    Map<String, dynamic> requestBody = {
      "model": apiConfig.model,
      "messages": openAIMessages,
      "stream": true,
    };

    // Use generationParams Map for these parameters
    if (generationParams['temperature'] != null) {
      requestBody["temperature"] = generationParams['temperature'];
    }
    if (generationParams['maxOutputTokens'] != null) {
      requestBody["max_tokens"] = generationParams['maxOutputTokens'];
    }
    if (generationParams['topP'] != null) {
      requestBody["top_p"] = generationParams['topP'];
    }
    // topK is not typically used directly by OpenAI's chat completions API.
    // We will only include it if explicitly present in generationParams and if the API supports it.
    // For now, assuming standard OpenAI API, we omit 'topK'.
    // if (generationParams['topK'] != null) {
    //   requestBody["top_k"] = generationParams['topK']; // Or appropriate OpenAI parameter if different
    // }

    if (generationParams['stopSequences'] != null && (generationParams['stopSequences'] as List).isNotEmpty) {
      requestBody["stop"] = generationParams['stopSequences'];
    }

    // Handle reasoning_effort (passed directly from LlmService)
    if (generationParams['reasoning_effort'] != null) {
      requestBody["reasoning_effort"] = generationParams['reasoning_effort'];
    }

    final String apiUrl;
    try {
      final baseUrl = apiConfig.baseUrl;
      if (baseUrl == null || baseUrl.isEmpty) {
        throw Exception("OpenAI API Base URL is not set in the configuration.");
      }
      String tempBaseUrl = baseUrl;
      if (!tempBaseUrl.endsWith('/')) {
        tempBaseUrl += '/';
      }
      apiUrl = Uri.parse(tempBaseUrl).resolve('chat/completions').toString();
      debugPrint("Requesting OpenAI stream from URL: $apiUrl");
    } catch (e) {
      debugPrint("Invalid API Base URL: ${apiConfig.baseUrl}. Error: $e");
      yield LlmStreamChunk.error("Invalid API Base URL: ${apiConfig.baseUrl}", accumulatedText);
      return;
    }

    try {
      final response = await _dio.post<ResponseBody>( // Expecting a stream
        apiUrl,
        data: jsonEncode(requestBody),
        options: Options(
          headers: {
            'Authorization': 'Bearer ${apiConfig.apiKey}',
            'Content-Type': 'application/json',
            'Accept': 'text/event-stream', // Important for SSE
          },
          responseType: ResponseType.stream, // Crucial for SSE
        ),
        cancelToken: _cancelToken, // Pass the cancel token
      );

      final stringStream = utf8.decoder.bind(response.data!.stream);
      String carryOverBuffer = ''; // Buffer for incomplete lines from the stream

      await for (var stringChunk in stringStream) {
        lastTimestamp = DateTime.now();
        // Prepend any carry-over from the previous chunk
        final rawChunk = carryOverBuffer + stringChunk;
        
        // Split into lines
        var lines = rawChunk.split('\n');

        // Check if the last line is complete. If not, buffer it.
        if (rawChunk.endsWith('\n')) {
          carryOverBuffer = ''; // All lines were complete
        } else {
          carryOverBuffer = lines.removeLast(); // Last line is incomplete, buffer it
        }

        for (var line in lines) {
          if (line.trim().isEmpty) continue; // Skip empty lines

          if (line.startsWith('data: ')) {
            final jsonData = line.substring('data: '.length).trim();
            if (jsonData == '[DONE]') {
              debugPrint("OpenAI stream finished with [DONE]");

              // REMOVED: Database saving logic from service layer.
              // This is now handled by ChatStateNotifier.

              yield LlmStreamChunk(
                textChunk: '',
                accumulatedText: accumulatedText, // Return the full raw text
                isFinished: true,
                timestamp: lastTimestamp,
              );
              return; // Stream is complete
            }
            try {
              final Map<String, dynamic> chunkMap = jsonDecode(jsonData);
              if (chunkMap['choices'] != null &&
                  (chunkMap['choices'] as List).isNotEmpty) {
                final choice = chunkMap['choices'][0];
                if (choice['delta'] != null &&
                    choice['delta']['content'] != null) {
                  final String textChunk = choice['delta']['content'];
                  accumulatedText += textChunk;
                  yield LlmStreamChunk(
                    textChunk: textChunk,
                    accumulatedText: accumulatedText,
                    timestamp: lastTimestamp,
                  );
                }
              }
            } catch (e) {
              debugPrint("Error parsing OpenAI stream JSON chunk: $jsonData. Error: $e");
              // Continue to next line, might be a malformed chunk
            }
          }
        }
      }
      // If loop finishes without [DONE], assume stream ended.
      debugPrint("OpenAI stream finished without [DONE] (might be ok). Finalizing...");

      // REMOVED: Database saving logic from service layer.
      // This is now handled by ChatStateNotifier.

      yield LlmStreamChunk(
          textChunk: '',
          accumulatedText: accumulatedText, // Return the full raw text
          isFinished: true,
          timestamp: lastTimestamp,
      );

    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        debugPrint("OpenAI stream request was cancelled by user.");
        // Yield a final chunk indicating cancellation if needed, or just return.
        // For true cancellation, we don't want to yield any more chunks.
        return;
      }
      String errorMessage = "OpenAI API DioException: ${e.message}";
      if (e.response != null) {
        errorMessage += "\nStatus: ${e.response?.statusCode} - ${e.response?.statusMessage}";
        if (e.response?.data is ResponseBody) {
          // Try to read error from stream response if possible
          // This is tricky with streams, often the error is in headers or status code
        } else if (e.response?.data != null) {
           try {
            final errorBody = jsonEncode(e.response?.data); // Attempt to stringify
            errorMessage += "\nBody: $errorBody";
          } catch (jsonErr) {
            errorMessage += "\nBody: (Failed to parse error body as JSON: $jsonErr)";
          }
        }
        debugPrint(errorMessage);
        yield LlmStreamChunk.error(errorMessage, accumulatedText);
      } else {
        debugPrint("OpenAI API DioException (no response): ${e.message}");
        yield LlmStreamChunk.error("OpenAI API Network Error: ${e.message}", accumulatedText);
      }
    } catch (e) {
      debugPrint("Unexpected error in OpenAI sendMessageStream: $e");
      yield LlmStreamChunk.error("Unexpected OpenAI Error: $e", accumulatedText);
    } finally {
      _cancelToken = null; // Clean up the token
    }
  }

  /// Sends messages and gets a single, complete response from an OpenAI-compatible API.
  @override
  Future<LlmResponse> sendMessageOnce({
    required List<LlmContent> llmContext,
    required ApiConfig apiConfig,
    required Map<String, dynamic> generationParams,
  }) async {
    // 1. Convert LlmContent to OpenAI message format
    List<Map<String, dynamic>> openAIMessages = [];
    LlmContent? systemPrompt;

    // Separate system prompt
    for (var content in llmContext) {
      if (content.role == "system") {
        systemPrompt = content;
      }
    }

    // Add system prompt first if it exists
    if (systemPrompt != null) {
      String systemTextContent = systemPrompt.parts
          .whereType<LlmTextPart>()
          .map((part) => part.text)
          .join("\n");
      if (systemTextContent.isNotEmpty) {
        openAIMessages.add({"role": "system", "content": systemTextContent});
      }
    }

    // Add other messages
    for (var content in llmContext) {
      if (content.role == "system") continue;

      final role = content.role == 'model' ? 'assistant' : content.role;

      // Vision API format: content can be a string OR an array of parts
      final contentParts = [];
      String textPartBuffer = "";

      for (var part in content.parts) {
        if (part is LlmTextPart) {
          textPartBuffer += "${part.text}\n";
        } else if (part is LlmDataPart) {
          contentParts.add({
            "type": "image_url",
            "image_url": {
              "url": "data:${part.mimeType};base64,${part.base64Data}"
            }
          });
        }
      }

      if (textPartBuffer.isNotEmpty) {
        contentParts.insert(0, {
          "type": "text",
          "text": textPartBuffer.trim()
        });
      }

      if (contentParts.isNotEmpty) {
        // If there's only one text part, send as a simple string for wider compatibility.
        // Otherwise, send as an array.
        final messageContent = (contentParts.length == 1 && contentParts.first['type'] == 'text')
                             ? contentParts.first['text']
                             : contentParts;
        openAIMessages.add({"role": role, "content": messageContent});
      }
    }

    // 2. Construct request body
    Map<String, dynamic> requestBody = {
      "model": apiConfig.model,
      "messages": openAIMessages,
      "stream": false, // Explicitly false for non-streaming
    };

    // Use generationParams Map for these parameters
    if (generationParams['temperature'] != null) {
      requestBody["temperature"] = generationParams['temperature'];
    }
    if (generationParams['maxOutputTokens'] != null) {
      requestBody["max_tokens"] = generationParams['maxOutputTokens'];
    }
    if (generationParams['topP'] != null) {
      requestBody["top_p"] = generationParams['topP'];
    }
    // topK is not typically used directly by OpenAI's chat completions API.
    // if (generationParams['topK'] != null) {
    //   requestBody["top_k"] = generationParams['topK'];
    // }

    if (generationParams['stopSequences'] != null && (generationParams['stopSequences'] as List).isNotEmpty) {
      requestBody["stop"] = generationParams['stopSequences'];
    }

    // Handle reasoning_effort (passed directly from LlmService)
    if (generationParams['reasoning_effort'] != null) {
      requestBody["reasoning_effort"] = generationParams['reasoning_effort'];
    }

    final String apiUrl;
    try {
      final baseUrl = apiConfig.baseUrl;
      if (baseUrl == null || baseUrl.isEmpty) {
        throw Exception("OpenAI API Base URL is not set in the configuration.");
      }
      String tempBaseUrl = baseUrl;
      if (!tempBaseUrl.endsWith('/')) {
        tempBaseUrl += '/';
      }
      apiUrl = Uri.parse(tempBaseUrl).resolve('chat/completions').toString();
      debugPrint("Requesting OpenAI (once) from URL: $apiUrl");
    } catch (e) {
      debugPrint("Invalid API Base URL for sendMessageOnce: ${apiConfig.baseUrl}. Error: $e");
      return LlmResponse.error("Invalid API Base URL: ${apiConfig.baseUrl}");
    }

    _cancelToken = CancelToken(); // Create a new token for this request
    try {
      final response = await _dio.post(
        apiUrl,
        data: jsonEncode(requestBody),
        options: Options(
          headers: {
            'Authorization': 'Bearer ${apiConfig.apiKey}',
            'Content-Type': 'application/json',
          },
        ),
        cancelToken: _cancelToken, // Pass the cancel token
      );

      if (response.statusCode == 200 && response.data != null) {
        final responseData = response.data as Map<String, dynamic>;
        if (responseData['choices'] != null && (responseData['choices'] as List).isNotEmpty) {
          final messageData = responseData['choices'][0]['message'];
          if (messageData != null && messageData['content'] != null) {
            final rawText = messageData['content'] as String;
            
            // REMOVED: Database saving logic from service layer.
            // This is now handled by ChatStateNotifier.
            
            return LlmResponse(
              parts: [MessagePart.text(rawText)],
              isSuccess: true,
            );
          }
        }
        return const LlmResponse.error("OpenAI response format unexpected (no content).");
      } else {
        String errorMsg = "OpenAI API Error: ${response.statusCode} ${response.statusMessage}";
        if (response.data != null) {
          errorMsg += "\nBody: ${jsonEncode(response.data)}";
        }
        return LlmResponse.error(errorMsg);
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        debugPrint("OpenAI single request was cancelled by user.");
        return const LlmResponse.error("Request cancelled by user.");
      }
      String errorMessage = "OpenAI API DioException: ${e.message}";
      if (e.response != null) {
        errorMessage += "\nStatus: ${e.response?.statusCode} - ${e.response?.statusMessage}";
         if (e.response?.data != null) {
           try {
            final errorBody = jsonEncode(e.response?.data);
            errorMessage += "\nBody: $errorBody";
          } catch (jsonErr) {
            errorMessage += "\nBody: (Failed to parse error body as JSON: $jsonErr)";
          }
        }
      }
      debugPrint(errorMessage);
      return LlmResponse.error(errorMessage);
    } catch (e) {
      debugPrint("Unexpected error in OpenAI sendMessageOnce: $e");
      return LlmResponse.error("Unexpected OpenAI Error: $e");
    } finally {
      _cancelToken = null; // Clean up the token
    }
  }

  /// 使用客户端库 (tiktoken) 计算给定上下文的 Token 数量。
  /// 这是一个纯本地的、高性能的异步操作，用于精确的上下文窗口管理。
  /// 如果计算失败（例如，模型名称无效），它将抛出异常。
  @override
  Future<int> countTokens({
    required List<LlmContent> llmContext,
    required ApiConfig apiConfig,
  }) async {
    // 使用立即调用函数表达式 (IIFE) 来确定编码器，允许 `encoding` 保持 final。
    final encoding = (() {
      try {
        // 优先尝试获取特定模型的编码器。
        return tiktoken.encodingForModel(apiConfig.model);
      } catch (_) {
        // 如果失败，则回退到通用编码器。
        debugPrint("Model '${apiConfig.model}' not found in tiktoken, falling back to 'cl100k_base' for token counting.");
        return tiktoken.getEncoding('cl100k_base');
      }
    })();

    int totalTokens = 0;
    for (final message in llmContext) {
      // 简单的 Token 计算逻辑：连接文本部分并编码。
      // 这提供了一个紧密的估算。要达到完美精度，需要复制消息的
      // 确切结构（角色、分隔符等），但这对于窗口管理而言过于复杂。
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
  @override
  Future<void> cancelRequest() async {
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      debugPrint("OpenAIService: Cancelling active Dio request...");
      _cancelToken!.cancel("Request cancelled by user.");
    }
  }
}

import 'dart:async';
import 'dart:convert'; // For jsonEncode/Decode if needed for request body

import 'package:dio/dio.dart'; // HTTP client
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

import '../models/models.dart'; // Chat, LlmType, Message, MessageRole etc.
// OpenAIAPIConfig will be imported directly from its Drift model file
import '../data/database/drift/models/drift_openai_api_config.dart'; // Import DriftOpenAIAPIConfig
// import '../providers/api_key_provider.dart'; // Not directly needed here, LlmService handles config provision
import '../repositories/message_repository.dart'; // For saving messages
import '../repositories/chat_repository.dart';   // For updating chat timestamp
import 'llm_service.dart'; // Generic LlmContent, LlmStreamChunk, LlmResponse

// 本文件包含与 OpenAI 兼容 API 交互的服务类和相关数据结构。

// --- OpenAI Service Provider ---
final openaiServiceProvider = Provider<OpenAIService>((ref) {
  final dio = Dio(); // Create a Dio instance
  final messageRepository = ref.watch(messageRepositoryProvider); // Get MessageRepository
  return OpenAIService(ref, dio, messageRepository); // Pass MessageRepository
});

// --- OpenAI Service Implementation ---
class OpenAIService {
  final Ref _ref;
  final Dio _dio;
  final MessageRepository _messageRepository; // Add MessageRepository field

  OpenAIService(this._ref, this._dio, this._messageRepository); // Update constructor

  String _formatOpenAIMessageForDebug(Map<String, dynamic> message, String prefix) {
    return '$prefix (Role: ${message['role']}): Content: "${message['content']}"';
  }

  /// Sends messages and gets a streaming response from an OpenAI-compatible API.
  Stream<LlmStreamChunk> sendMessageStream({
    required List<LlmContent> llmContext,
    required Chat chat, // Still needed for chat ID, etc.
    required DriftOpenAIAPIConfig apiConfig,
    required Map<String, dynamic> generationParams, // New parameter
  }) async* {
    // TODO: Implement OpenAI stream logic
    // 1. Construct request body (model, messages, stream: true, etc.)
    //    - Convert LlmContent to OpenAI message format: List<Map<String, String>>
    //    - Include parameters from generationParams if applicable
    // 2. Make POST request to apiConfig.baseUrl + '/v1/chat/completions'
    //    - Headers: {'Authorization': 'Bearer ${apiConfig.apiKey}'}
    // 3. Handle stream response (Server-Sent Events)
    //    - Parse each event, extract text chunk
    //    - Yield LlmStreamChunk
    //    - Handle errors and finish states

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
      if (content.role == "system") continue; // Skip system prompt as it's already added

      String role;
      switch (content.role) {
        case "user":
          role = "user";
          break;
        case "model":
          role = "assistant"; // OpenAI uses "assistant" for model role
          break;
        default:
          role = content.role; // Should not happen if LlmContent.role is validated
          debugPrint("Warning: Unexpected LlmContent role '${content.role}' for OpenAI message conversion.");
      }
      String textContent = content.parts
          .whereType<LlmTextPart>()
          .map((part) => part.text)
          .join("\n");
      // Only add if textContent is not empty, to avoid sending empty messages for other roles
      if (textContent.isNotEmpty) {
        openAIMessages.add({"role": role, "content": textContent});
      }
    }

    // 2. Construct request body
    Map<String, dynamic> requestBody = {
      "model": apiConfig.modelName,
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

    final String apiUrl;
    try {
      String tempBaseUrl = apiConfig.baseUrl;
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
      );

      String carryOverBuffer = ''; // Buffer for incomplete lines from the stream

      await for (var uInt8List in response.data!.stream) {
        lastTimestamp = DateTime.now();
        // Prepend any carry-over from the previous chunk
        final rawChunk = carryOverBuffer + utf8.decode(uInt8List, allowMalformed: true);
        
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

              // Create message with raw text
              final aiMessage = Message.create(
                chatId: chat.id,
                rawText: accumulatedText,
                role: MessageRole.model,
              );
              try {
                await _messageRepository.saveMessage(aiMessage);
                chat.updatedAt = DateTime.now();
                await _ref.read(chatRepositoryProvider).saveChat(chat);
                debugPrint("OpenAIService.sendMessageStream: AI Message (raw) and chat timestamp saved.");
              } catch (dbError) {
                debugPrint("OpenAIService.sendMessageStream: Error saving message/chat: $dbError");
                yield LlmStreamChunk.error("DB Error saving AI response: $dbError", accumulatedText);
              }

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

      final aiMessageAfterLoop = Message.create(
        chatId: chat.id,
        rawText: accumulatedText,
        role: MessageRole.model,
      );
      try {
        await _messageRepository.saveMessage(aiMessageAfterLoop);
        chat.updatedAt = DateTime.now();
        await _ref.read(chatRepositoryProvider).saveChat(chat);
        debugPrint("OpenAIService.sendMessageStream (no DONE): AI Message (raw) and chat timestamp saved.");
      } catch (dbError) {
         debugPrint("OpenAIService.sendMessageStream (no DONE): Error saving message/chat: $dbError");
         yield LlmStreamChunk.error("DB Error saving AI response (no DONE): $dbError", accumulatedText);
      }

      yield LlmStreamChunk(
          textChunk: '',
          accumulatedText: accumulatedText, // Return the full raw text
          isFinished: true,
          timestamp: lastTimestamp,
      );

    } on DioException catch (e) {
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
    }
  }

  /// Sends messages and gets a single, complete response from an OpenAI-compatible API.
  Future<LlmResponse> sendMessageOnce({
    required List<LlmContent> llmContext,
    required Chat chat, // Still needed for chat ID etc.
    required DriftOpenAIAPIConfig apiConfig,
    required Map<String, dynamic> generationParams, // New parameter
  }) async {
    // TODO: Implement OpenAI single response logic
    // 1. Construct request body (model, messages, stream: false, etc.)
    // 2. Make POST request
    // 3. Parse JSON response
    //    - Extract text, handle errors
    //    - Convert to LlmResponse

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
      if (content.role == "system") continue; // Skip system prompt as it's already added

      String role;
      switch (content.role) {
        case "user":
          role = "user";
          break;
        case "model":
          role = "assistant"; // OpenAI uses "assistant" for model role
          break;
        default:
          role = content.role; // Should not happen
          debugPrint("Warning: Unexpected LlmContent role '${content.role}' for OpenAI message conversion (sendMessageOnce).");
      }
      String textContent = content.parts
          .whereType<LlmTextPart>()
          .map((part) => part.text)
          .join("\n");
      if (textContent.isNotEmpty) {
        openAIMessages.add({"role": role, "content": textContent});
      }
    }

    // 2. Construct request body
    Map<String, dynamic> requestBody = {
      "model": apiConfig.modelName,
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

    final String apiUrl;
    try {
      String tempBaseUrl = apiConfig.baseUrl;
      if (!tempBaseUrl.endsWith('/')) {
        tempBaseUrl += '/';
      }
      apiUrl = Uri.parse(tempBaseUrl).resolve('chat/completions').toString();
      debugPrint("Requesting OpenAI (once) from URL: $apiUrl");
    } catch (e) {
      debugPrint("Invalid API Base URL for sendMessageOnce: ${apiConfig.baseUrl}. Error: $e");
      return LlmResponse.error("Invalid API Base URL: ${apiConfig.baseUrl}");
    }

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
      );

      if (response.statusCode == 200 && response.data != null) {
        final responseData = response.data as Map<String, dynamic>;
        if (responseData['choices'] != null && (responseData['choices'] as List).isNotEmpty) {
          final messageData = responseData['choices'][0]['message'];
          if (messageData != null && messageData['content'] != null) {
            final rawText = messageData['content'] as String;
            
            final aiMessage = Message.create(
              chatId: chat.id,
              rawText: rawText,
              role: MessageRole.model,
            );
            try {
              await _messageRepository.saveMessage(aiMessage);
              chat.updatedAt = DateTime.now();
              await _ref.read(chatRepositoryProvider).saveChat(chat);
              debugPrint("OpenAIService.sendMessageOnce: AI Message (raw) and chat timestamp saved.");
            } catch (dbError) {
              debugPrint("OpenAIService.sendMessageOnce: Error saving message/chat: $dbError");
            }
            return LlmResponse(
              rawText: rawText, // Return the full raw text
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
    }
  }

  /// Counts tokens for a given context (OpenAI specific, might be client-side or not directly supported).
  Future<int> countTokens({
    required List<LlmContent> llmContext,
    required DriftOpenAIAPIConfig apiConfig, // Use DriftOpenAIAPIConfig
    // required String modelName, // Or pass modelName directly
  }) async {
    // TODO: Implement OpenAI token counting if possible/needed.
    // OpenAI token counting is often done client-side with a library like tiktoken,
    // or might not be available as a direct API endpoint for all custom OpenAI-compatible servers.
    debugPrint("OpenAIService.countTokens called for ${apiConfig.name}");
    return -1; // Placeholder
  }
}

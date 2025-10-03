// lib/src/openai/services/chat.dart


// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../models.dart';
import '../openai_exception.dart';

/// 处理所有与 OpenAI 聊天补全相关的 API 调用。
class CustomOpenAIChatService {
  final Dio _dio;
  final String _apiKey;
  final String _baseUrl;

  CustomOpenAIChatService({required Dio dio, required String apiKey, required String baseUrl})
      : _dio = dio,
        _apiKey = apiKey,
        _baseUrl = baseUrl;

  /// 创建一个聊天补全响应。
  Future<OpenAIChatCompletionModel> create({
    required String model,
    required List<OpenAIChatCompletionChoiceMessageModel> messages,
    double? temperature,
    double? topP,
    int? maxTokens,
    double? reasoningEffort,
    List<OpenAITool>? tools,
    dynamic toolChoice, // Can be String or Map
    int? n,
    List<String>? stop,
  }) async {
    final url = '$_baseUrl/chat/completions';
    final headers = {
      'Authorization': 'Bearer $_apiKey',
      'Content-Type': 'application/json',
    };
    final body = {
      'model': model,
      'messages': messages.map(_messageToJson).toList(),
      'temperature': temperature,
      'top_p': topP,
      'max_tokens': maxTokens,
      if (reasoningEffort != null) 'reasoning_effort': reasoningEffort,
      if (tools != null) 'tools': tools.map(_toolToJson).toList(),
      if (toolChoice != null) 'tool_choice': toolChoice,
      if (n != null) 'n': n,
      if (stop != null) 'stop': stop,
      'stream': false,
    };

    try {
      final response = await _dio.post(url, data: body, options: Options(headers: headers));
      return _parseChatCompletion(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// 创建一个流式的聊天补全响应。
  Stream<OpenAIChatCompletionModel> createStream({
    required String model,
    required List<OpenAIChatCompletionChoiceMessageModel> messages,
    double? temperature,
    double? topP,
    int? maxTokens,
    double? reasoningEffort,
    List<OpenAITool>? tools,
    dynamic toolChoice,
    int? n,
    List<String>? stop,
  }) async* {
    final url = '$_baseUrl/chat/completions';
    final headers = {
      'Authorization': 'Bearer $_apiKey',
      'Content-Type': 'application/json',
    };
    final body = {
      'model': model,
      'messages': messages.map(_messageToJson).toList(),
      'temperature': temperature,
      'top_p': topP,
      'max_tokens': maxTokens,
      if (reasoningEffort != null) 'reasoning_effort': reasoningEffort,
      if (tools != null) 'tools': tools.map(_toolToJson).toList(),
      if (toolChoice != null) 'tool_choice': toolChoice,
      if (n != null) 'n': n,
      if (stop != null) 'stop': stop,
      'stream': true,
    };

    try {
      final response = await _dio.post<ResponseBody>(
        url,
        data: body,
        options: Options(headers: headers, responseType: ResponseType.stream),
      );

      yield* response.data!.stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .where((line) => line.startsWith('data: '))
          .map((line) => line.substring('data: '.length).trim())
          .where((data) => data.isNotEmpty && data != '[DONE]')
          .map((jsonString) => jsonDecode(jsonString) as Map<String, dynamic>)
          .map(_parseChatCompletion); // Re-use the same parser for stream chunks

    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Map<String, dynamic> _messageToJson(OpenAIChatCompletionChoiceMessageModel message) {
    // [新增] 处理 tool role
    if (message.role == OpenAIChatMessageRole.tool) {
      return {
        'role': 'tool',
        'tool_call_id': message.toolCallId,
        'content': message.content,
      };
    }
  
    // [修改] 现在 content 可能是一个列表
    if (message.content is! List) {
      // 处理简单文本内容的情况（向后兼容或简化路径）
      return {
        'role': message.role.name,
        'content': message.content,
      };
    }
  
    final contentList = (message.content as List<OpenAIChatCompletionChoiceMessageContentItemModel>)
        .map((c) {
          if (c is OpenAITextMessageContent) {
            return {'type': 'text', 'text': c.text};
          }
          if (c is OpenAIImageUrlMessageContent) {
            return {'type': 'image_url', 'image_url': {'url': c.url}};
          }
          return null;
        })
        .whereType<Map<String, dynamic>>()
        .toList();
  
    dynamic finalContent;
    if (contentList.length == 1 && contentList.first['type'] == 'text') {
      finalContent = contentList.first['text'];
    } else {
      finalContent = contentList;
    }
  
    return {
      'role': message.role.name,
      'content': finalContent,
    };
  }

  Map<String, dynamic> _toolToJson(OpenAITool tool) {
    return {
      'type': tool.type,
      'function': {
        'name': tool.function.name,
        'description': tool.function.description,
        'parameters': tool.function.parameters,
      },
    };
  }

  OpenAIChatCompletionModel _parseChatCompletion(Map<String, dynamic> json) {
    // This parser is now robust enough to handle both regular and stream responses.
    return OpenAIChatCompletionModel(
      id: json['id'],
      choices: (json['choices'] as List).map((choice) {
        // In streams, the message is under 'delta', not 'message'.
        final messageJson = choice['delta'] ?? choice['message'];
        if (messageJson == null) {
          // Handle cases where a chunk might be empty (e.g., finish_reason chunk)
          return OpenAIChatCompletionChoiceModel(index: choice['index'], message: OpenAIChatCompletionChoiceMessageModel(role: OpenAIChatMessageRole.assistant, content: []));
        }

        final List<OpenAIChatCompletionChoiceMessageContentItemModel> content = [];
        
        // Handle text content (can be null in stream deltas)
        if (messageJson['content'] is String) {
          content.add(OpenAIChatCompletionChoiceMessageContentItemModel.text(messageJson['content']));
        }
        
        // Handle tool calls
        if (messageJson['tool_calls'] != null) {
          final toolCalls = (messageJson['tool_calls'] as List).map((tc) {
            return OpenAIToolCall(
              id: tc['id'] ?? '', // ID might be in a different chunk
              type: tc['type'] ?? 'function',
              function: OpenAIFunctionCall(
                name: tc['function']?['name'],
                arguments: tc['function']?['arguments'],
              ),
            );
          }).toList();
          content.add(OpenAIToolCallMessageContentItemModel(toolCalls));
        }

        return OpenAIChatCompletionChoiceModel(
          index: choice['index'],
          finishReason: choice['finish_reason'],
          message: OpenAIChatCompletionChoiceMessageModel(
            // Role might be absent in delta chunks, default to assistant
            role: messageJson['role'] != null
                ? OpenAIChatMessageRole.values.firstWhere((r) => r.name == messageJson['role'], orElse: () => OpenAIChatMessageRole.assistant)
                : OpenAIChatMessageRole.assistant,
            content: content,
          ),
        );
      }).toList(),
      created: DateTime.fromMillisecondsSinceEpoch((json['created'] as int) * 1000),
      model: json['model'],
    );
  }

  Exception _handleDioError(DioException e) {
      final response = e.response;
      if (response != null && response.data is Map<String, dynamic>) {
        final errorData = response.data['error'] as Map<String, dynamic>?;
        if (errorData != null) {
          return OpenAIApiException(
            statusCode: response.statusCode,
            message: errorData['message'],
            type: errorData['type'],
            code: errorData['code'],
          );
        }
      }
      // Fallback for other errors
      if (response != null) {
          return Exception('OpenAI API Error: ${response.statusCode} ${response.statusMessage}\nBody: ${response.data}');
      } else {
          return Exception('Error sending request to OpenAI API: ${e.message}');
      }
  }
}
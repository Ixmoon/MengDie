// lib/src/gemini/chat_session.dart


// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'models.dart';

typedef GenerateContentFunc = Future<GenerateContentResponse> Function(
    List<Content> history,
    {GenerationConfig? generationConfig,
    List<SafetySetting>? safetySettings,
    List<Tool>? tools,
    ToolConfig? toolConfig});

typedef StreamGenerateContentFunc = Stream<GenerateContentResponse> Function(
    List<Content> history,
    {GenerationConfig? generationConfig,
    List<SafetySetting>? safetySettings,
    List<Tool>? tools,
    ToolConfig? toolConfig});

/// 模仿 `google_generative_ai` 的 `ChatSession` 类，用于管理多轮对话。
class ChatSession {
  final GenerateContentFunc _generateContent;
  final StreamGenerateContentFunc _streamGenerateContent;
  final List<Content> _history;
  final int? _maxHistoryMessages;
  StreamSubscription? _streamSubscription;

  ChatSession(
      {required GenerateContentFunc generateContent,
      required StreamGenerateContentFunc streamGenerateContent,
      required List<Content> history,
      int? maxHistoryMessages})
      : _generateContent = generateContent,
        _streamGenerateContent = streamGenerateContent,
        _history = history,
        _maxHistoryMessages = maxHistoryMessages;

  /// 获取当前对话的历史记录。
  List<Content> get history => List.unmodifiable(_history);

  /// 向模型发送消息并获取响应。
  Future<GenerateContentResponse> sendMessage(dynamic message,
      {GenerationConfig? generationConfig,
      List<SafetySetting>? safetySettings,
      List<Tool>? tools,
      ToolConfig? toolConfig}) async {
    _truncateHistory();
    final content = _messageToContent(message);
    _history.add(content);
    try {
      final response = await _generateContent(_history,
          generationConfig: generationConfig,
          safetySettings: safetySettings,
          tools: tools,
          toolConfig: toolConfig);
      // 当收到响应后，立即将模型的回复添加到历史记录中，
      // 确保在返回响应前历史记录是完整的，这对函数调用至关重要。
      if (response.candidates.isNotEmpty) {
        _history.add(response.candidates.first.content);
      }
      return response;
    } catch (e) {
      _history.removeLast();
      rethrow;
    }
  }

  /// 以流的形式向模型发送消息并获取响应。
  Stream<GenerateContentResponse> sendMessageStream(dynamic message,
      {GenerationConfig? generationConfig,
      List<SafetySetting>? safetySettings,
      List<Tool>? tools,
      ToolConfig? toolConfig}) {
    _truncateHistory();
    final content = _messageToContent(message);
    _history.add(content);

    try {
      final stream = _streamGenerateContent(_history,
          generationConfig: generationConfig,
          safetySettings: safetySettings,
          tools: tools,
          toolConfig: toolConfig);
      final controller = StreamController<GenerateContentResponse>();
      final aggregatedParts = <Part>[];

      _streamSubscription = stream.listen(
        (response) {
          if (response.candidates.isNotEmpty) {
            final candidate = response.candidates.first;
            aggregatedParts.addAll(candidate.content.parts);
          }
          controller.add(response);
        },
        onError: (e) {
          _history.removeLast();
          controller.addError(e);
          controller.close();
        },
        onDone: () {
          if (aggregatedParts.isNotEmpty) {
            _history.add(Content('model', List.of(aggregatedParts)));
          }
          controller.close();
        },
      );
      return controller.stream;
    } catch (e) {
      _history.removeLast();
      rethrow;
    }
  }

  Content _messageToContent(dynamic message) {
    if (message is Content) {
      return message;
    } else if (message is String) {
      return Content.text(message);
    } else {
      throw ArgumentError(
          'Unsupported message type: ${message.runtimeType}. '
          'Please provide a String or a Content object.');
    }
  }

  Future<void> close() async {
    await _streamSubscription?.cancel();
  }

  void _truncateHistory() {
    if (_maxHistoryMessages != null && _history.length > _maxHistoryMessages!) {
      _history.removeRange(0, _history.length - _maxHistoryMessages!);
    }
  }
}
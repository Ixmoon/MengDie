// lib/src/gemini/music_model.dart


// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'http/http_client.dart';
import 'gemini.dart';

/// A class for interacting with Google AI's Lyria RealTime music generation API.
class MusicModel {
  final String model;
  final HttpClient _client;
  final String? _authToken;
  final String _baseUrl;
  final String apiVersion;

  MusicModel({
    required this.model,
    required HttpClient client,
    required String baseUrl,
    String? authToken,
    this.apiVersion = 'v1alpha',
  })  : _client = client,
        _baseUrl = baseUrl,
        _authToken = authToken;

  /// Connects to the Lyria RealTime API and returns a [MusicSession] for interaction.
  Future<MusicSession> connect() async {
    final apiKey = getAuthToken(_authToken, _client);
    final baseUri = Uri.parse(_baseUrl);

    // 1. [已修改] 使用捕获到的正确路径和查询参数构建 URI
    final uri = Uri(
      scheme: 'wss', // 使用 wss 进行安全 WebSocket 连接
      host: baseUri.host,
      port: baseUri.port,
      // 注意路径开头的 "/"
      path:
          '/ws/google.ai.generativelanguage.$apiVersion.GenerativeService.BidiGenerateMusic',
      queryParameters: {
        // [已修改] 移除 'alt': 'json'，只保留 key
        'key': apiKey,
      },
    );

    // 2. [新增] 构建与官方 SDK 一致的自定义请求头
    final customHeaders = {
      'Content-Type': 'application/json',
      'x-goog-api-key': apiKey,
      'user-agent': 'gemini-dart-sdk/0.1.0', // 定义一个你自己的 User Agent
      'x-goog-api-client': 'gemini-dart-sdk/0.1.0', // 同上
      // Upgrade, Connection, Sec-WebSocket-Key 等头由 web_socket_channel 库自动添加
    };

    // 3. [已修改] 在连接时传递自定义请求头
    final channel = IOWebSocketChannel.connect(uri, headers: customHeaders);

    return MusicSession(channel);
  }
}

/// Represents an active WebSocket session with the Lyria RealTime API.
class MusicSession {
  final WebSocketChannel _channel;
  final StreamController<MusicServerMessage> _serverMessagesController =
      StreamController.broadcast();
  StreamSubscription? _subscription;

  MusicSession(this._channel) {
    _subscription = _channel.stream.listen(
      (message) {
        final decoded = jsonDecode(message);
        _serverMessagesController.add(MusicServerMessage.fromJson(decoded));
      },
      onDone: () {
        _serverMessagesController.close();
      },
      onError: (error) {
        if (error is WebSocketChannelException) {
          _serverMessagesController.addError(
            GeminiApiException(
              message: 'WebSocket connection failed',
              originalException: error,
            ),
          );
        } else {
          _serverMessagesController.addError(error);
        }
      },
    );
  }

  /// A stream of messages received from the server, primarily containing audio chunks.
  Stream<MusicServerMessage> get stream => _serverMessagesController.stream;

  Future<void> _sendCommand(String command, Map<String, dynamic> payload) async {
    final message = {command: payload};
    _channel.sink.add(jsonEncode(message));
  }

  /// Sets the weighted prompts for music generation.
  Future<void> setWeightedPrompts(List<WeightedPrompt> prompts) async {
    await _sendCommand('setWeightedPrompts', {
      'prompts': prompts.map((p) => p.toJson()).toList(),
    });
  }

  /// Sets the configuration for music generation.
  Future<void> setMusicGenerationConfig(LiveMusicGenerationConfig config) async {
    await _sendCommand('setMusicGenerationConfig', {
      'config': config.toJson(),
    });
  }

  /// Starts playing/streaming music from the model.
  Future<void> play() async {
    await _sendCommand('play', {});
  }

  /// Pauses the music stream.
  Future<void> pause() async {
    await _sendCommand('pause', {});
  }

  /// Stops the music stream entirely.
  Future<void> stop() async {
    await _sendCommand('stop', {});
  }

  /// Resets the model's context, useful after significant config changes (e.g., BPM).
  Future<void> resetContext() async {
    await _sendCommand('resetContext', {});
  }

  /// Closes the WebSocket connection.
  Future<void> close() async {
    await _subscription?.cancel();
    await _channel.sink.close();
    await _serverMessagesController.close();
  }
}
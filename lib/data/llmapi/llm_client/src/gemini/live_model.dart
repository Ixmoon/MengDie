// lib/src/gemini/live_model.dart


// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'http/http_client.dart';
import 'gemini.dart';

/// An exception indicating that the server is about to close the connection.
class ConnectionClosingException implements Exception {
  /// The time remaining before the connection is closed.
  final Duration timeLeft;

  const ConnectionClosingException(this.timeLeft);

  @override
  String toString() =>
      'ConnectionClosingException: Server closing connection in $timeLeft.';
}

/// A class for interacting with Google AI's Live API for real-time communication.
class LiveModel {
  final String model;
  final HttpClient _client;
  final String? _authToken;
  final String _baseUrl;
  final String apiVersion;

  LiveModel({
    required this.model,
    required HttpClient client,
    required String baseUrl,
    String? authToken,
    this.apiVersion = 'v1beta',
  })  : _client = client,
        _baseUrl = baseUrl,
        _authToken = authToken;

  /// Connects to the Live API and returns a [LiveSession] for interaction.
  Future<LiveSession> connect(LiveConnectConfig config) async {
    final apiKey = getAuthToken(_authToken, _client);
    final baseUri = Uri.parse(_baseUrl);

    final uri = Uri(
      scheme: 'wss',
      host: baseUri.host,
      port: baseUri.port,
      path:
          '/ws/google.ai.generativelanguage.$apiVersion.GenerativeService.BidiGenerateContent',
      queryParameters: {
        'key': apiKey,
      },
    );

    final customHeaders = {
      'Content-Type': 'application/json',
      'x-goog-api-key': apiKey,
      'user-agent': 'gemini-dart-sdk/0.1.0',
      'x-goog-api-client': 'gemini-dart-sdk/0.1.0',
    };

    final channel = IOWebSocketChannel.connect(uri, headers: customHeaders);

    // Send the initial configuration message.
    final setupPayload = {
      'model': 'models/$model',
      ...config.toJson(),
    };
    final initialMessage = {'setup': setupPayload};
    channel.sink.add(jsonEncode(initialMessage));

    return LiveSession(channel);
  }
}

/// Represents an active WebSocket session with the Live API.
class LiveSession {
  final WebSocketChannel _channel;
  final StreamController<LiveServerMessage> _serverMessagesController =
      StreamController.broadcast();
  StreamSubscription? _subscription;

  LiveSession(this._channel) {
    _subscription = _channel.stream.listen(
      (message) {
        final decoded = jsonDecode(message);
        final serverMessage = LiveServerMessage.fromJson(decoded);

        if (serverMessage.goAway != null) {
          final timeLeftString =
              serverMessage.goAway!.timeLeft.replaceAll(RegExp(r'[^0-9.]'), '');
          final seconds = double.tryParse(timeLeftString);
          final timeLeft = seconds != null
              ? Duration(milliseconds: (seconds * 1000).round())
              : Duration.zero;
          _serverMessagesController.addError(
            ConnectionClosingException(timeLeft),
          );
          _subscription?.cancel();
          _channel.sink.close();
        } else {
          _serverMessagesController.add(serverMessage);
        }
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

  /// A stream of messages received from the server.
  Stream<LiveServerMessage> get stream => _serverMessagesController.stream;

  /// Sends client content to the model.
  Future<void> sendClientContent(List<Content> turns,
      {bool turnComplete = false}) async {
    final message = {
      'clientContent': {
        'turns': turns.map((t) => t.toJson()).toList(),
        'turnComplete': turnComplete,
      }
    };
    _channel.sink.add(jsonEncode(message));
  }

  /// Sends real-time input to the model.
  Future<void> sendRealtimeInput({
    String? text,
    Uint8List? audioBytes,
    Uint8List? videoBytes,
    bool audioStreamEnd = false,
  }) async {
    final message = {
      'realtimeInput': {
        if (text != null) 'text': text,
        if (audioBytes != null)
          'audio': {
            'data': base64Encode(audioBytes),
            'mimeType': 'audio/pcm;rate=16000'
          },
        if (videoBytes != null)
          'video': {
            'data': base64Encode(videoBytes),
            'mimeType': 'video/mp4'
          },
        if (audioStreamEnd) 'audioStreamEnd': true,
      }
    };
    _channel.sink.add(jsonEncode(message));
  }

  /// Sends the result of a tool call back to the model.
  Future<void> sendToolResponse(List<FunctionResponsePart> responses) async {
    final message = {
      'toolResponse': {
        'functionResponses': responses.map((r) => r.toJson()).toList(),
      }
    };
    _channel.sink.add(jsonEncode(message));
  }

  /// Closes the WebSocket connection.
  Future<void> close() async {
    await _subscription?.cancel();
    await _channel.sink.close();
    await _serverMessagesController.close();
  }
}
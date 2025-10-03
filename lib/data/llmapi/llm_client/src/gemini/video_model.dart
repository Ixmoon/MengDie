// lib/src/gemini/video_model.dart


// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'http/http_client.dart';
import 'models.dart';
import 'utils/lro_poller.dart';

/// A class for interacting with Google AI's Veo video generation models.
class VideoModel {
  final String _model;
  final HttpClient _client;
  final LroPoller _lroPoller;

  VideoModel({
    required String model,
    required HttpClient client,
  })  : _model = model,
        _client = client,
        _lroPoller = LroPoller(client);

  /// Generates a video based on a text prompt and polls for the result.
  Future<GenerateVideoResponse> generateVideo({
    required VeoConfig config,
    Duration pollingInterval = const Duration(seconds: 10),
    Duration timeout = const Duration(minutes: 5),
    void Function(Operation operation)? onProgress,
  }) async {
    return _lroPoller.poll<GenerateVideoResponse>(
      startOperation: () => startVideoGeneration(config),
      responseParser: (json) => GenerateVideoResponse.fromJson(json),
      pollingInterval: pollingInterval,
      timeout: timeout,
      onProgress: onProgress,
    );
  }

  Future<Operation> startVideoGeneration(VeoConfig config) async {
    final parameters = config.toApiParametersJson();
    final body = {
      'instances': [config.toApiInstancesJson()],
      if (parameters.isNotEmpty) 'parameters': parameters,
    };
    final response =
        await _client.post('models/$_model:predictLongRunning', body);
    return Operation.fromJson(response);
  }
}
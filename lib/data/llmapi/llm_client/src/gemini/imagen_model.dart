// lib/src/gemini/imagen_model.dart


// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'http/http_client.dart';
import 'models/imagen.dart';

/// A class for interacting with Google AI's Imagen models.
class ImagenModel {
  final String _model;
  final HttpClient _client;

  ImagenModel({
    required String model,
    required HttpClient client,
  })  : _model = model,
        _client = client;

  /// Generates images based on a text prompt.
  Future<ImagenResponse> generateImages({
    required String prompt,
    ImagenParameters? parameters,
  }) async {
    final request = ImagenRequest(
      instances: [ImagenInstance(prompt: prompt)],
      parameters: parameters ?? const ImagenParameters(),
    );

    final response = await _client.post('models/$_model:predict', request.toJson());
    return ImagenResponse.fromJson(response);
  }
}
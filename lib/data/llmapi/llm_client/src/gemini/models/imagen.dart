// lib/src/gemini/models/imagen.dart


// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

/// Represents a request to the Imagen API.
class ImagenRequest {
  final List<ImagenInstance> instances;
  final ImagenParameters parameters;

  const ImagenRequest({required this.instances, required this.parameters});

  Map<String, dynamic> toJson() => {
        'instances': instances.map((i) => i.toJson()).toList(),
        'parameters': parameters.toJson(),
      };
}

/// A single instance in an Imagen request, containing the prompt.
class ImagenInstance {
  final String prompt;

  const ImagenInstance({required this.prompt});

  Map<String, dynamic> toJson() => {'prompt': prompt};
}

/// Parameters for controlling Imagen image generation.
class ImagenParameters {
  final int? numberOfImages;
  final String? aspectRatio;
  final String? personGeneration;

  const ImagenParameters({
    this.numberOfImages,
    this.aspectRatio,
    this.personGeneration,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {};
    if (numberOfImages != null) json['numberOfImages'] = numberOfImages;
    if (aspectRatio != null) json['aspectRatio'] = aspectRatio;
    if (personGeneration != null) json['personGeneration'] = personGeneration;
    return json;
  }
}

/// Represents the response from the Imagen API.
class ImagenResponse {
  final List<String> predictions; // List of base64 encoded images

  const ImagenResponse({required this.predictions});

  factory ImagenResponse.fromJson(Map<String, dynamic> json) {
    // The actual response structure might be nested, e.g., json['predictions'][0]['bytesBase64Encoded']
    // This is a simplified version assuming a flat list of base64 strings.
    // A more robust implementation would inspect the structure more carefully.
    final predictionsList = (json['predictions'] as List? ?? [])
        .map((p) => p['bytesBase64Encoded'] as String)
        .toList();
    return ImagenResponse(predictions: predictionsList);
  }
}
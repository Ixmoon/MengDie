// lib/src/gemini/models/video.dart


// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.


/// Metadata for video processing.
class VideoMetadata {
  final String? startOffset; // e.g., "1250s"
  final String? endOffset;
  final double? fps;

  const VideoMetadata({this.startOffset, this.endOffset, this.fps});

  factory VideoMetadata.fromJson(Map<String, dynamic> json) {
    return VideoMetadata(
      startOffset: json['startOffset'],
      endOffset: json['endOffset'],
      fps: json['fps']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (startOffset != null) 'startOffset': startOffset,
        if (endOffset != null) 'endOffset': endOffset,
        if (fps != null) 'fps': fps,
      };
}

/// Configuration for a Veo video generation request.
class VeoConfig {
  final String prompt;
  final String? image; // Base64 encoded image for image-to-video
  final String? negativePrompt;
  final String? aspectRatio; // "16:9", "9:16"
  final String? personGeneration; // "allow_all", "dont_allow", "allow_adult"
  final int? numberOfVideos;
  final int? durationSeconds;
  final bool? enhancePrompt;

  const VeoConfig({
    required this.prompt,
    this.image,
    this.negativePrompt,
    this.aspectRatio,
    this.personGeneration,
    this.numberOfVideos,
    this.durationSeconds,
    this.enhancePrompt,
  });

  Map<String, dynamic> toApiInstancesJson() => {
        'prompt': prompt,
        if (image != null) 'image': {'bytesBase64Encoded': image},
      };

  Map<String, dynamic> toApiParametersJson() {
    final params = <String, dynamic>{};
    if (negativePrompt != null) params['negativePrompt'] = negativePrompt;
    if (aspectRatio != null) params['aspectRatio'] = aspectRatio;
    if (personGeneration != null) params['personGeneration'] = personGeneration;
    if (numberOfVideos != null) params['numberOfVideos'] = numberOfVideos;
    if (durationSeconds != null) params['durationSeconds'] = durationSeconds;
    if (enhancePrompt != null) params['enhancePrompt'] = enhancePrompt;
    return params;
  }
}


/// The final response containing the generated videos.
class GenerateVideoResponse {
  final List<GeneratedVideo> generatedVideos;
  const GenerateVideoResponse(this.generatedVideos);

  factory GenerateVideoResponse.fromJson(Map<String, dynamic> json) {
    final samples = json['response']?['generateVideoResponse']
        ?['generatedSamples'] as List? ??
        [];
    final videos =
        samples.map((videoJson) => GeneratedVideo.fromJson(videoJson)).toList();
    return GenerateVideoResponse(videos);
  }
}

/// Represents a single generated video with its URI.
class GeneratedVideo {
  final String uri;
  const GeneratedVideo(this.uri);

  factory GeneratedVideo.fromJson(Map<String, dynamic> json) {
    return GeneratedVideo(json['video']['uri']);
  }
}
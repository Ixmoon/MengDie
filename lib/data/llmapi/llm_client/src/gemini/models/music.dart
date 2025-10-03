// lib/src/gemini/models/music.dart


// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

/// A prompt with an associated weight for Lyria RealTime music generation.
class WeightedPrompt {
  final String text;
  final double weight;

  const WeightedPrompt({required this.text, this.weight = 1.0});

  Map<String, dynamic> toJson() => {
        'text': text,
        'weight': weight,
      };
}

/// Configuration for live music generation with Lyria RealTime.
class LiveMusicGenerationConfig {
  final int? bpm;
  final double? temperature;
  final Scale? scale;
  final double? guidance;
  final double? density;
  final double? brightness;
  final bool? muteBass;
  final bool? muteDrums;
  final bool? onlyBassAndDrums;

  const LiveMusicGenerationConfig({
    this.bpm,
    this.temperature,
    this.scale,
    this.guidance,
    this.density,
    this.brightness,
    this.muteBass,
    this.muteDrums,
    this.onlyBassAndDrums,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {};
    if (bpm != null) json['bpm'] = bpm;
    if (temperature != null) json['temperature'] = temperature;
    if (scale != null) json['scale'] = scale!.value;
    if (guidance != null) json['guidance'] = guidance;
    if (density != null) json['density'] = density;
    if (brightness != null) json['brightness'] = brightness;
    if (muteBass != null) json['mute_bass'] = muteBass;
    if (muteDrums != null) json['mute_drums'] = muteDrums;
    if (onlyBassAndDrums != null) {
      json['only_bass_and_drums'] = onlyBassAndDrums;
    }
    return json;
  }
}

/// Musical scales supported by Lyria RealTime.
enum Scale {
  cMajorAMinor('C_MAJOR_A_MINOR'),
  dbMajorBbMinor('D_FLAT_MAJOR_B_FLAT_MINOR'),
  dMajorBMinor('D_MAJOR_B_MINOR'),
  ebMajorCMinor('E_FLAT_MAJOR_C_MINOR'),
  eMajorDbMinor('E_MAJOR_D_FLAT_MINOR'),
  fMajorDMinor('F_MAJOR_D_MINOR'),
  gbMajorEbMinor('G_FLAT_MAJOR_E_FLAT_MINOR'),
  gMajorEMinor('G_MAJOR_E_MINOR'),
  abMajorFMinor('A_FLAT_MAJOR_F_MINOR'),
  aMajorGbMinor('A_MAJOR_G_FLAT_MINOR'),
  bbMajorGMinor('B_FLAT_MAJOR_G_MINOR'),
  bMajorAbMinor('B_MAJOR_A_FLAT_MINOR'),
  unspecified('SCALE_UNSPECIFIED');

  const Scale(this.value);
  final String value;
}

/// Represents a server message from the Lyria RealTime WebSocket session.
class MusicServerMessage {
  final MusicServerContent? serverContent;

  const MusicServerMessage({this.serverContent});

  factory MusicServerMessage.fromJson(Map<String, dynamic> json) {
    return MusicServerMessage(
      serverContent: json['serverContent'] != null
          ? MusicServerContent.fromJson(json['serverContent'])
          : null,
    );
  }
}

/// The content of a server message from Lyria RealTime.
class MusicServerContent {
  final List<AudioChunk> audioChunks;

  const MusicServerContent({required this.audioChunks});

  factory MusicServerContent.fromJson(Map<String, dynamic> json) {
    return MusicServerContent(
      audioChunks: (json['audio_chunks'] as List? ?? [])
          .map((c) => AudioChunk.fromJson(c))
          .toList(),
    );
  }
}

/// A chunk of audio data from Lyria RealTime.
class AudioChunk {
  final List<int> data; // PCM16 audio data

  const AudioChunk({required this.data});

  factory AudioChunk.fromJson(Map<String, dynamic> json) {
    return AudioChunk(
      data: (json['data'] as List).map<int>((e) => e as int).toList(),
    );
  }
}
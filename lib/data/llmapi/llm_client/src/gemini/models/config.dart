// lib/src/gemini/models/config.dart


// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'content.dart';
import 'schema.dart';

/// Configuration for controlling the model's response generation.
class GenerationConfig {
  final double? temperature;
  final double? topP;
  final int? topK;
  final int? maxOutputTokens;
  final List<String>? stopSequences;
  final String? responseMimeType;
  final Schema? responseSchema;
  final Map<String, dynamic>? responseJsonSchema;
  final ThinkingConfig? thinkingConfig;
  final List<String>? responseModalities;
  final SpeechConfig? speechConfig;
  final int? candidateCount;
  final int? seed;
  final double? presencePenalty;
  final double? frequencyPenalty;
  final bool? responseLogprobs;
  final int? logprobs;
  final bool? enableEnhancedCivicAnswers;
  final MediaResolution? mediaResolution;

  const GenerationConfig({
    this.temperature,
    this.topP,
    this.topK,
    this.maxOutputTokens,
    this.stopSequences,
    this.responseMimeType,
    this.responseSchema,
    this.responseJsonSchema,
    this.thinkingConfig,
    this.responseModalities,
    this.speechConfig,
    this.candidateCount,
    this.seed,
    this.presencePenalty,
    this.frequencyPenalty,
    this.responseLogprobs,
    this.logprobs,
    this.enableEnhancedCivicAnswers,
    this.mediaResolution,
  });

  Map<String, dynamic> toJson() => {
        if (temperature != null) 'temperature': temperature,
        if (topP != null) 'topP': topP,
        if (topK != null) 'topK': topK,
        if (maxOutputTokens != null) 'maxOutputTokens': maxOutputTokens,
        if (stopSequences != null) 'stopSequences': stopSequences,
        if (responseMimeType != null) 'responseMimeType': responseMimeType,
        if (responseSchema != null) 'responseSchema': responseSchema!.toJson(),
        if (responseJsonSchema != null)
          'responseJsonSchema': responseJsonSchema,
        if (thinkingConfig != null) 'thinkingConfig': thinkingConfig!.toJson(),
        if (responseModalities != null)
          'responseModalities': responseModalities,
        if (speechConfig != null) 'speechConfig': speechConfig!.toJson(),
        if (candidateCount != null) 'candidateCount': candidateCount,
        if (seed != null) 'seed': seed,
        if (presencePenalty != null) 'presencePenalty': presencePenalty,
        if (frequencyPenalty != null) 'frequencyPenalty': frequencyPenalty,
        if (responseLogprobs != null) 'responseLogprobs': responseLogprobs,
        if (logprobs != null) 'logprobs': logprobs,
        if (enableEnhancedCivicAnswers != null)
          'enableEnhancedCivicAnswers': enableEnhancedCivicAnswers,
        if (mediaResolution != null) 'mediaResolution': mediaResolution!.name,
      };

  factory GenerationConfig.fromJson(Map<String, dynamic> json) {
    return GenerationConfig(
      temperature: json['temperature'],
      topP: json['topP'],
      topK: json['topK'],
      maxOutputTokens: json['maxOutputTokens'],
      stopSequences: json['stopSequences'] != null
          ? List<String>.from(json['stopSequences'])
          : null,
      responseMimeType: json['responseMimeType'],
      responseSchema: json['responseSchema'] != null
          ? Schema.fromJson(json['responseSchema'])
          : null,
      responseJsonSchema: json['responseJsonSchema'],
      thinkingConfig: json['thinkingConfig'] != null
          ? ThinkingConfig.fromJson(json['thinkingConfig'])
          : null,
      responseModalities: json['responseModalities'] != null
          ? List<String>.from(json['responseModalities'])
          : null,
      speechConfig: json['speechConfig'] != null
          ? SpeechConfig.fromJson(json['speechConfig'])
          : null,
      candidateCount: json['candidateCount'],
      seed: json['seed'],
      presencePenalty: json['presencePenalty'],
      frequencyPenalty: json['frequencyPenalty'],
      responseLogprobs: json['responseLogprobs'],
      logprobs: json['logprobs'],
      enableEnhancedCivicAnswers: json['enableEnhancedCivicAnswers'],
      mediaResolution: json['mediaResolution'] != null
          ? MediaResolution.values.firstWhere(
              (e) => e.name.toUpperCase() == json['mediaResolution'])
          : null,
    );
  }

  GenerationConfig copyWith({
    double? temperature,
    double? topP,
    int? topK,
    int? maxOutputTokens,
    List<String>? stopSequences,
    String? responseMimeType,
    Schema? responseSchema,
    Map<String, dynamic>? responseJsonSchema,
    ThinkingConfig? thinkingConfig,
    List<String>? responseModalities,
    SpeechConfig? speechConfig,
    int? candidateCount,
    int? seed,
    double? presencePenalty,
    double? frequencyPenalty,
    bool? responseLogprobs,
    int? logprobs,
    bool? enableEnhancedCivicAnswers,
    MediaResolution? mediaResolution,
  }) {
    return GenerationConfig(
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      topK: topK ?? this.topK,
      maxOutputTokens: maxOutputTokens ?? this.maxOutputTokens,
      stopSequences: stopSequences ?? this.stopSequences,
      responseMimeType: responseMimeType ?? this.responseMimeType,
      responseSchema: responseSchema ?? this.responseSchema,
      responseJsonSchema: responseJsonSchema ?? this.responseJsonSchema,
      thinkingConfig: thinkingConfig ?? this.thinkingConfig,
      responseModalities: responseModalities ?? this.responseModalities,
      speechConfig: speechConfig ?? this.speechConfig,
      candidateCount: candidateCount ?? this.candidateCount,
      seed: seed ?? this.seed,
      presencePenalty: presencePenalty ?? this.presencePenalty,
      frequencyPenalty: frequencyPenalty ?? this.frequencyPenalty,
      responseLogprobs: responseLogprobs ?? this.responseLogprobs,
      logprobs: logprobs ?? this.logprobs,
      enableEnhancedCivicAnswers:
          enableEnhancedCivicAnswers ?? this.enableEnhancedCivicAnswers,
      mediaResolution: mediaResolution ?? this.mediaResolution,
    );
  }
}

/// A safety setting for a specific harm category.
class SafetySetting {
  final HarmCategory category;
  final HarmBlockThreshold threshold;
  const SafetySetting(this.category, this.threshold);

  Map<String, dynamic> toJson() {
    final thresholdString = switch (threshold) {
      HarmBlockThreshold.lowAndAbove => 'BLOCK_LOW_AND_ABOVE',
      HarmBlockThreshold.mediumAndAbove => 'BLOCK_MEDIUM_AND_ABOVE',
      HarmBlockThreshold.highAndAbove => 'BLOCK_ONLY_HIGH',
      HarmBlockThreshold.none => 'BLOCK_NONE',
      HarmBlockThreshold.off => 'OFF',
      _ => 'HARM_BLOCK_THRESHOLD_UNSPECIFIED',
    };
    return {
      'category': 'HARM_CATEGORY_${category.name.toUpperCase()}',
      'threshold': thresholdString,
    };
  }

  factory SafetySetting.fromJson(Map<String, dynamic> json) {
    return SafetySetting(
      HarmCategory.values.firstWhere((e) =>
          'HARM_CATEGORY_${e.name.toUpperCase()}' == json['category']),
      HarmBlockThreshold.values.firstWhere((e) =>
          'HARM_BLOCK_THRESHOLD_${e.name.toUpperCase()}' ==
          json['threshold']),
    );
  }
}

/// The type of harm that may be present in content.
enum HarmCategory {
  unspecified,
  harassment,
  hateSpeech,
  sexuallyExplicit,
  dangerousContent,
  civicIntegrity,
}

/// The threshold for blocking unsafe content.
enum HarmBlockThreshold {
  unspecified,
  lowAndAbove,
  mediumAndAbove,
  highAndAbove,
  none,
  off,
}

/// Defines a tool that can be called by the model.
class Tool {
  final List<FunctionDeclaration>? functionDeclarations;
  final Map<String, dynamic>? googleSearch; // {}
  final Map<String, dynamic>? googleSearchRetrieval; // {}
  final Map<String, dynamic>? codeExecution; // {}
  final Map<String, dynamic>? urlContext; // {}

  const Tool({
    this.functionDeclarations,
    this.googleSearch,
    this.googleSearchRetrieval,
    this.codeExecution,
    this.urlContext,
  }) : assert(
            (functionDeclarations != null ? 1 : 0) +
                    (googleSearch != null ? 1 : 0) +
                    (googleSearchRetrieval != null ? 1 : 0) +
                    (codeExecution != null ? 1 : 0) +
                    (urlContext != null ? 1 : 0) ==
                1,
            'Exactly one of functionDeclarations, googleSearch, googleSearchRetrieval, codeExecution, or urlContext must be provided.');

  Map<String, dynamic> toJson() {
    if (functionDeclarations != null) {
      return {
        'functionDeclarations':
            functionDeclarations!.map((d) => d.toJson()).toList(),
      };
    }
    if (googleSearch != null) {
      return {'googleSearch': googleSearch};
    }
    if (googleSearchRetrieval != null) {
      return {'googleSearchRetrieval': googleSearchRetrieval};
    }
    if (codeExecution != null) {
      return {'codeExecution': codeExecution};
    }
    if (urlContext != null) {
      return {'urlContext': urlContext};
    }
    return {};
  }

  factory Tool.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('functionDeclarations')) {
      return Tool(
          functionDeclarations: (json['functionDeclarations'] as List<dynamic>)
              .map((d) =>
                  FunctionDeclaration.fromJson(d as Map<String, dynamic>))
              .toList());
    }
    if (json.containsKey('googleSearch')) {
      return Tool(googleSearch: json['googleSearch'] as Map<String, dynamic>);
    }
    if (json.containsKey('googleSearchRetrieval')) {
      return Tool(
          googleSearchRetrieval:
              json['googleSearchRetrieval'] as Map<String, dynamic>);
    }
    if (json.containsKey('codeExecution')) {
      return Tool(
          codeExecution: json['codeExecution'] as Map<String, dynamic>);
    }
    if (json.containsKey('urlContext')) {
      return Tool(urlContext: json['urlContext'] as Map<String, dynamic>);
    }
    throw ArgumentError('Invalid Tool JSON: $json');
  }
}

/// A declaration for a single function.
class FunctionDeclaration {
  final String name;
  final String description;
  final Map<String, dynamic>? parameters; // Using Map for OpenAPI Schema
  final Map<String, dynamic>? parametersJsonSchema;
  final Map<String, dynamic>? response;
  final Map<String, dynamic>? responseJsonSchema;
  final Behavior? behavior;

  const FunctionDeclaration({
    required this.name,
    required this.description,
    this.parameters,
    this.parametersJsonSchema,
    this.response,
    this.responseJsonSchema,
    this.behavior,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        if (parameters != null) 'parameters': parameters,
        if (parametersJsonSchema != null)
          'parametersJsonSchema': parametersJsonSchema,
        if (response != null) 'response': response,
        if (responseJsonSchema != null)
          'responseJsonSchema': responseJsonSchema,
        if (behavior != null) 'behavior': behavior!.name,
      };

  factory FunctionDeclaration.fromJson(Map<String, dynamic> json) {
    return FunctionDeclaration(
      name: json['name'] as String,
      description: json['description'] as String,
      parameters: json['parameters'] as Map<String, dynamic>?,
      parametersJsonSchema:
          json['parametersJsonSchema'] as Map<String, dynamic>?,
      response: json['response'] as Map<String, dynamic>?,
      responseJsonSchema: json['responseJsonSchema'] as Map<String, dynamic>?,
      behavior: json['behavior'] != null
          ? Behavior.values.firstWhere((e) => e.name == json['behavior'])
          : null,
    );
  }
}

/// Configures how the model uses tools.
class ToolConfig {
  final FunctionCallingConfig functionCallingConfig;
  const ToolConfig({required this.functionCallingConfig});

  Map<String, dynamic> toJson() =>
      {'functionCallingConfig': functionCallingConfig.toJson()};

  factory ToolConfig.fromJson(Map<String, dynamic> json) {
    return ToolConfig(
      functionCallingConfig:
          FunctionCallingConfig.fromJson(json['functionCallingConfig']),
    );
  }
}

/// Specific configuration for function calling.
class FunctionCallingConfig {
  final FunctionCallingMode mode;
  final List<String>? allowedFunctionNames;

  const FunctionCallingConfig({
    required this.mode,
    this.allowedFunctionNames,
  });

  Map<String, dynamic> toJson() => {
        'mode': mode.name.toUpperCase(),
        if (allowedFunctionNames != null)
          'allowedFunctionNames': allowedFunctionNames,
      };

  factory FunctionCallingConfig.fromJson(Map<String, dynamic> json) {
    return FunctionCallingConfig(
      mode: FunctionCallingMode.values
          .firstWhere((e) => e.name.toUpperCase() == json['mode']),
      allowedFunctionNames: json['allowedFunctionNames'] != null
          ? List<String>.from(json['allowedFunctionNames'])
          : null,
    );
  }
}

/// The mode for function calling.
enum FunctionCallingMode {
  unspecified,
  none,
  auto,
  any,
  validated,
}

/// A developer-set system instruction for the model.
class SystemInstruction {
  final Part part;
  const SystemInstruction(this.part);

  Map<String, dynamic> toJson() => {'parts': [part.toJson()]};

  factory SystemInstruction.fromJson(Map<String, dynamic> json) {
    final partsList = json['parts'] as List<dynamic>;
    if (partsList.isEmpty) {
      throw ArgumentError(
          'Invalid SystemInstruction JSON: "parts" list cannot be empty.');
    }
    final firstPart = partsList.first as Map<String, dynamic>;
    return SystemInstruction(Part.fromJson(firstPart));
  }
}

/// Configuration for the model's thinking process.
class ThinkingConfig {
  final int? thinkingBudget;
  final bool? includeThoughts;

  const ThinkingConfig({this.thinkingBudget, this.includeThoughts});

  Map<String, dynamic> toJson() => {
        if (thinkingBudget != null) 'thinkingBudget': thinkingBudget,
        if (includeThoughts != null) 'includeThoughts': includeThoughts,
      };

  factory ThinkingConfig.fromJson(Map<String, dynamic> json) {
    return ThinkingConfig(
      thinkingBudget: json['thinkingBudget'],
      includeThoughts: json['includeThoughts'],
    );
  }
}

/// Configuration for text-to-speech.
class SpeechConfig {
  final VoiceConfig? voiceConfig;
  final MultiSpeakerVoiceConfig? multiSpeakerVoiceConfig;

  const SpeechConfig({this.voiceConfig, this.multiSpeakerVoiceConfig});

  Map<String, dynamic> toJson() => {
        if (voiceConfig != null) 'voiceConfig': voiceConfig!.toJson(),
        if (multiSpeakerVoiceConfig != null)
          'multiSpeakerVoiceConfig': multiSpeakerVoiceConfig!.toJson(),
      };

  factory SpeechConfig.fromJson(Map<String, dynamic> json) {
    return SpeechConfig(
      voiceConfig: json['voiceConfig'] != null
          ? VoiceConfig.fromJson(json['voiceConfig'])
          : null,
      multiSpeakerVoiceConfig: json['multiSpeakerVoiceConfig'] != null
          ? MultiSpeakerVoiceConfig.fromJson(json['multiSpeakerVoiceConfig'])
          : null,
    );
  }
}

/// Configuration for a single voice.
class VoiceConfig {
  final PrebuiltVoiceConfig prebuiltVoiceConfig;
  const VoiceConfig({required this.prebuiltVoiceConfig});

  Map<String, dynamic> toJson() =>
      {'prebuiltVoiceConfig': prebuiltVoiceConfig.toJson()};

  factory VoiceConfig.fromJson(Map<String, dynamic> json) {
    return VoiceConfig(
      prebuiltVoiceConfig:
          PrebuiltVoiceConfig.fromJson(json['prebuiltVoiceConfig']),
    );
  }
}

/// Media resolution for the input media.
enum MediaResolution {
  unspecified,
  low,
  medium,
  high,
}

/// Defines the function behavior.
enum Behavior {
  unspecified,
  blocking,
  nonBlocking,
}

/// Configuration for a prebuilt voice.
class PrebuiltVoiceConfig {
  final String voiceName;
  const PrebuiltVoiceConfig({required this.voiceName});

  Map<String, dynamic> toJson() => {'voiceName': voiceName};

  factory PrebuiltVoiceConfig.fromJson(Map<String, dynamic> json) {
    return PrebuiltVoiceConfig(
      voiceName: json['voiceName'],
    );
  }
}

/// Configuration for multiple speakers.
class MultiSpeakerVoiceConfig {
  final List<SpeakerVoiceConfig> speakerVoiceConfigs;
  const MultiSpeakerVoiceConfig({required this.speakerVoiceConfigs});

  Map<String, dynamic> toJson() => {
        'speakerVoiceConfigs':
            speakerVoiceConfigs.map((c) => c.toJson()).toList(),
      };

  factory MultiSpeakerVoiceConfig.fromJson(Map<String, dynamic> json) {
    return MultiSpeakerVoiceConfig(
      speakerVoiceConfigs: (json['speakerVoiceConfigs'] as List)
          .map((c) => SpeakerVoiceConfig.fromJson(c))
          .toList(),
    );
  }
}

/// Configuration for a specific speaker's voice.
class SpeakerVoiceConfig {
  final String speaker;
  final VoiceConfig voiceConfig;
  const SpeakerVoiceConfig({required this.speaker, required this.voiceConfig});

  Map<String, dynamic> toJson() => {
        'speaker': speaker,
        'voiceConfig': voiceConfig.toJson(),
      };

  factory SpeakerVoiceConfig.fromJson(Map<String, dynamic> json) {
    return SpeakerVoiceConfig(
      speaker: json['speaker'],
      voiceConfig: VoiceConfig.fromJson(json['voiceConfig']),
    );
  }
}
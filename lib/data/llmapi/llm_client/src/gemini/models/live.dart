// lib/src/gemini/models/live.dart


// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'config.dart';
import 'dart:typed_data';
import 'content.dart';
import 'generative.dart';
import 'grounding.dart';
import 'url_context.dart';

// --- Request Configuration Models ---

class LiveConnectConfig {
  final List<String> responseModalities;
  final Map<String, dynamic>? speechConfig;
  final Map<String, dynamic>? inputAudioTranscription;
  final Map<String, dynamic>? outputAudioTranscription;
  final SessionResumptionConfig? sessionResumption;
  final ContextWindowCompressionConfig? contextWindowCompression;
  final List<Map<String, dynamic>>? tools;
  final RealtimeInputConfig? realtimeInputConfig;
  final ProactivityConfig? proactivity;
  final GenerationConfig? generationConfig;
  final SystemInstruction? systemInstruction;

  const LiveConnectConfig({
    required this.responseModalities,
    this.speechConfig,
    this.inputAudioTranscription,
    this.outputAudioTranscription,
    this.sessionResumption,
    this.contextWindowCompression,
    this.tools,
    this.realtimeInputConfig,
    this.proactivity,
    this.generationConfig,
    this.systemInstruction,
  });

  Map<String, dynamic> toJson() => {
        'responseModalities': responseModalities,
        if (speechConfig != null) 'speechConfig': speechConfig,
        if (inputAudioTranscription != null)
          'inputAudioTranscription': inputAudioTranscription,
        if (outputAudioTranscription != null)
          'outputAudioTranscription': outputAudioTranscription,
        if (sessionResumption != null)
          'sessionResumption': sessionResumption!.toJson(),
        if (contextWindowCompression != null)
          'contextWindowCompression': contextWindowCompression!.toJson(),
        if (tools != null) 'tools': tools,
        if (realtimeInputConfig != null)
          'realtimeInputConfig': realtimeInputConfig!.toJson(),
        if (proactivity != null) 'proactivity': proactivity!.toJson(),
        if (generationConfig != null)
          'generationConfig': generationConfig!.toJson(),
        if (systemInstruction != null)
          'systemInstruction': systemInstruction!.toJson(),
      };
}

class SessionResumptionConfig {
  final String? handle;
  const SessionResumptionConfig({this.handle});
  Map<String, dynamic> toJson() => {'handle': handle};
}

class ContextWindowCompressionConfig {
  final Map<String, dynamic> slidingWindow; // e.g., {'sliding_window': {}}
  const ContextWindowCompressionConfig({this.slidingWindow = const {}});
  Map<String, dynamic> toJson() => slidingWindow;
}

// --- Server Response Models ---

class BidiGenerateContentSetupComplete {
  const BidiGenerateContentSetupComplete();
  factory BidiGenerateContentSetupComplete.fromJson(Map<String, dynamic> json) =>
      const BidiGenerateContentSetupComplete();
}

class BidiGenerateContentToolCallCancellation {
  final String toolCallId;
  const BidiGenerateContentToolCallCancellation({required this.toolCallId});
  factory BidiGenerateContentToolCallCancellation.fromJson(
          Map<String, dynamic> json) =>
      BidiGenerateContentToolCallCancellation(toolCallId: json['toolCallId']);
}

class LiveServerMessage {
  final ServerContent? serverContent;
  final ToolCall? toolCall;
  final SessionResumptionUpdate? sessionResumptionUpdate;
  final GoAway? goAway;
  final UsageMetadata? usageMetadata;
  final BidiGenerateContentSetupComplete? setupComplete;
  final BidiGenerateContentToolCallCancellation? toolCallCancellation;

  // Helper getters
  String? get text => serverContent?.modelTurn?.parts
      .whereType<TextPart>()
      .map((p) => p.text)
      .join('');
  Uint8List? get audioData => serverContent?.modelTurn?.parts
      .whereType<DataPart>()
      .map((p) => p.bytes)
      .firstOrNull;

  const LiveServerMessage({
    this.serverContent,
    this.toolCall,
    this.sessionResumptionUpdate,
    this.goAway,
    this.usageMetadata,
    this.setupComplete,
    this.toolCallCancellation,
  });

  factory LiveServerMessage.fromJson(Map<String, dynamic> json) {
    return LiveServerMessage(
      serverContent: json['serverContent'] != null
          ? ServerContent.fromJson(json['serverContent'])
          : null,
      toolCall:
          json['toolCall'] != null ? ToolCall.fromJson(json['toolCall']) : null,
      sessionResumptionUpdate: json['sessionResumptionUpdate'] != null
          ? SessionResumptionUpdate.fromJson(json['sessionResumptionUpdate'])
          : null,
      goAway: json['goAway'] != null ? GoAway.fromJson(json['goAway']) : null,
      usageMetadata: json['usageMetadata'] != null
          ? UsageMetadata.fromJson(json['usageMetadata'])
          : null,
      setupComplete: json['setupComplete'] != null
          ? BidiGenerateContentSetupComplete.fromJson(json['setupComplete'])
          : null,
      toolCallCancellation: json['toolCallCancellation'] != null
          ? BidiGenerateContentToolCallCancellation.fromJson(
              json['toolCallCancellation'])
          : null,
    );
  }
}

class ServerContent {
  final Content? modelTurn;
  final bool? interrupted;
  final bool? generationComplete;
  final bool? turnComplete;
  final GroundingMetadata? groundingMetadata;
  final BidiGenerateContentTranscription? inputTranscription;
  final BidiGenerateContentTranscription? outputTranscription;
  final UrlContextMetadata? urlContextMetadata;

  const ServerContent({
    this.modelTurn,
    this.interrupted,
    this.generationComplete,
    this.turnComplete,
    this.groundingMetadata,
    this.inputTranscription,
    this.outputTranscription,
    this.urlContextMetadata,
  });

  factory ServerContent.fromJson(Map<String, dynamic> json) {
    return ServerContent(
      modelTurn: json['modelTurn'] != null
          ? Content.fromJson(json['modelTurn'])
          : null,
      interrupted: json['interrupted'],
      generationComplete: json['generationComplete'],
      turnComplete: json['turnComplete'],
      groundingMetadata: json['groundingMetadata'] != null
          ? GroundingMetadata.fromJson(json['groundingMetadata'])
          : null,
      inputTranscription: json['inputTranscription'] != null
          ? BidiGenerateContentTranscription.fromJson(json['inputTranscription'])
          : null,
      outputTranscription: json['outputTranscription'] != null
          ? BidiGenerateContentTranscription.fromJson(
              json['outputTranscription'])
          : null,
      urlContextMetadata: json['urlContextMetadata'] != null
          ? UrlContextMetadata.fromJson(json['urlContextMetadata'])
          : null,
    );
  }
}

class ToolCall {
  final List<FunctionCall> functionCalls;
  const ToolCall({required this.functionCalls});

  factory ToolCall.fromJson(Map<String, dynamic> json) {
    return ToolCall(
      functionCalls: (json['functionCalls'] as List? ?? [])
          .map((fc) => FunctionCall.fromJson(fc))
          .toList(),
    );
  }
}

class SessionResumptionUpdate {
  final bool resumable;
  final String? newHandle;
  const SessionResumptionUpdate({required this.resumable, this.newHandle});

  factory SessionResumptionUpdate.fromJson(Map<String, dynamic> json) {
    return SessionResumptionUpdate(
      resumable: json['resumable'],
      newHandle: json['newHandle'],
    );
  }
}

class GoAway {
  final String timeLeft;
  const GoAway({required this.timeLeft});
  factory GoAway.fromJson(Map<String, dynamic> json) {
    return GoAway(timeLeft: json['timeLeft']);
  }
}

class RealtimeInputConfig {
  // Simplified for now
  const RealtimeInputConfig();
  Map<String, dynamic> toJson() => {};
}

class ProactivityConfig {
  final bool? proactiveAudio;
  const ProactivityConfig({this.proactiveAudio});
  Map<String, dynamic> toJson() =>
      {'proactiveAudio': proactiveAudio ?? false};
}

class BidiGenerateContentTranscription {
  final String text;
  const BidiGenerateContentTranscription({required this.text});
  factory BidiGenerateContentTranscription.fromJson(Map<String, dynamic> json) {
    return BidiGenerateContentTranscription(text: json['text']);
  }
}
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'enums.dart';

@immutable
class ApiConfig {
  final String id;
  final String name;
  final LlmType apiType;
  final String model;
  final String? apiKey;
  final String? baseUrl;
  final bool useCustomTemperature;
  final double? temperature;
  final bool useCustomTopP;
  final double? topP;
  final bool useCustomTopK;
  final int? topK;
  final int? maxOutputTokens;
  final List<String>? stopSequences;
  final DateTime createdAt;
  final DateTime updatedAt;
  // OpenAI specific settings
  final bool? enableReasoningEffort;
  final OpenAIReasoningEffort? reasoningEffort;

  const ApiConfig({
    required this.id,
    required this.name,
    required this.apiType,
    required this.model,
    this.apiKey,
    this.baseUrl,
    this.useCustomTemperature = false,
    this.temperature,
    this.useCustomTopP = false,
    this.topP,
    this.useCustomTopK = false,
    this.topK,
    this.maxOutputTokens,
    this.stopSequences,
    required this.createdAt,
    required this.updatedAt,
    this.enableReasoningEffort,
    this.reasoningEffort = OpenAIReasoningEffort.auto,
  });

  factory ApiConfig.fromJson(Map<String, dynamic> json) {
    return ApiConfig(
      id: json['id'],
      name: json['name'],
      apiType: LlmType.values.byName(json['api_type']),
      model: json['model'],
      apiKey: json['api_key'],
      baseUrl: json['base_url'],
      useCustomTemperature: json['use_custom_temperature'] ?? false,
      temperature: (json['temperature'] as num?)?.toDouble(),
      useCustomTopP: json['use_custom_top_p'] ?? false,
      topP: (json['top_p'] as num?)?.toDouble(),
      useCustomTopK: json['use_custom_top_k'] ?? false,
      topK: json['top_k'],
      maxOutputTokens: json['max_output_tokens'],
      stopSequences: (json['stop_sequences'] as List<dynamic>?)?.cast<String>(),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      enableReasoningEffort: json['enable_reasoning_effort'],
      reasoningEffort: json['reasoning_effort'] != null
          ? OpenAIReasoningEffort.values.byName(json['reasoning_effort'])
          : OpenAIReasoningEffort.auto,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'api_type': apiType.name,
      'model': model,
      'api_key': apiKey,
      'base_url': baseUrl,
      'use_custom_temperature': useCustomTemperature,
      'temperature': temperature,
      'use_custom_top_p': useCustomTopP,
      'top_p': topP,
      'use_custom_top_k': useCustomTopK,
      'top_k': topK,
      'max_output_tokens': maxOutputTokens,
      'stop_sequences': stopSequences,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'enable_reasoning_effort': enableReasoningEffort,
      'reasoning_effort': reasoningEffort?.name,
    };
  }
}
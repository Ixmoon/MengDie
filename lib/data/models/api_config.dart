import 'package:flutter/foundation.dart';
import 'enums.dart'; // Assuming enums.dart will be cleaned up to only export pure enums

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
  });
}
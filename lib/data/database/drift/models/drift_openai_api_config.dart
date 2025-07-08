import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../app_database.dart'; // Import generated data class

class DriftOpenAIAPIConfig {
  late final String id;
  String name;
  String baseUrl;
  String? apiKey;
  String model; // Renamed from modelName for consistency
  double? temperature;
  int? maxTokens;


  DriftOpenAIAPIConfig({
    String? id,
    this.name = 'My OpenAI Endpoint',
    this.baseUrl = 'https://api.openai.com/v1',
    this.apiKey,
    this.model = 'gpt-3.5-turbo',
    this.temperature,
    this.maxTokens,
  }) {
    this.id = id ?? const Uuid().v4();
  }

  // Deserialization from JSON
  factory DriftOpenAIAPIConfig.fromJson(Map<String, dynamic> json) {
    return DriftOpenAIAPIConfig(
      id: json['id'] as String? ?? const Uuid().v4(),
      name: json['name'] as String? ?? 'My OpenAI Endpoint',
      baseUrl: json['baseUrl'] as String? ?? 'https://api.openai.com/v1',
      apiKey: json['apiKey'] as String?,
      model: json['model'] as String? ?? 'gpt-3.5-turbo',
      temperature: (json['temperature'] as num?)?.toDouble(),
      maxTokens: json['maxTokens'] as int?,
    );
  }

  // Serialization to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'baseUrl': baseUrl,
      'apiKey': apiKey,
      'model': model,
      'temperature': temperature,
      'maxTokens': maxTokens,
    };
  }

  // Conversion from Drift's data class to this model
  factory DriftOpenAIAPIConfig.fromData(OpenAIConfig data) {
    return DriftOpenAIAPIConfig(
      id: data.id,
      name: data.name,
      baseUrl: data.baseUrl,
      apiKey: data.apiKey,
      model: data.model,
      temperature: data.temperature,
      maxTokens: data.maxTokens,
    );
  }

  // Conversion from this model to Drift's companion for writing
  OpenAIConfigsCompanion toCompanion({bool forInsert = false}) {
    return OpenAIConfigsCompanion(
      id: forInsert ? const Value.absent() : Value(id),
      name: Value(name),
      baseUrl: Value(baseUrl),
      apiKey: Value(apiKey ?? ''),
      model: Value(model),
      temperature: Value(temperature),
      maxTokens: Value(maxTokens),
      updatedAt: Value(DateTime.now()),
    );
  }
}

import 'package:uuid/uuid.dart';

class DriftOpenAIAPIConfig {
  late final String id;
  String name;
  String baseUrl;
  String? apiKey;
  String modelName;

  DriftOpenAIAPIConfig({
    String? id,
    this.name = 'My OpenAI Endpoint',
    this.baseUrl = 'https://api.openai.com/v1',
    this.apiKey,
    this.modelName = 'gpt-3.5-turbo',
  }) {
    this.id = id ?? const Uuid().v4();
  }

  factory DriftOpenAIAPIConfig.fromJson(Map<String, dynamic> json) {
    return DriftOpenAIAPIConfig(
      id: json['id'] as String? ?? const Uuid().v4(), // Ensure ID is always present
      name: json['name'] as String? ?? 'My OpenAI Endpoint',
      baseUrl: json['baseUrl'] as String? ?? 'https://api.openai.com/v1',
      apiKey: json['apiKey'] as String?,
      modelName: json['modelName'] as String? ?? 'gpt-3.5-turbo',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'baseUrl': baseUrl,
      'apiKey': apiKey,
      'modelName': modelName,
    };
  }
}

import 'package:drift/drift.dart';

// Import the domain model with a prefix 'domain' to avoid name clashes
import '../../domain/models/api_config.dart' as domain;
// Import the drift-generated data class and companion from the database layer
import '../database/app_database.dart' as drift;

/// Maps between the domain [domain.ApiConfig] and the Drift-generated
/// [drift.ApiConfig] data class and [drift.ApiConfigsCompanion].
class ApiConfigMapper {
  /// Converts a Drift data class [drift.ApiConfig] to a domain model [domain.ApiConfig].
  static domain.ApiConfig fromData(drift.ApiConfig data) {
    return domain.ApiConfig(
      id: data.id,
      name: data.name,
      apiType: data.apiType, // This relies on the LlmType enum being accessible
      model: data.model,
      apiKey: data.apiKey,
      baseUrl: data.baseUrl,
      useCustomTemperature: data.useCustomTemperature ?? false,
      temperature: data.temperature,
      useCustomTopP: data.useCustomTopP ?? false,
      topP: data.topP,
      useCustomTopK: data.useCustomTopK ?? false,
      topK: data.topK,
      maxOutputTokens: data.maxOutputTokens,
      stopSequences: data.stopSequences ?? [],
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
      enableReasoningEffort: data.enableReasoningEffort ?? false,
      reasoningEffort: data.reasoningEffort,
      thinkingBudget: data.thinkingBudget,
      toolConfig: data.toolConfig,
      toolChoice: data.toolChoice,
      useDefaultSafetySettings: data.useDefaultSafetySettings,
    );
  }

  /// Converts a domain model [domain.ApiConfig] to a Drift [drift.ApiConfigsCompanion]
  /// for database insertion or update operations.
  static drift.ApiConfigsCompanion toCompanion(domain.ApiConfig config) {
    return drift.ApiConfigsCompanion(
      id: Value(config.id),
      name: Value(config.name),
      apiType: Value(config.apiType),
      model: Value(config.model),
      apiKey: Value(config.apiKey),
      baseUrl: Value(config.baseUrl),
      useCustomTemperature: Value(config.useCustomTemperature),
      temperature: Value(config.temperature),
      useCustomTopP: Value(config.useCustomTopP),
      topP: Value(config.topP),
      useCustomTopK: Value(config.useCustomTopK),
      topK: Value(config.topK),
      maxOutputTokens: Value(config.maxOutputTokens),
      stopSequences: Value(config.stopSequences),
      createdAt: Value(config.createdAt),
      updatedAt: Value(config.updatedAt),
      enableReasoningEffort: Value(config.enableReasoningEffort),
      reasoningEffort: Value(config.reasoningEffort),
      thinkingBudget: Value(config.thinkingBudget),
      toolConfig: Value(config.toolConfig),
      toolChoice: Value(config.toolChoice),
      useDefaultSafetySettings: Value(config.useDefaultSafetySettings),
    );
  }
}
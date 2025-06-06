import 'dart:convert';
import 'package:drift/drift.dart';
import 'models/drift_generation_config.dart';
import 'models/drift_context_config.dart';
import 'models/drift_xml_rule.dart';
import 'models/drift_openai_api_config.dart'; // Assuming this will be stored in settings, not directly in chat
import 'common_enums.dart';

// For GenerationConfig
class GenerationConfigConverter extends TypeConverter<DriftGenerationConfig, String> {
  const GenerationConfigConverter();

  @override
  DriftGenerationConfig fromSql(String fromDb) {
    return DriftGenerationConfig.fromJson(json.decode(fromDb) as Map<String, dynamic>);
  }

  @override
  String toSql(DriftGenerationConfig value) {
    return json.encode(value.toJson());
  }
}

// For ContextConfig
class ContextConfigConverter extends TypeConverter<DriftContextConfig, String> {
  const ContextConfigConverter();

  @override
  DriftContextConfig fromSql(String fromDb) {
    return DriftContextConfig.fromJson(json.decode(fromDb) as Map<String, dynamic>);
  }

  @override
  String toSql(DriftContextConfig value) {
    return json.encode(value.toJson());
  }
}

// For List<DriftXmlRule>
class XmlRuleListConverter extends TypeConverter<List<DriftXmlRule>, String> {
  const XmlRuleListConverter();

  @override
  List<DriftXmlRule> fromSql(String fromDb) {
    if (fromDb.isEmpty) return [];
    final List<dynamic> jsonData = json.decode(fromDb) as List<dynamic>;
    return jsonData.map((item) => DriftXmlRule.fromJson(item as Map<String, dynamic>)).toList();
  }

  @override
  String toSql(List<DriftXmlRule> value) {
    return json.encode(value.map((rule) => rule.toJson()).toList());
  }
}

// For LlmType enum
class LlmTypeConverter extends TypeConverter<LlmType, String> {
  const LlmTypeConverter();

  @override
  LlmType fromSql(String fromDb) {
    return LlmType.values.firstWhere((e) => e.name == fromDb, orElse: () => LlmType.gemini);
  }

  @override
  String toSql(LlmType value) {
    return value.name;
  }
}

// For MessageRole enum
class MessageRoleConverter extends TypeConverter<MessageRole, String> {
  const MessageRoleConverter();

  @override
  MessageRole fromSql(String fromDb) {
    return MessageRole.values.firstWhere((e) => e.name == fromDb, orElse: () => MessageRole.user);
  }

  @override
  String toSql(MessageRole value) {
    return value.name;
  }
}

// Note: DriftOpenAIAPIConfig might be better stored as a separate table if it becomes complex
// or if multiple chats can share the same config.
// For now, if it were to be stored as JSON in a single chat's settings:
class OpenAIAPIConfigConverter extends TypeConverter<DriftOpenAIAPIConfig, String> {
  const OpenAIAPIConfigConverter();

  @override
  DriftOpenAIAPIConfig fromSql(String fromDb) {
    return DriftOpenAIAPIConfig.fromJson(json.decode(fromDb) as Map<String, dynamic>);
  }

  @override
  String toSql(DriftOpenAIAPIConfig value) {
    return json.encode(value.toJson());
  }
}

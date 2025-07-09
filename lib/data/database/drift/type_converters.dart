import 'dart:convert';
import 'package:drift/drift.dart';
import 'models/drift_context_config.dart';
import 'models/drift_xml_rule.dart';
import 'common_enums.dart';

// Note: GenerationConfigConverter is removed as its fields are now part of the ApiConfigs table.
// Note: OpenAIAPIConfigConverter is removed for the same reason.

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

// For List<String>
class StringListConverter extends TypeConverter<List<String>?, String?> {
  const StringListConverter();

  @override
  List<String>? fromSql(String? fromDb) {
    if (fromDb == null || fromDb.isEmpty) {
      return null;
    }
    try {
      final List<dynamic> jsonData = json.decode(fromDb) as List<dynamic>;
      return jsonData.map((item) => item as String).toList();
    } catch (e) {
      // Handle potential old data that was stored as comma-separated.
      return fromDb.split(',');
    }
  }

  @override
  String? toSql(List<String>? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return json.encode(value);
  }
}

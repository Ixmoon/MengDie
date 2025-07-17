import 'dart:convert';
import 'package:drift/drift.dart';
import '../../domain/models/context_config.dart';
import '../../domain/models/xml_rule.dart';
import '../../domain/enums.dart';

// Note: GenerationConfigConverter is removed as its fields are now part of the ApiConfigs table.
// Note: OpenAIAPIConfigConverter is removed for the same reason.

// For ContextConfig
class ContextConfigConverter extends TypeConverter<ContextConfig, String> {
  const ContextConfigConverter();

  @override
  ContextConfig fromSql(String fromDb) {
    return ContextConfig.fromJson(json.decode(fromDb) as Map<String, dynamic>);
  }

  @override
  String toSql(ContextConfig value) {
    return json.encode(value.toJson());
  }
}

// For List<XmlRule>
class XmlRuleListConverter extends TypeConverter<List<XmlRule>, String> {
  const XmlRuleListConverter();

  @override
  List<XmlRule> fromSql(String fromDb) {
    if (fromDb.isEmpty) return [];
    final List<dynamic> jsonData = json.decode(fromDb) as List<dynamic>;
    return jsonData.map((item) => XmlRule.fromJson(item as Map<String, dynamic>)).toList();
  }

  @override
  String toSql(List<XmlRule> value) {
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
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) {
    // If the data from the database is empty, return an empty list.
    if (fromDb.isEmpty) {
      return [];
    }
    try {
      // Try to decode it as a JSON list.
      final List<dynamic> jsonData = json.decode(fromDb) as List<dynamic>;
      return jsonData.map((item) => item as String).toList();
    } catch (e) {
      // Handle potential old data that was stored as a single string or comma-separated.
      if (fromDb.startsWith('[') && fromDb.endsWith(']')) {
        final content = fromDb.substring(1, fromDb.length - 1);
        return content.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      }
      return [fromDb];
    }
  }

  @override
  String toSql(List<String> value) {
    // Always encode to a JSON string. An empty list becomes '[]'.
    return json.encode(value);
  }
}
// For generic Map<String, dynamic> to handle legacy columns gracefully
class JsonMapConverter extends TypeConverter<Map<String, dynamic>?, String?> {
  const JsonMapConverter();

  @override
  Map<String, dynamic>? fromSql(String? fromDb) {
    if (fromDb == null || fromDb.isEmpty) {
      return null;
    }
    try {
      return json.decode(fromDb) as Map<String, dynamic>;
    } catch (e) {
      // If parsing fails, return null to avoid crashing.
      return null;
    }
  }

  @override
  String? toSql(Map<String, dynamic>? value) {
    if (value == null) {
      return null;
    }
    return json.encode(value);
  }
}

// For OpenAIReasoningEffort enum
class OpenAIReasoningEffortConverter extends TypeConverter<OpenAIReasoningEffort?, String?> {
  const OpenAIReasoningEffortConverter();

  @override
  OpenAIReasoningEffort? fromSql(String? fromDb) {
    if (fromDb == null) return null;
    // Safely find the enum by name, defaulting to 'none' if not found.
    return OpenAIReasoningEffort.values.firstWhere((e) => e.name == fromDb, orElse: () => OpenAIReasoningEffort.auto);
  }

  @override
  String? toSql(OpenAIReasoningEffort? value) {
    return value?.name;
  }
}

// For HelpMeReplyTriggerMode enum
class HelpMeReplyTriggerModeConverter extends TypeConverter<HelpMeReplyTriggerMode?, String?> {
  const HelpMeReplyTriggerModeConverter();

  @override
  HelpMeReplyTriggerMode? fromSql(String? fromDb) {
    if (fromDb == null) return null;
    return HelpMeReplyTriggerMode.values.firstWhere((e) => e.name == fromDb, orElse: () => HelpMeReplyTriggerMode.manual);
  }

  @override
  String? toSql(HelpMeReplyTriggerMode? value) {
    return value?.name;
  }
}

/// Type converter for `List<int>` to be stored as a JSON string.
class IntListConverter extends TypeConverter<List<int>, String> {
  const IntListConverter();

  @override
  List<int> fromSql(String fromDb) {
    if (fromDb.isEmpty) return [];
    try {
      final List<dynamic> jsonData = json.decode(fromDb) as List<dynamic>;
      return jsonData.map((item) => item as int).toList();
    } catch (e) {
      // Fallback for non-JSON format like '[1,2,3]'
      if (fromDb.startsWith('[') && fromDb.endsWith(']')) {
        final content = fromDb.substring(1, fromDb.length - 1);
        if (content.isEmpty) return [];
        return content.split(',').map((s) => int.parse(s.trim())).toList();
      }
      return []; // Return empty list if format is unrecognizable
    }
  }

  @override
  String toSql(List<int> value) {
    return json.encode(value);
  }
}

import 'package:flutter/foundation.dart'; // for listEquals

import 'enums.dart'; // 导入本地枚举

// --- DTO for XmlRule ---
@immutable
class XmlRuleDto {
  final String? tagName;
  final XmlAction action;

  const XmlRuleDto({
    this.tagName,
    this.action = XmlAction.ignore,
  });

  factory XmlRuleDto.fromJson(Map<String, dynamic> json) {
    return XmlRuleDto(
      tagName: json['tagName'] as String?,
      action: XmlAction.values.firstWhere(
        (e) => e.toString() == json['action'],
        orElse: () => XmlAction.ignore,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tagName': tagName,
      'action': action.toString(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is XmlRuleDto &&
          runtimeType == other.runtimeType &&
          tagName == other.tagName &&
          action == other.action;

  @override
  int get hashCode => tagName.hashCode ^ action.hashCode;
}

// SafetySettingRuleDto is no longer needed for export

// GenerationConfigDto is no longer needed for export

// --- DTO for ContextConfig ---
@immutable
class ContextConfigDto {
  final ContextManagementMode mode;
  final int maxTurns;
  final int? maxContextTokens;

  const ContextConfigDto({
    this.mode = ContextManagementMode.turns,
    this.maxTurns = 10,
    this.maxContextTokens,
  });

  factory ContextConfigDto.fromJson(Map<String, dynamic> json) {
    return ContextConfigDto(
      mode: ContextManagementMode.values.firstWhere(
        (e) => e.toString() == json['mode'],
        orElse: () => ContextManagementMode.turns,
      ),
      maxTurns: json['maxTurns'] as int? ?? 10,
      maxContextTokens: json['maxContextTokens'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode.toString(),
      'maxTurns': maxTurns,
      'maxContextTokens': maxContextTokens,
    };
  }

   @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContextConfigDto &&
          runtimeType == other.runtimeType &&
          mode == other.mode &&
          maxTurns == other.maxTurns &&
          maxContextTokens == other.maxContextTokens;

  @override
  int get hashCode =>
      mode.hashCode ^ maxTurns.hashCode ^ maxContextTokens.hashCode;
}

// --- DTO for Message ---
@immutable
class MessageExportDto {
  final String rawText;
  final MessageRole role;
  final List<Map<String, dynamic>>? parts;
  final String? originalXmlContent;
  final String? secondaryXmlContent;

  const MessageExportDto({
    required this.rawText,
    required this.role,
    this.parts,
    this.originalXmlContent,
    this.secondaryXmlContent,
  });

  factory MessageExportDto.fromJson(Map<String, dynamic> json) {
    return MessageExportDto(
      rawText: json['rawText'] as String? ?? '',
      role: MessageRole.values.byName(json['role'] ?? 'user'),
      parts: (json['parts'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList(),
      originalXmlContent: json['originalXmlContent'] as String?,
      secondaryXmlContent: json['secondaryXmlContent'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rawText': rawText,
      'role': role.name,
      'parts': parts,
      'originalXmlContent': originalXmlContent,
      'secondaryXmlContent': secondaryXmlContent,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageExportDto &&
          runtimeType == other.runtimeType &&
          rawText == other.rawText &&
          role == other.role &&
          listEquals(parts, other.parts) &&
          originalXmlContent == other.originalXmlContent &&
          secondaryXmlContent == other.secondaryXmlContent;

  @override
  int get hashCode =>
      rawText.hashCode ^
      role.hashCode ^
      parts.hashCode ^
      originalXmlContent.hashCode ^
      secondaryXmlContent.hashCode;
}

// --- DTO for Chat ---
@immutable
class ChatExportDto {
  final String? title;
  final String? systemPrompt;
  final bool isFolder;
  final String? apiConfigId;
  final ContextConfigDto contextConfig;
  final List<XmlRuleDto> xmlRules;
  final List<MessageExportDto> messages;
  final String? coverImageBase64;
  final bool enablePreprocessing;
  final String? preprocessingPrompt;
  final String? preprocessingApiConfigId;
  final bool enableSecondaryXml;
  final String? secondaryXmlPrompt;
  final String? secondaryXmlApiConfigId;
  final String? contextSummary;
  final String? continuePrompt;
  final bool hasRealCoverImage;
  // 新增时间戳字段
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? orderIndex; // 新增：用于保存排序信息

  const ChatExportDto({
    this.title,
    this.systemPrompt,
    this.isFolder = false,
    this.apiConfigId,
    required this.contextConfig,
    required this.xmlRules,
    required this.messages,
    this.coverImageBase64,
    this.enablePreprocessing = false,
    this.preprocessingPrompt,
    this.preprocessingApiConfigId,
    this.enableSecondaryXml = false,
    this.secondaryXmlPrompt,
    this.secondaryXmlApiConfigId,
    this.contextSummary,
    this.continuePrompt,
    this.hasRealCoverImage = false,
    this.createdAt, // 在构造函数中添加
    this.updatedAt, // 在构造函数中添加
    this.orderIndex, // 在构造函数中添加
  });

  factory ChatExportDto.fromJson(Map<String, dynamic> json) {
    return ChatExportDto(
      title: json['title'] as String?,
      systemPrompt: json['systemPrompt'] as String?,
      isFolder: json['isFolder'] as bool? ?? false,
      apiConfigId: json['apiConfigId'] as String?,
      contextConfig: ContextConfigDto.fromJson(json['contextConfig'] as Map<String, dynamic>),
      xmlRules: (json['xmlRules'] as List<dynamic>)
          .map((e) => XmlRuleDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      messages: (json['messages'] as List<dynamic>)
          .map((e) => MessageExportDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      coverImageBase64: json['coverImageBase64'] as String?,
      enablePreprocessing: json['enablePreprocessing'] as bool? ?? false,
      preprocessingPrompt: json['preprocessingPrompt'] as String?,
      preprocessingApiConfigId: json['preprocessingApiConfigId'] as String?,
      enableSecondaryXml: json['enableSecondaryXml'] as bool? ?? false,
      secondaryXmlPrompt: json['secondaryXmlPrompt'] as String?,
      secondaryXmlApiConfigId: json['secondaryXmlApiConfigId'] as String?,
      contextSummary: json['contextSummary'] as String?,
      continuePrompt: json['continuePrompt'] as String?,
      hasRealCoverImage: json['hasRealCoverImage'] as bool? ?? false,
      // 从 JSON 解析时间戳
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : null,
      orderIndex: json['orderIndex'] as int?, // 从 JSON 解析排序信息
    );
  }

  factory ChatExportDto.createFolder({required String? title}) {
    return ChatExportDto(
      title: title,
      isFolder: true,
      contextConfig: const ContextConfigDto(),
      xmlRules: const [],
      messages: const [],
    );
  }

  ChatExportDto copyWith({
    String? title,
    String? systemPrompt,
    bool? isFolder,
    String? apiConfigId,
    ContextConfigDto? contextConfig,
    List<XmlRuleDto>? xmlRules,
    List<MessageExportDto>? messages,
    String? coverImageBase64,
    bool? hasRealCoverImage,
    bool? enablePreprocessing,
    String? preprocessingPrompt,
    String? preprocessingApiConfigId,
    bool? enableSecondaryXml,
    String? secondaryXmlPrompt,
    String? secondaryXmlApiConfigId,
    String? contextSummary,
    String? continuePrompt,
    int? orderIndex,
  }) {
    return ChatExportDto(
      title: title ?? this.title,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      isFolder: isFolder ?? this.isFolder,
      apiConfigId: apiConfigId ?? this.apiConfigId,
      contextConfig: contextConfig ?? this.contextConfig,
      xmlRules: xmlRules ?? this.xmlRules,
      messages: messages ?? this.messages,
      coverImageBase64: coverImageBase64 ?? this.coverImageBase64,
      hasRealCoverImage: hasRealCoverImage ?? this.hasRealCoverImage,
      enablePreprocessing: enablePreprocessing ?? this.enablePreprocessing,
      preprocessingPrompt: preprocessingPrompt ?? this.preprocessingPrompt,
      preprocessingApiConfigId: preprocessingApiConfigId ?? this.preprocessingApiConfigId,
      enableSecondaryXml: enableSecondaryXml ?? this.enableSecondaryXml,
      secondaryXmlPrompt: secondaryXmlPrompt ?? this.secondaryXmlPrompt,
      secondaryXmlApiConfigId: secondaryXmlApiConfigId ?? this.secondaryXmlApiConfigId,
      contextSummary: contextSummary ?? this.contextSummary,
      continuePrompt: continuePrompt ?? this.continuePrompt,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'systemPrompt': systemPrompt,
      'isFolder': isFolder,
      'apiConfigId': apiConfigId,
      'contextConfig': contextConfig.toJson(),
      'xmlRules': xmlRules.map((e) => e.toJson()).toList(),
      'messages': messages.map((e) => e.toJson()).toList(),
      'coverImageBase64': coverImageBase64,
      'enablePreprocessing': enablePreprocessing,
      'preprocessingPrompt': preprocessingPrompt,
      'preprocessingApiConfigId': preprocessingApiConfigId,
      'enableSecondaryXml': enableSecondaryXml,
      'secondaryXmlPrompt': secondaryXmlPrompt,
      'secondaryXmlApiConfigId': secondaryXmlApiConfigId,
      'contextSummary': contextSummary,
      'continuePrompt': continuePrompt,
      'hasRealCoverImage': hasRealCoverImage,
      // 将时间戳转换为 ISO 8601 字符串以便序列化
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'orderIndex': orderIndex, // 序列化排序信息
    };
  }

   @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatExportDto &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          systemPrompt == other.systemPrompt &&
          isFolder == other.isFolder &&
          apiConfigId == other.apiConfigId &&
          contextConfig == other.contextConfig &&
          listEquals(xmlRules, other.xmlRules) &&
          listEquals(messages, other.messages) &&
          coverImageBase64 == other.coverImageBase64 &&
          hasRealCoverImage == other.hasRealCoverImage &&
          enablePreprocessing == other.enablePreprocessing &&
          preprocessingPrompt == other.preprocessingPrompt &&
          preprocessingApiConfigId == other.preprocessingApiConfigId &&
          enableSecondaryXml == other.enableSecondaryXml &&
          secondaryXmlPrompt == other.secondaryXmlPrompt &&
          secondaryXmlApiConfigId == other.secondaryXmlApiConfigId &&
          contextSummary == other.contextSummary &&
          continuePrompt == other.continuePrompt;

  @override
  int get hashCode =>
      title.hashCode ^
      systemPrompt.hashCode ^
      isFolder.hashCode ^
      apiConfigId.hashCode ^
      contextConfig.hashCode ^
      xmlRules.hashCode ^
      messages.hashCode ^
      coverImageBase64.hashCode ^
      hasRealCoverImage.hashCode ^
      enablePreprocessing.hashCode ^
      preprocessingPrompt.hashCode ^
      preprocessingApiConfigId.hashCode ^
      enableSecondaryXml.hashCode ^
      secondaryXmlPrompt.hashCode ^
      secondaryXmlApiConfigId.hashCode ^
      contextSummary.hashCode ^
      continuePrompt.hashCode;
}

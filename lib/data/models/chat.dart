import 'package:flutter/foundation.dart';
import 'context_config.dart';
import 'xml_rule.dart';

/// 用于标识聊天模板的特殊时间戳。
/// 使用一个极早的时间来避免与真实的用户数据冲突。
final kTemplateTimestamp = DateTime.fromMicrosecondsSinceEpoch(0, isUtc: true);

@immutable
class Chat {
  final int id;
  final String? title;
  final String? systemPrompt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? coverImageBase64;
  final String? backgroundImagePath;
  final int? orderIndex;
  final bool isFolder;
  final int? parentFolderId;
  final String? apiConfigId;
  final ContextConfig contextConfig;
  final List<XmlRule> xmlRules;
  final bool enablePreprocessing;
  final String? preprocessingPrompt;
  final String? contextSummary;
  final String? preprocessingApiConfigId;
  final bool enableSecondaryXml;
  final String? secondaryXmlPrompt;
  final String? secondaryXmlApiConfigId;
  final String? continuePrompt;

  const Chat({
    this.id = 0,
    this.title,
    this.systemPrompt,
    required this.createdAt,
    required this.updatedAt,
    this.coverImageBase64,
    this.backgroundImagePath,
    this.orderIndex,
    this.isFolder = false,
    this.parentFolderId,
    this.apiConfigId,
    this.contextConfig = const ContextConfig(),
    this.xmlRules = const [],
    this.enablePreprocessing = false,
    this.preprocessingPrompt,
    this.contextSummary,
    this.preprocessingApiConfigId,
    this.enableSecondaryXml = false,
    this.secondaryXmlPrompt,
    this.secondaryXmlApiConfigId,
    this.continuePrompt,
  });

  Chat copyWith(Map<String, dynamic> changes) {
    // 允许通过传入 'key: null' 来将可选字段设置为空
    return Chat(
      id: changes['id'] as int? ?? id,
      title: changes.containsKey('title') ? changes['title'] as String? : title,
      systemPrompt: changes.containsKey('systemPrompt') ? changes['systemPrompt'] as String? : systemPrompt,
      createdAt: changes['createdAt'] as DateTime? ?? createdAt,
      updatedAt: changes['updatedAt'] as DateTime? ?? updatedAt,
      coverImageBase64: changes.containsKey('coverImageBase64') ? changes['coverImageBase64'] as String? : coverImageBase64,
      backgroundImagePath: changes.containsKey('backgroundImagePath') ? changes['backgroundImagePath'] as String? : backgroundImagePath,
      orderIndex: changes.containsKey('orderIndex') ? changes['orderIndex'] as int? : orderIndex,
      isFolder: changes['isFolder'] as bool? ?? isFolder,
      parentFolderId: changes.containsKey('parentFolderId') ? changes['parentFolderId'] as int? : parentFolderId,
      apiConfigId: changes.containsKey('apiConfigId') ? changes['apiConfigId'] as String? : apiConfigId,
      contextConfig: changes['contextConfig'] as ContextConfig? ?? contextConfig,
      xmlRules: changes['xmlRules'] as List<XmlRule>? ?? xmlRules,
      enablePreprocessing: changes['enablePreprocessing'] as bool? ?? enablePreprocessing,
      preprocessingPrompt: changes.containsKey('preprocessingPrompt') ? changes['preprocessingPrompt'] as String? : preprocessingPrompt,
      contextSummary: changes.containsKey('contextSummary') ? changes['contextSummary'] as String? : contextSummary,
      preprocessingApiConfigId: changes.containsKey('preprocessingApiConfigId') ? changes['preprocessingApiConfigId'] as String? : preprocessingApiConfigId,
      enableSecondaryXml: changes['enableSecondaryXml'] as bool? ?? enableSecondaryXml,
      secondaryXmlPrompt: changes.containsKey('secondaryXmlPrompt') ? changes['secondaryXmlPrompt'] as String? : secondaryXmlPrompt,
      secondaryXmlApiConfigId: changes.containsKey('secondaryXmlApiConfigId') ? changes['secondaryXmlApiConfigId'] as String? : secondaryXmlApiConfigId,
      continuePrompt: changes.containsKey('continuePrompt') ? changes['continuePrompt'] as String? : continuePrompt,
    );
  }
}
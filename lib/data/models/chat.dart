import 'package:flutter/foundation.dart';
import 'context_config.dart';
import 'xml_rule.dart';

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

  // A more robust copyWith that can differentiate between a field being absent
  // and a field being explicitly set to null.
  Chat copyWith(Map<String, dynamic> updates) {
    return Chat(
      id: updates.containsKey('id') ? updates['id'] : id,
      title: updates.containsKey('title') ? updates['title'] : title,
      systemPrompt: updates.containsKey('systemPrompt') ? updates['systemPrompt'] : systemPrompt,
      createdAt: updates.containsKey('createdAt') ? updates['createdAt'] : createdAt,
      updatedAt: updates.containsKey('updatedAt') ? updates['updatedAt'] : updatedAt,
      coverImageBase64: updates.containsKey('coverImageBase64') ? updates['coverImageBase64'] : coverImageBase64,
      backgroundImagePath: updates.containsKey('backgroundImagePath') ? updates['backgroundImagePath'] : backgroundImagePath,
      orderIndex: updates.containsKey('orderIndex') ? updates['orderIndex'] : orderIndex,
      isFolder: updates.containsKey('isFolder') ? updates['isFolder'] : isFolder,
      parentFolderId: updates.containsKey('parentFolderId') ? updates['parentFolderId'] : parentFolderId,
      apiConfigId: updates.containsKey('apiConfigId') ? updates['apiConfigId'] : apiConfigId,
      contextConfig: updates.containsKey('contextConfig') ? updates['contextConfig'] : contextConfig,
      xmlRules: updates.containsKey('xmlRules') ? updates['xmlRules'] : xmlRules,
      enablePreprocessing: updates.containsKey('enablePreprocessing') ? updates['enablePreprocessing'] : enablePreprocessing,
      preprocessingPrompt: updates.containsKey('preprocessingPrompt') ? updates['preprocessingPrompt'] : preprocessingPrompt,
      contextSummary: updates.containsKey('contextSummary') ? updates['contextSummary'] : contextSummary,
      preprocessingApiConfigId: updates.containsKey('preprocessingApiConfigId') ? updates['preprocessingApiConfigId'] : preprocessingApiConfigId,
      enableSecondaryXml: updates.containsKey('enableSecondaryXml') ? updates['enableSecondaryXml'] : enableSecondaryXml,
      secondaryXmlPrompt: updates.containsKey('secondaryXmlPrompt') ? updates['secondaryXmlPrompt'] : secondaryXmlPrompt,
      secondaryXmlApiConfigId: updates.containsKey('secondaryXmlApiConfigId') ? updates['secondaryXmlApiConfigId'] : secondaryXmlApiConfigId,
      continuePrompt: updates.containsKey('continuePrompt') ? updates['continuePrompt'] : continuePrompt,
    );
  }
}
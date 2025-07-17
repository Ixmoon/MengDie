import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';

import 'context_config.dart';
import 'message.dart';
import 'xml_rule.dart';
import '../enums.dart';

part 'chat.g.dart';

@JsonSerializable(explicitToJson: true)
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
  final bool enableHelpMeReply;
  final String? helpMeReplyPrompt;
  final String? helpMeReplyApiConfigId;
  final HelpMeReplyTriggerMode helpMeReplyTriggerMode;

  // Not part of the database, used for export/import
  @JsonKey(includeIfNull: false, defaultValue: [])
  final List<Message> messages;

  /// 如果背景图片路径包含 '/template'，则该聊天被视为模板。
  @JsonKey(includeFromJson: false, includeToJson: false)
  bool get isTemplate => backgroundImagePath?.contains('/template') ?? false;

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
    this.enableHelpMeReply = false,
    this.helpMeReplyPrompt,
    this.helpMeReplyApiConfigId,
    this.helpMeReplyTriggerMode = HelpMeReplyTriggerMode.manual,
    this.messages = const [],
  });

  Chat copyWith({
    int? id,
    String? title,
    String? systemPrompt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? coverImageBase64,
    String? backgroundImagePath,
    int? orderIndex,
    bool? isFolder,
    int? parentFolderId,
    String? apiConfigId,
    ContextConfig? contextConfig,
    List<XmlRule>? xmlRules,
    bool? enablePreprocessing,
    String? preprocessingPrompt,
    String? contextSummary,
    String? preprocessingApiConfigId,
    bool? enableSecondaryXml,
    String? secondaryXmlPrompt,
    String? secondaryXmlApiConfigId,
    String? continuePrompt,
    bool? enableHelpMeReply,
    String? helpMeReplyPrompt,
    String? helpMeReplyApiConfigId,
    HelpMeReplyTriggerMode? helpMeReplyTriggerMode,
    List<Message>? messages,
  }) {
    return Chat(
      id: id ?? this.id,
      title: title ?? this.title,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      coverImageBase64: coverImageBase64 ?? this.coverImageBase64,
      backgroundImagePath: backgroundImagePath ?? this.backgroundImagePath,
      orderIndex: orderIndex ?? this.orderIndex,
      isFolder: isFolder ?? this.isFolder,
      parentFolderId: parentFolderId ?? this.parentFolderId,
      apiConfigId: apiConfigId ?? this.apiConfigId,
      contextConfig: contextConfig ?? this.contextConfig,
      xmlRules: xmlRules ?? this.xmlRules,
      enablePreprocessing: enablePreprocessing ?? this.enablePreprocessing,
      preprocessingPrompt: preprocessingPrompt ?? this.preprocessingPrompt,
      contextSummary: contextSummary ?? this.contextSummary,
      preprocessingApiConfigId: preprocessingApiConfigId ?? this.preprocessingApiConfigId,
      enableSecondaryXml: enableSecondaryXml ?? this.enableSecondaryXml,
      secondaryXmlPrompt: secondaryXmlPrompt ?? this.secondaryXmlPrompt,
      secondaryXmlApiConfigId: secondaryXmlApiConfigId ?? this.secondaryXmlApiConfigId,
      continuePrompt: continuePrompt ?? this.continuePrompt,
      enableHelpMeReply: enableHelpMeReply ?? this.enableHelpMeReply,
      helpMeReplyPrompt: helpMeReplyPrompt ?? this.helpMeReplyPrompt,
      helpMeReplyApiConfigId: helpMeReplyApiConfigId ?? this.helpMeReplyApiConfigId,
      helpMeReplyTriggerMode: helpMeReplyTriggerMode ?? this.helpMeReplyTriggerMode,
      messages: messages ?? this.messages,
    );
  }

  factory Chat.fromJson(Map<String, dynamic> json) => _$ChatFromJson(json);

  Map<String, dynamic> toJson() => _$ChatToJson(this);
}
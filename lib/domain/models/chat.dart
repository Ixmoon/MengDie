import 'package:meta/meta.dart';
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
  final int? lastSummarizedMessageId;

  // Not part of the database, used for export/import
  @JsonKey(includeIfNull: false, defaultValue: [])
  final List<Message> messages;

  /// 如果背景图片路径包含 '/template'，则该聊天被视为模板。
  @JsonKey(includeFromJson: false, includeToJson: false)
  bool get isTemplate => backgroundImagePath?.contains('/template') ?? false;

  static const Object _sentinel = Object();

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
    this.xmlRules = const [
      XmlRule(
        tagName: 'think',
        action: XmlAction.collapsible,
        ignoreInContext: true,
      ),
      XmlRule(
        tagName: 'content',
        action: XmlAction.content,
        ignoreInContext: false,
      ),
    ],
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
    this.lastSummarizedMessageId,
  });

  Chat copyWith({
    int? id,
    Object? title = _sentinel,
    Object? systemPrompt = _sentinel,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? coverImageBase64 = _sentinel,
    Object? backgroundImagePath = _sentinel,
    Object? orderIndex = _sentinel,
    bool? isFolder,
    Object? parentFolderId = _sentinel,
    Object? apiConfigId = _sentinel,
    ContextConfig? contextConfig,
    List<XmlRule>? xmlRules,
    bool? enablePreprocessing,
    Object? preprocessingPrompt = _sentinel,
    Object? contextSummary = _sentinel,
    Object? preprocessingApiConfigId = _sentinel,
    bool? enableSecondaryXml,
    Object? secondaryXmlPrompt = _sentinel,
    Object? secondaryXmlApiConfigId = _sentinel,
    Object? continuePrompt = _sentinel,
    bool? enableHelpMeReply,
    Object? helpMeReplyPrompt = _sentinel,
    Object? helpMeReplyApiConfigId = _sentinel,
    HelpMeReplyTriggerMode? helpMeReplyTriggerMode,
    List<Message>? messages,
    Object? lastSummarizedMessageId = _sentinel,
  }) {
    return Chat(
      id: id ?? this.id,
      title: title == _sentinel ? this.title : title as String?,
      systemPrompt: systemPrompt == _sentinel
          ? this.systemPrompt
          : systemPrompt as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      coverImageBase64: coverImageBase64 == _sentinel
          ? this.coverImageBase64
          : coverImageBase64 as String?,
      backgroundImagePath: backgroundImagePath == _sentinel
          ? this.backgroundImagePath
          : backgroundImagePath as String?,
      orderIndex: orderIndex == _sentinel
          ? this.orderIndex
          : orderIndex as int?,
      isFolder: isFolder ?? this.isFolder,
      parentFolderId: parentFolderId == _sentinel
          ? this.parentFolderId
          : parentFolderId as int?,
      apiConfigId: apiConfigId == _sentinel
          ? this.apiConfigId
          : apiConfigId as String?,
      contextConfig: contextConfig ?? this.contextConfig,
      xmlRules: xmlRules ?? this.xmlRules,
      enablePreprocessing: enablePreprocessing ?? this.enablePreprocessing,
      preprocessingPrompt: preprocessingPrompt == _sentinel
          ? this.preprocessingPrompt
          : preprocessingPrompt as String?,
      contextSummary: contextSummary == _sentinel
          ? this.contextSummary
          : contextSummary as String?,
      preprocessingApiConfigId: preprocessingApiConfigId == _sentinel
          ? this.preprocessingApiConfigId
          : preprocessingApiConfigId as String?,
      enableSecondaryXml: enableSecondaryXml ?? this.enableSecondaryXml,
      secondaryXmlPrompt: secondaryXmlPrompt == _sentinel
          ? this.secondaryXmlPrompt
          : secondaryXmlPrompt as String?,
      secondaryXmlApiConfigId: secondaryXmlApiConfigId == _sentinel
          ? this.secondaryXmlApiConfigId
          : secondaryXmlApiConfigId as String?,
      continuePrompt: continuePrompt == _sentinel
          ? this.continuePrompt
          : continuePrompt as String?,
      enableHelpMeReply: enableHelpMeReply ?? this.enableHelpMeReply,
      helpMeReplyPrompt: helpMeReplyPrompt == _sentinel
          ? this.helpMeReplyPrompt
          : helpMeReplyPrompt as String?,
      helpMeReplyApiConfigId: helpMeReplyApiConfigId == _sentinel
          ? this.helpMeReplyApiConfigId
          : helpMeReplyApiConfigId as String?,
      helpMeReplyTriggerMode:
          helpMeReplyTriggerMode ?? this.helpMeReplyTriggerMode,
      messages: messages ?? this.messages,
      lastSummarizedMessageId:
          (contextSummary == _sentinel
                      ? this.contextSummary
                      : contextSummary as String?)
                  ?.isEmpty ??
              true
          ? null
          : (lastSummarizedMessageId == _sentinel
                ? this.lastSummarizedMessageId
                : lastSummarizedMessageId as int?),
    );
  }

  factory Chat.fromJson(Map<String, dynamic> json) => _$ChatFromJson(json);

  Map<String, dynamic> toJson() => _$ChatToJson(this);
}

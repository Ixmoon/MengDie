// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Chat _$ChatFromJson(Map<String, dynamic> json) => Chat(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String?,
      systemPrompt: json['systemPrompt'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      coverImageBase64: json['coverImageBase64'] as String?,
      backgroundImagePath: json['backgroundImagePath'] as String?,
      orderIndex: (json['orderIndex'] as num?)?.toInt(),
      isFolder: json['isFolder'] as bool? ?? false,
      parentFolderId: (json['parentFolderId'] as num?)?.toInt(),
      apiConfigId: json['apiConfigId'] as String?,
      contextConfig: json['contextConfig'] == null
          ? const ContextConfig()
          : ContextConfig.fromJson(
              json['contextConfig'] as Map<String, dynamic>),
      xmlRules: (json['xmlRules'] as List<dynamic>?)
              ?.map((e) => XmlRule.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      enablePreprocessing: json['enablePreprocessing'] as bool? ?? false,
      preprocessingPrompt: json['preprocessingPrompt'] as String?,
      contextSummary: json['contextSummary'] as String?,
      preprocessingApiConfigId: json['preprocessingApiConfigId'] as String?,
      enableSecondaryXml: json['enableSecondaryXml'] as bool? ?? false,
      secondaryXmlPrompt: json['secondaryXmlPrompt'] as String?,
      secondaryXmlApiConfigId: json['secondaryXmlApiConfigId'] as String?,
      continuePrompt: json['continuePrompt'] as String?,
      enableHelpMeReply: json['enableHelpMeReply'] as bool? ?? false,
      helpMeReplyPrompt: json['helpMeReplyPrompt'] as String?,
      helpMeReplyApiConfigId: json['helpMeReplyApiConfigId'] as String?,
      helpMeReplyTriggerMode: $enumDecodeNullable(
              _$HelpMeReplyTriggerModeEnumMap,
              json['helpMeReplyTriggerMode']) ??
          HelpMeReplyTriggerMode.manual,
      messages: (json['messages'] as List<dynamic>?)
              ?.map((e) => Message.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );

Map<String, dynamic> _$ChatToJson(Chat instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'systemPrompt': instance.systemPrompt,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'coverImageBase64': instance.coverImageBase64,
      'backgroundImagePath': instance.backgroundImagePath,
      'orderIndex': instance.orderIndex,
      'isFolder': instance.isFolder,
      'parentFolderId': instance.parentFolderId,
      'apiConfigId': instance.apiConfigId,
      'contextConfig': instance.contextConfig.toJson(),
      'xmlRules': instance.xmlRules.map((e) => e.toJson()).toList(),
      'enablePreprocessing': instance.enablePreprocessing,
      'preprocessingPrompt': instance.preprocessingPrompt,
      'contextSummary': instance.contextSummary,
      'preprocessingApiConfigId': instance.preprocessingApiConfigId,
      'enableSecondaryXml': instance.enableSecondaryXml,
      'secondaryXmlPrompt': instance.secondaryXmlPrompt,
      'secondaryXmlApiConfigId': instance.secondaryXmlApiConfigId,
      'continuePrompt': instance.continuePrompt,
      'enableHelpMeReply': instance.enableHelpMeReply,
      'helpMeReplyPrompt': instance.helpMeReplyPrompt,
      'helpMeReplyApiConfigId': instance.helpMeReplyApiConfigId,
      'helpMeReplyTriggerMode':
          _$HelpMeReplyTriggerModeEnumMap[instance.helpMeReplyTriggerMode]!,
      'messages': instance.messages.map((e) => e.toJson()).toList(),
    };

const _$HelpMeReplyTriggerModeEnumMap = {
  HelpMeReplyTriggerMode.manual: 'manual',
  HelpMeReplyTriggerMode.auto: 'auto',
};

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MessagePart _$MessagePartFromJson(Map<String, dynamic> json) => MessagePart(
      type: $enumDecode(_$MessagePartTypeEnumMap, json['type']),
      text: json['text'] as String?,
      mimeType: json['mimeType'] as String?,
      base64Data: json['base64Data'] as String?,
      fileName: json['fileName'] as String?,
    );

Map<String, dynamic> _$MessagePartToJson(MessagePart instance) =>
    <String, dynamic>{
      'type': _$MessagePartTypeEnumMap[instance.type]!,
      'text': instance.text,
      'mimeType': instance.mimeType,
      'base64Data': instance.base64Data,
      'fileName': instance.fileName,
    };

const _$MessagePartTypeEnumMap = {
  MessagePartType.text: 'text',
  MessagePartType.image: 'image',
  MessagePartType.file: 'file',
  MessagePartType.audio: 'audio',
  MessagePartType.generatedImage: 'generatedImage',
};

Message _$MessageFromJson(Map<String, dynamic> json) => Message(
      id: (json['id'] as num?)?.toInt() ?? 0,
      chatId: (json['chatId'] as num).toInt(),
      parts: (json['parts'] as List<dynamic>)
          .map((e) => MessagePart.fromJson(e as Map<String, dynamic>))
          .toList(),
      role: $enumDecode(_$MessageRoleEnumMap, json['role']),
      timestamp: json['timestamp'] == null
          ? null
          : DateTime.parse(json['timestamp'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      originalXmlContent: json['originalXmlContent'] as String?,
      secondaryXmlContent: json['secondaryXmlContent'] as String?,
    );

Map<String, dynamic> _$MessageToJson(Message instance) => <String, dynamic>{
      'id': instance.id,
      'chatId': instance.chatId,
      'parts': instance.parts.map((e) => e.toJson()).toList(),
      'role': _$MessageRoleEnumMap[instance.role]!,
      'timestamp': instance.timestamp.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'originalXmlContent': instance.originalXmlContent,
      'secondaryXmlContent': instance.secondaryXmlContent,
    };

const _$MessageRoleEnumMap = {
  MessageRole.user: 'user',
  MessageRole.model: 'model',
};

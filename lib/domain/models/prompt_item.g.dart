// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prompt_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PromptItem _$PromptItemFromJson(Map<String, dynamic> json) => PromptItem(
  id: json['id'] as String,
  status:
      $enumDecodeNullable(_$PromptItemStatusEnumMap, json['status']) ??
      PromptItemStatus.off,
  keyword: json['keyword'] as String? ?? '',
  text: json['text'] as String? ?? '',
  injectionRole:
      $enumDecodeNullable(_$MessageRoleEnumMap, json['injectionRole']) ??
      MessageRole.user,
  injectionPosition: (json['injectionPosition'] as num?)?.toInt() ?? 2,
  matchMessageCount: (json['matchMessageCount'] as num?)?.toInt() ?? 6,
  order: (json['order'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$PromptItemToJson(PromptItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'status': _$PromptItemStatusEnumMap[instance.status]!,
      'keyword': instance.keyword,
      'text': instance.text,
      'injectionRole': _$MessageRoleEnumMap[instance.injectionRole]!,
      'injectionPosition': instance.injectionPosition,
      'matchMessageCount': instance.matchMessageCount,
      'order': instance.order,
    };

const _$PromptItemStatusEnumMap = {
  PromptItemStatus.off: 'off',
  PromptItemStatus.on: 'on',
  PromptItemStatus.match: 'match',
  PromptItemStatus.insert: 'insert',
};

const _$MessageRoleEnumMap = {
  MessageRole.user: 'user',
  MessageRole.model: 'model',
};

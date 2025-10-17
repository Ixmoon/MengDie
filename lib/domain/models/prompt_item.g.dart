// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prompt_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PromptItem _$PromptItemFromJson(Map<String, dynamic> json) => PromptItem(
  id: json['id'] as String,
  type:
      $enumDecodeNullable(_$PromptItemTypeEnumMap, json['type']) ??
      PromptItemType.item,
  parentId: json['parentId'] as String?,
  status:
      $enumDecodeNullable(_$PromptItemStatusEnumMap, json['status']) ??
      PromptItemStatus.off,
  keyword: json['keyword'] as String? ?? '',
  text: json['text'] as String? ?? '',
  comment: json['comment'] as String? ?? '',
  injectionRole:
      $enumDecodeNullable(
        _$PromptInjectionRoleEnumMap,
        json['injectionRole'],
      ) ??
      PromptInjectionRole.user,
  injectionPosition: (json['injectionPosition'] as num?)?.toInt() ?? 2,
  matchMessageCount: (json['matchMessageCount'] as num?)?.toInt() ?? 6,
  injectionTag: json['injectionTag'] as String? ?? '',
  order: (json['order'] as num?)?.toInt() ?? 0,
  critical: json['critical'] as bool? ?? false,
);

Map<String, dynamic> _$PromptItemToJson(PromptItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$PromptItemTypeEnumMap[instance.type]!,
      'parentId': instance.parentId,
      'status': _$PromptItemStatusEnumMap[instance.status]!,
      'keyword': instance.keyword,
      'text': instance.text,
      'comment': instance.comment,
      'injectionRole': _$PromptInjectionRoleEnumMap[instance.injectionRole]!,
      'injectionPosition': instance.injectionPosition,
      'matchMessageCount': instance.matchMessageCount,
      'injectionTag': instance.injectionTag,
      'order': instance.order,
      'critical': instance.critical,
    };

const _$PromptItemTypeEnumMap = {
  PromptItemType.item: 'item',
  PromptItemType.folder: 'folder',
};

const _$PromptItemStatusEnumMap = {
  PromptItemStatus.off: 'off',
  PromptItemStatus.on: 'on',
  PromptItemStatus.match: 'match',
};

const _$PromptInjectionRoleEnumMap = {
  PromptInjectionRole.system: 'system',
  PromptInjectionRole.user: 'user',
  PromptInjectionRole.model: 'model',
};

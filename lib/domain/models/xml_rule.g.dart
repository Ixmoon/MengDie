// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'xml_rule.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

XmlRule _$XmlRuleFromJson(Map<String, dynamic> json) => XmlRule(
      tagName: json['tagName'] as String?,
      action: $enumDecodeNullable(_$XmlActionEnumMap, json['action']) ??
          XmlAction.ignore,
    );

Map<String, dynamic> _$XmlRuleToJson(XmlRule instance) => <String, dynamic>{
      'tagName': instance.tagName,
      'action': _$XmlActionEnumMap[instance.action]!,
    };

const _$XmlActionEnumMap = {
  XmlAction.save: 'save',
  XmlAction.update: 'update',
  XmlAction.ignore: 'ignore',
};

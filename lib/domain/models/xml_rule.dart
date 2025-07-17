import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';
import '../enums.dart';

part 'xml_rule.g.dart';

@JsonSerializable()
@immutable
class XmlRule {
  final String? tagName;
  final XmlAction action;

  const XmlRule({this.tagName, this.action = XmlAction.ignore});

  factory XmlRule.fromJson(Map<String, dynamic> json) {
    if (json['action'] is String) {
      final actionString = json['action'] as String;
      if (actionString.startsWith('XmlAction.')) {
        json['action'] = actionString.split('.').last;
      }
    }
    return _$XmlRuleFromJson(json);
  }

  Map<String, dynamic> toJson() => _$XmlRuleToJson(this);
}
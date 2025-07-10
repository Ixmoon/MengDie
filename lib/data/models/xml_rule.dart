import 'package:flutter/foundation.dart';
import 'enums.dart';

@immutable
class XmlRule {
  final String? tagName;
  final XmlAction action;

  const XmlRule({this.tagName, this.action = XmlAction.ignore});
}
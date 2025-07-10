import '../common_enums.dart';

class DriftXmlRule {
  String? tagName;
  XmlAction action;

  DriftXmlRule({this.tagName, this.action = XmlAction.ignore});

  factory DriftXmlRule.fromJson(Map<String, dynamic> json) {
    return DriftXmlRule(
      tagName: json['tagName'] as String?,
      action: XmlAction.values.firstWhere(
        (e) => e.toString() == json['action'],
        orElse: () => XmlAction.ignore,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tagName': tagName,
      'action': action.toString(),
    };
  }
}

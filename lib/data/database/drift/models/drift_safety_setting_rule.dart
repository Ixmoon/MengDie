import '../common_enums.dart';

class DriftSafetySettingRule {
  LocalHarmCategory category;
  LocalHarmBlockThreshold threshold;

  DriftSafetySettingRule({
    this.category = LocalHarmCategory.harassment,
    this.threshold = LocalHarmBlockThreshold.none,
  });

  factory DriftSafetySettingRule.fromJson(Map<String, dynamic> json) {
    return DriftSafetySettingRule(
      category: LocalHarmCategory.values.firstWhere(
        (e) => e.toString() == json['category'],
        orElse: () => LocalHarmCategory.unknown,
      ),
      threshold: LocalHarmBlockThreshold.values.firstWhere(
        (e) => e.toString() == json['threshold'],
        orElse: () => LocalHarmBlockThreshold.unspecified,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category.toString(),
      'threshold': threshold.toString(),
    };
  }
}

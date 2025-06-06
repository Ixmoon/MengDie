import 'drift_safety_setting_rule.dart';
import '../common_enums.dart'; // For default safety settings

class DriftGenerationConfig {
  String modelName;
  double? temperature;
  double? topP;
  int? topK;
  int? maxOutputTokens;
  List<String>? stopSequences;
  List<DriftSafetySettingRule> safetySettings;
  bool useCustomTemperature;
  bool useCustomTopP;
  bool useCustomTopK;

  DriftGenerationConfig({
    this.modelName = 'gemini-2.5-pro-exp-03-25',
    this.temperature,
    this.topP,
    this.topK,
    this.maxOutputTokens = 60000,
    this.stopSequences,
    List<DriftSafetySettingRule>? safetySettings,
    this.useCustomTemperature = false, // Default to false
    this.useCustomTopP = false,      // Default to false
    this.useCustomTopK = false,        // Default to false
  }) : safetySettings = safetySettings ?? _defaultSafetySettings();

  static List<DriftSafetySettingRule> _defaultSafetySettings() {
    return [
      DriftSafetySettingRule(category: LocalHarmCategory.harassment, threshold: LocalHarmBlockThreshold.none),
      DriftSafetySettingRule(category: LocalHarmCategory.hateSpeech, threshold: LocalHarmBlockThreshold.none),
      DriftSafetySettingRule(category: LocalHarmCategory.sexuallyExplicit, threshold: LocalHarmBlockThreshold.none),
      DriftSafetySettingRule(category: LocalHarmCategory.dangerousContent, threshold: LocalHarmBlockThreshold.none),
    ];
  }

  factory DriftGenerationConfig.fromJson(Map<String, dynamic> json) {
    return DriftGenerationConfig(
      modelName: json['modelName'] as String? ?? 'gemini-2.5-pro-exp-03-25',
      temperature: (json['temperature'] as num?)?.toDouble(),
      topP: (json['topP'] as num?)?.toDouble(),
      topK: json['topK'] as int?,
      maxOutputTokens: json['maxOutputTokens'] as int? ?? 60000,
      stopSequences: (json['stopSequences'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      safetySettings: (json['safetySettings'] as List<dynamic>?)
          ?.map((e) => DriftSafetySettingRule.fromJson(e as Map<String, dynamic>))
          .toList() ?? _defaultSafetySettings(),
      useCustomTemperature: json['useCustomTemperature'] as bool? ?? false,
      useCustomTopP: json['useCustomTopP'] as bool? ?? false,
      useCustomTopK: json['useCustomTopK'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'modelName': modelName,
      'temperature': temperature,
      'topP': topP,
      'topK': topK,
      'maxOutputTokens': maxOutputTokens,
      'stopSequences': stopSequences,
      'safetySettings': safetySettings.map((e) => e.toJson()).toList(),
      'useCustomTemperature': useCustomTemperature,
      'useCustomTopP': useCustomTopP,
      'useCustomTopK': useCustomTopK,
    };
  }
}

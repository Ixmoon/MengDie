import '../common_enums.dart';

class DriftContextConfig {
  ContextManagementMode mode;
  int maxTurns;
  int? maxContextTokens;

  DriftContextConfig({
    this.mode = ContextManagementMode.turns,
    this.maxTurns = 10,
    this.maxContextTokens,
  });

  factory DriftContextConfig.fromJson(Map<String, dynamic> json) {
    return DriftContextConfig(
      mode: ContextManagementMode.values.firstWhere(
        (e) => e.toString() == json['mode'],
        orElse: () => ContextManagementMode.turns,
      ),
      maxTurns: json['maxTurns'] as int? ?? 10,
      maxContextTokens: json['maxContextTokens'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode.toString(),
      'maxTurns': maxTurns,
      'maxContextTokens': maxContextTokens,
    };
  }
}

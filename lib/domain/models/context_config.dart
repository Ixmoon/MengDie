import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';
import '../enums.dart';

part 'context_config.g.dart';

@JsonSerializable()
@immutable
class ContextConfig {
  final ContextManagementMode mode;
  final int maxTurns;
  final int? maxContextTokens;

  const ContextConfig({
    this.mode = ContextManagementMode.turns,
    this.maxTurns = 10,
    this.maxContextTokens,
  });

  ContextConfig copyWith({
    ContextManagementMode? mode,
    int? maxTurns,
    int? maxContextTokens,
  }) {
    return ContextConfig(
      mode: mode ?? this.mode,
      maxTurns: maxTurns ?? this.maxTurns,
      maxContextTokens: maxContextTokens ?? this.maxContextTokens,
    );
  }

  factory ContextConfig.fromJson(Map<String, dynamic> json) {
    if (json['mode'] is String) {
      final modeString = json['mode'] as String;
      if (modeString.startsWith('ContextManagementMode.')) {
        json['mode'] = modeString.split('.').last;
      }
    }
    return _$ContextConfigFromJson(json);
  }

  Map<String, dynamic> toJson() => _$ContextConfigToJson(this);
}
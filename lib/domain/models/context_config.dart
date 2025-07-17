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

  factory ContextConfig.fromJson(Map<String, dynamic> json) => _$ContextConfigFromJson(json);

  Map<String, dynamic> toJson() => _$ContextConfigToJson(this);
}
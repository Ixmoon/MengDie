import 'package:flutter/foundation.dart';
import 'enums.dart';

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
}
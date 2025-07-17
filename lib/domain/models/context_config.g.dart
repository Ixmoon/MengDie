// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'context_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ContextConfig _$ContextConfigFromJson(Map<String, dynamic> json) =>
    ContextConfig(
      mode: $enumDecodeNullable(_$ContextManagementModeEnumMap, json['mode']) ??
          ContextManagementMode.turns,
      maxTurns: (json['maxTurns'] as num?)?.toInt() ?? 10,
      maxContextTokens: (json['maxContextTokens'] as num?)?.toInt(),
    );

Map<String, dynamic> _$ContextConfigToJson(ContextConfig instance) =>
    <String, dynamic>{
      'mode': _$ContextManagementModeEnumMap[instance.mode]!,
      'maxTurns': instance.maxTurns,
      'maxContextTokens': instance.maxContextTokens,
    };

const _$ContextManagementModeEnumMap = {
  ContextManagementMode.turns: 'turns',
  ContextManagementMode.tokens: 'tokens',
};

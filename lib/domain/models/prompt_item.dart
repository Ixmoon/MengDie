import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';
import '../enums.dart';

part 'prompt_item.g.dart';

enum PromptItemStatus { off, on, match, insert }

@JsonSerializable()
@immutable
class PromptItem {
  final String id;
  final PromptItemStatus status;
  final String keyword;
  final String text;
  final MessageRole injectionRole;
  final int injectionPosition;
  final int matchMessageCount;

  const PromptItem({
    required this.id,
    this.status = PromptItemStatus.off,
    this.keyword = '',
    this.text = '',
    this.injectionRole = MessageRole.user,
    this.injectionPosition = 2,
    this.matchMessageCount = 6,
  });

  factory PromptItem.fromJson(Map<String, dynamic> json) =>
      _$PromptItemFromJson(json);

  Map<String, dynamic> toJson() => _$PromptItemToJson(this);

  PromptItem copyWith({
    String? id,
    PromptItemStatus? status,
    String? keyword,
    String? text,
    MessageRole? injectionRole,
    int? injectionPosition,
    int? matchMessageCount,
  }) {
    return PromptItem(
      id: id ?? this.id,
      status: status ?? this.status,
      keyword: keyword ?? this.keyword,
      text: text ?? this.text,
      injectionRole: injectionRole ?? this.injectionRole,
      injectionPosition: injectionPosition ?? this.injectionPosition,
      matchMessageCount: matchMessageCount ?? this.matchMessageCount,
    );
  }
}

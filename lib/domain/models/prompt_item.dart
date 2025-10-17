import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';
import '../enums.dart';

part 'prompt_item.g.dart';

enum PromptItemStatus { off, on, match }

enum PromptItemType { item, folder }

@JsonSerializable()
@immutable
class PromptItem {
  final String id;
  final PromptItemType type;
  final String? parentId;
  final PromptItemStatus status;
  final String keyword;
  final String text;
  final String comment; // New field for the display name
  final PromptInjectionRole injectionRole;
  final int injectionPosition;
  final int matchMessageCount;
  final String injectionTag; // New field for the XML tag
  final int order;
  final bool critical;
  @JsonKey(includeFromJson: false, includeToJson: false)
  final bool isGlobal;

  const PromptItem({
    required this.id,
    this.type = PromptItemType.item,
    this.parentId,
    this.status = PromptItemStatus.off,
    this.keyword = '',
    this.text = '',
    this.comment = '',
    this.injectionRole = PromptInjectionRole.user,
    this.injectionPosition = 2,
    this.matchMessageCount = 6,
    this.injectionTag = '', // Default to empty string
    this.order = 0,
    this.critical = false,
    this.isGlobal = false,
  });

  factory PromptItem.fromJson(Map<String, dynamic> json) =>
      _$PromptItemFromJson(json);

  Map<String, dynamic> toJson() => _$PromptItemToJson(this);

  PromptItem copyWith({
    String? id,
    PromptItemType? type,
    String? parentId,
    bool? setParentIdToNull,
    PromptItemStatus? status,
    String? keyword,
    String? text,
    String? comment,
    PromptInjectionRole? injectionRole,
    int? injectionPosition,
    int? matchMessageCount,
    String? injectionTag,
    int? order,
    bool? critical,
    bool? isGlobal,
  }) {
    return PromptItem(
      id: id ?? this.id,
      type: type ?? this.type,
      parentId: setParentIdToNull == true ? null : parentId ?? this.parentId,
      status: status ?? this.status,
      keyword: keyword ?? this.keyword,
      text: text ?? this.text,
      comment: comment ?? this.comment,
      injectionRole: injectionRole ?? this.injectionRole,
      injectionPosition: injectionPosition ?? this.injectionPosition,
      matchMessageCount: matchMessageCount ?? this.matchMessageCount,
      injectionTag: injectionTag ?? this.injectionTag,
      order: order ?? this.order,
      critical: critical ?? this.critical,
      isGlobal: isGlobal ?? this.isGlobal,
    );
  }

}

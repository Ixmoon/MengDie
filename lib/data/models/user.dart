import 'package:flutter/foundation.dart';

import 'app_constants.dart';

/// 用户数据模型
///
/// 代表一个应用用户，包含其凭证、拥有的聊天列表以及个人设置。
@immutable
class User {
  /// 用户的唯一ID。
  final int id;

  /// 用于数据同步的全局唯一标识符。
  final String uuid;

  /// 记录创建时间的时间戳。
  final DateTime createdAt;

  /// 记录最后更新时间的时间戳。
  final DateTime updatedAt;

  /// 用户名。
  final String username;

  /// 存储密码的哈希值，而不是明文密码。
  final String passwordHash;

  /// 该用户拥有的所有聊天会话的ID列表。
  final List<int> chatIds;

  // --- 全局设置 ---

  /// 是否启用自动生成聊天标题。
  final bool enableAutoTitleGeneration;

  /// 自动生成标题时使用的提示词。
  final String titleGenerationPrompt;

  /// 自动生成标题时使用的 API 配置 ID。
  final String? titleGenerationApiConfigId;

  /// 是否启用中断恢复功能。
  final bool enableResume;

  /// 中断恢复时使用的提示词。
  final String resumePrompt;

  /// 中断恢复时使用的 API 配置 ID。
  final String? resumeApiConfigId;

  /// 与此用户绑定的 Gemini API 密钥列表。
  final List<String> geminiApiKeys;

  const User({
    required this.id,
    required this.uuid,
    required this.createdAt,
    required this.updatedAt,
    required this.username,
    required this.passwordHash,
    required this.chatIds,
    this.enableAutoTitleGeneration = false,
    this.titleGenerationPrompt = defaultTitleGenerationPrompt,
    this.titleGenerationApiConfigId,
    this.enableResume = false,
    this.resumePrompt = defaultResumePrompt,
    this.resumeApiConfigId,
    this.geminiApiKeys = const [],
  });

  /// 创建一个具有默认设置的游客用户实例。
  ///
  /// 此工厂构造函数用于在游客模式下提供一个临时的 User 对象。
  /// 它使用一个特殊的ID（通常为0）来标识游客，并且不包含敏感信息（如密码哈希）。
  /// 所有设置都采用应用程序定义的默认值。
  factory User.guest() {
    return User(
      id: 0, // 使用 0 作为游客的特殊ID
      uuid: '00000000-0000-0000-0000-000000000000', // 游客使用固定的UUID
      createdAt: DateTime(2000), // 使用一个固定的旧时间
      updatedAt: DateTime(2000),
      username: 'Guest',
      passwordHash: '', // 游客没有密码
      chatIds: [], // 游客没有持久化的聊天记录
      // 所有设置均使用默认值
      enableAutoTitleGeneration: false,
      titleGenerationPrompt: defaultTitleGenerationPrompt,
      titleGenerationApiConfigId: null,
      enableResume: false,
      resumePrompt: defaultResumePrompt,
      resumeApiConfigId: null,
      geminiApiKeys: [],
    );
  }

  /// 判断此用户实例是否为游客。
  bool get isGuestMode => id == 0;

  User copyWith({
    int? id,
    String? uuid,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? username,
    String? passwordHash,
    List<int>? chatIds,
    List<String>? geminiApiKeys,
    bool? enableAutoTitleGeneration,
    String? titleGenerationPrompt,
    String? titleGenerationApiConfigId,
    bool? enableResume,
    String? resumePrompt,
    String? resumeApiConfigId,
    bool clearTitleGenerationApiConfigId = false,
    bool clearResumeApiConfigId = false,
  }) {
    return User(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      chatIds: chatIds ?? this.chatIds,
      geminiApiKeys: geminiApiKeys ?? this.geminiApiKeys,
      enableAutoTitleGeneration: enableAutoTitleGeneration ?? this.enableAutoTitleGeneration,
      titleGenerationPrompt: titleGenerationPrompt ?? this.titleGenerationPrompt,
      titleGenerationApiConfigId: clearTitleGenerationApiConfigId ? null : titleGenerationApiConfigId ?? this.titleGenerationApiConfigId,
      enableResume: enableResume ?? this.enableResume,
      resumePrompt: resumePrompt ?? this.resumePrompt,
      resumeApiConfigId: clearResumeApiConfigId ? null : resumeApiConfigId ?? this.resumeApiConfigId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          uuid == other.uuid &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          username == other.username &&
          passwordHash == other.passwordHash &&
          listEquals(chatIds, other.chatIds) &&
          enableAutoTitleGeneration == other.enableAutoTitleGeneration &&
          titleGenerationPrompt == other.titleGenerationPrompt &&
          titleGenerationApiConfigId == other.titleGenerationApiConfigId &&
          enableResume == other.enableResume &&
          resumePrompt == other.resumePrompt &&
          resumeApiConfigId == other.resumeApiConfigId &&
          listEquals(geminiApiKeys, other.geminiApiKeys);

  @override
  int get hashCode =>
      id.hashCode ^
      uuid.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode ^
      username.hashCode ^
      passwordHash.hashCode ^
      chatIds.hashCode ^
      enableAutoTitleGeneration.hashCode ^
      titleGenerationPrompt.hashCode ^
      titleGenerationApiConfigId.hashCode ^
      enableResume.hashCode ^
      resumePrompt.hashCode ^
      resumeApiConfigId.hashCode ^
      geminiApiKeys.hashCode;

  @override
  String toString() {
    return 'User{id: $id, username: $username, chatIds: ${chatIds.length} chats, settings: ...}';
  }
}
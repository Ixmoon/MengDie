import '../database/app_database.dart';
import '../models/user.dart';

/// 用户数据映射器
///
/// 提供静态方法，用于在数据库实体 (DriftUser) 和应用数据模型 (User) 之间进行转换。
class UserMapper {
  /// 将数据库实体 [DriftUser] 转换为应用数据模型 [User]。
  static User fromDrift(DriftUser driftUser) {
    return User(
      id: driftUser.id,
      username: driftUser.username,
      passwordHash: driftUser.passwordHash,
      chatIds: driftUser.chatIds ?? [],
      // 映射设置字段
      enableAutoTitleGeneration: driftUser.enableAutoTitleGeneration ?? false,
      titleGenerationPrompt: driftUser.titleGenerationPrompt ?? '',
      titleGenerationApiConfigId: driftUser.titleGenerationApiConfigId,
      enableResume: driftUser.enableResume ?? false,
      resumePrompt: driftUser.resumePrompt ?? '',
      resumeApiConfigId: driftUser.resumeApiConfigId,
      geminiApiKeys: driftUser.geminiApiKeys ?? [],
    );
  }

  /// 将应用数据模型 [User] 转换为数据库实体 [DriftUser]。
  ///
  /// 注意：通常在插入或更新数据时，我们更倾向于使用 Drift 的 `Companion` 对象，
  /// 因为它能更好地处理默认值和部分更新。这个方法主要用于需要完整实体对象的场景。
  static DriftUser toDrift(User user) {
    return DriftUser(
      id: user.id,
      username: user.username,
      passwordHash: user.passwordHash,
      chatIds: user.chatIds,
      // 映射设置字段
      enableAutoTitleGeneration: user.enableAutoTitleGeneration,
      titleGenerationPrompt: user.titleGenerationPrompt,
      titleGenerationApiConfigId: user.titleGenerationApiConfigId,
      enableResume: user.enableResume,
      resumePrompt: user.resumePrompt,
      resumeApiConfigId: user.resumeApiConfigId,
      geminiApiKeys: user.geminiApiKeys,
    );
  }
}
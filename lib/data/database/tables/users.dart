import 'package:drift/drift.dart';

import '../type_converters.dart';

/// 用户表
///
/// 用于存储应用的用户信息，包括登录凭证、他们所拥有的聊天记录以及个性化设置。
@DataClassName('DriftUser')
class Users extends Table {
  /// 用户的唯一ID，自增主键。
  IntColumn get id => integer().autoIncrement()();

  /// 用户名，必须是唯一的。
  TextColumn get username => text().unique()();

  /// 存储密码的哈希值。
  TextColumn get passwordHash => text()();

  /// 存储用户拥有的聊天ID列表。
  /// 使用自定义的 TypeConverter 将 List<int> 转换为 String 进行存储。
  TextColumn get chatIds => text().map(const IntListConverter()).nullable()();

  // --- 全局设置 ---

  /// 是否启用自动生成聊天标题。
  BoolColumn get enableAutoTitleGeneration => boolean().nullable()();

  /// 自动生成标题时使用的提示词。
  TextColumn get titleGenerationPrompt => text().nullable()();

  /// 自动生成标题时使用的 API 配置 ID。
  TextColumn get titleGenerationApiConfigId => text().nullable()();

  /// 是否启用中断恢复功能。
  BoolColumn get enableResume => boolean().nullable()();

  /// 中断恢复时使用的提示词。
  TextColumn get resumePrompt => text().nullable()();

  /// 中断恢复时使用的 API 配置 ID。
  TextColumn get resumeApiConfigId => text().nullable()();

  /// Gemini API 密钥列表
  TextColumn get geminiApiKeys => text().map(const StringListConverter()).nullable()();
}

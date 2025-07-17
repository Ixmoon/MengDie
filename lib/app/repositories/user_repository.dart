import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/database/app_database.dart';
import '../../data/database/daos/user_dao.dart';
import '../../data/mappers/user_mapper.dart';
import '../../domain/models/user.dart';
import '../providers/auth_providers.dart';
import '../../data/sync/sync_service.dart';

/// 用户仓库
///
/// 封装了所有与用户相关的业务逻辑，如用户创建、认证、数据更新和登录状态持久化。
class UserRepository {
  final Ref _ref;
  final UserDao _userDao;

  // SharedPreferences 中用于存储最后登录用户ID的键。
  static const String _lastLoggedInUserIdKey = 'last_logged_in_user_id';

  UserRepository(this._ref, this._userDao);

  /// 密码哈希处理
  String _hashPassword(String password) {
    final bytes = utf8.encode(password); // data being hashed
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// 验证用户凭证
  ///
  /// [username] 用户名。
  /// [password] 密码。
  /// 如果凭证有效，返回 [User] 对象，否则返回 null。
  Future<User?> authenticate(String username, String password) async {
    final driftUser = await _userDao.getUserByUsername(username);
    if (driftUser == null) {
      return null;
    }

    final hashedPassword = _hashPassword(password);
    if (driftUser.passwordHash == hashedPassword) {
      return UserMapper.fromDrift(driftUser);
    }

    return null;
  }
  
  /// 根据ID获取用户
  Future<User?> getUserById(int userId) async {
    final driftUser = await _userDao.getUserById(userId);
    if (driftUser != null) {
      return UserMapper.fromDrift(driftUser);
    }
    return null;
  }

  /// 创建一个新用户
  ///
  /// [username] 用户名。
  /// [password] 密码。
  /// 如果用户名已存在，将抛出异常。
  /// 成功创建后返回新的 [User] 对象。
  Future<User> createUser(String username, String password, {int? id}) async {
    // 如果提供了ID，则直接使用。否则，检查用户名是否存在。
    if (id == null) {
      final existingUser = await _userDao.getUserByUsername(username);
      if (existingUser != null) {
        throw Exception('Username already exists');
      }
    }

    final hashedPassword = _hashPassword(password);
    final newUserCompanion = UsersCompanion(
      id: id != null ? Value(id) : const Value.absent(),
      username: Value(username),
      passwordHash: Value(hashedPassword),
      updatedAt: Value(DateTime.now()), // Set initial timestamp
      // 新用户从一个空的聊天列表开始
      chatIds: const Value([]),
      // 使用默认设置
      enableAutoTitleGeneration: const Value(false),
      titleGenerationPrompt: const Value('根据对话，为本次聊天生成一个简洁的、不超过10个字的标题。（你的回复内容只能是纯标题，不能包含任何其他内容）'),
      enableResume: const Value(false),
      resumePrompt: const Value('继续生成被中断的回复，请直接从最后一个字甚至是符号后继续，不要包含任何其他内容。'),
      geminiApiKeys: const Value([]), // Provide default empty list
    );

    final driftUser = await _userDao.db.into(_userDao.db.users).insertReturning(newUserCompanion, mode: InsertMode.insertOrReplace);
    
    return UserMapper.fromDrift(driftUser);
  }

  /// 获取或创建游客用户（ID为0）。
  ///
  /// 此方法确保系统中始终存在一个用于游客模式的、可持久化的用户记录。
  Future<User> getOrCreateGuestUser() async {
    final guestDriftUser = await _userDao.getUserById(0);
    if (guestDriftUser != null) {
      return UserMapper.fromDrift(guestDriftUser);
    } else {
      // 如果ID为0的用户不存在，则创建一个
      // 注意：密码字段为空字符串，因为游客不需要登录
      return await createUser('guest_user_placeholder', '', id: 0);
    }
  }

  /// 将一个聊天ID添加给指定用户
  ///
  /// [userId] 用户的ID。
  /// [chatId] 要添加的聊天的ID。
  Future<void> addChatIdToUser(int userId, int chatId) async {
    // 统一逻辑：先获取安全的领域模型 User
    final user = await getUserById(userId);
    if (user == null) {
      throw Exception('User not found');
    }

    if (!user.chatIds.contains(chatId)) {
      final updatedChatIds = List<int>.from(user.chatIds)..add(chatId);
      // 统一调用更新方法，确保状态刷新
      await updateUserSettings(user.copyWith(chatIds: updatedChatIds));
    }
  }

  /// 从指定用户移除一个聊天ID
  ///
  /// [userId] 用户的ID。
  /// [chatId] 要移除的聊天的ID。
  Future<void> removeChatIdFromUser(int userId, int chatId) async {
    // 统一逻辑：先获取安全的领域模型 User
    final user = await getUserById(userId);
    if (user == null) {
      throw Exception('User not found');
    }

    if (user.chatIds.contains(chatId)) {
      final updatedChatIds = List<int>.from(user.chatIds)..remove(chatId);
      // 统一调用更新方法，确保状态刷新
      await updateUserSettings(user.copyWith(chatIds: updatedChatIds));
    }
  }

  /// 更新指定用户的设置
  ///
  /// [user] 包含最新设置的 User 对象。
  Future<void> updateUserSettings(User user) async {
    // Convert to companion to allow DAO to handle the `updatedAt` timestamp.
    final companion = UserMapper.toDrift(user).toCompanion(false);
    await _userDao.saveUser(companion);
    // 更新数据库后，刷新 AuthProvider 中的状态，以确保UI反映最新设置
    await _ref.read(authProvider.notifier).refreshCurrentUserState();
  }

  /// 将最后登录的用户ID保存到 SharedPreferences。
  Future<void> saveLastLoggedInUserId(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastLoggedInUserIdKey, userId);
  }

  /// 从 SharedPreferences 获取最后登录的用户ID。
  ///
  /// 如果没有找到ID，则返回 null。
  Future<int?> getLastLoggedInUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lastLoggedInUserIdKey);
  }

  /// 从 SharedPreferences 清除最后登录的用户ID。
  Future<void> clearLastLoggedInUserId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastLoggedInUserIdKey);
  }
}
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user.dart';
import 'repository_providers.dart';

/// 认证状态
///
/// 代表当前用户的认证信息。
class AuthState {
  /// 当前登录的用户。如果为 null，则表示用户未登录或处于游客模式。
  final User? currentUser;

  /// 指示当前是否为游客模式。
  final bool isGuestMode;

  const AuthState({this.currentUser, this.isGuestMode = false});

  /// 创建一个表示游客模式的初始状态。
  factory AuthState.initial() => const AuthState(isGuestMode: false, currentUser: null);
}

/// 认证状态通知器
///
/// 管理应用的认证逻辑，如登录、登出和注册。
class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;

  AuthNotifier(this._ref) : super(AuthState.initial());

  /// 用户登录
  ///
  /// [username] 用户名。
  /// [password] 密码。
  /// 成功登录后更新状态，失败则抛出异常。
  /// 尝试自动登录
  ///
  /// 在应用启动时调用，检查是否存在最后登录的用户。
  Future<void> tryAutoLogin() async {
    final lastUserId = await _ref.read(userRepositoryProvider).getLastLoggedInUserId();
    if (lastUserId != null) {
      final user = await _ref.read(userRepositoryProvider).getUserById(lastUserId);
      if (user != null) {
        state = AuthState(currentUser: user, isGuestMode: user.id == 0);
      }
    }
    // 如果没有保存的用户ID，或者找不到用户，状态将保持 initial，
    // UI 将停留在登录页面。
  }

  /// 用户登录
  ///
  /// [username] 用户名。
  /// [password] 密码。
  /// 成功登录后更新状态，失败则抛出异常。
  Future<void> login(String username, String password) async {
    final user = await _ref.read(userRepositoryProvider).authenticate(username, password);
    if (user != null) {
      state = AuthState(currentUser: user, isGuestMode: false);
      await _ref.read(userRepositoryProvider).saveLastLoggedInUserId(user.id);
    } else {
      throw Exception('Invalid username or password');
    }
  }

  /// 用户登出
  ///
  /// 将状态重置为初始未认证状态。UI应监听此状态变化并导航到登录页。
  /// 用户登出
  ///
  /// 将状态重置为初始未认证状态，并清除持久化的用户ID。
  /// UI应监听此状态变化并导航到登录页。
  Future<void> logout() async {
    await _ref.read(userRepositoryProvider).clearLastLoggedInUserId();
    state = AuthState.initial();
    // 登出后，我们希望用户停留在登录页，而不是自动进入游客模式。
    // 因此，这里不需要调用 switchToGuestMode()。
  }

  /// 切换到游客模式
  ///
  /// 这个方法会尝试加载游客用户，并更新状态。
  /// 它与 `logout` 是分开的，因为登出后我们希望有一个明确的“未认证”状态，
  /// 而不是直接跳回到游客模式。
  Future<void> switchToGuestMode() async {
    // 切换前，确保我们不是在一个有效的用户会话中
    if (state.currentUser != null && !state.isGuestMode) {
      // 这是一个不应该发生的情况，但作为安全措施
      state = AuthState.initial();
    }
    await enterGuestMode();
  }

  /// 注册新用户
  ///
  /// [username] 用户名。
  /// [password] 密码。
  /// 成功注册后，自动为新用户登录。
  /// 注册新用户
  ///
  /// [username] 用户名。
  /// [password] 密码。
  /// 成功注册后，自动为新用户登录，并持久化其ID。
  Future<void> register(String username, String password) async {
    final newUser = await _ref.read(userRepositoryProvider).createUser(username, password);
    state = AuthState(currentUser: newUser, isGuestMode: false);
    await _ref.read(userRepositoryProvider).saveLastLoggedInUserId(newUser.id);
  }

  /// 进入游客模式
  ///
  /// 从数据库加载或创建 ID 为 0 的游客用户，并将其设为当前用户。
  /// 进入游客模式
  ///
  /// 从数据库加载或创建 ID 为 0 的游客用户，并将其设为当前用户，同时持久化其ID。
  Future<void> enterGuestMode() async {
    final guestUser = await _ref.read(userRepositoryProvider).getOrCreateGuestUser();
    state = AuthState(currentUser: guestUser, isGuestMode: true);
    await _ref.read(userRepositoryProvider).saveLastLoggedInUserId(guestUser.id);
  }

  /// 从数据库刷新当前用户的状态
  ///
  /// 这在用户信息（如聊天列表）在后台被更新后，
  /// 用来确保UI状态与数据库保持同步。
  Future<void> refreshCurrentUserState() async {
    if (state.currentUser != null) {
      final updatedUser = await _ref.read(userRepositoryProvider).getUserById(state.currentUser!.id);
      if (updatedUser != null) {
        state = AuthState(currentUser: updatedUser, isGuestMode: updatedUser.id == 0);
      }
    }
  }
}

/// 全局认证状态提供者
///
/// 提供一个 [AuthNotifier] 实例，用于在整个应用中访问和管理认证状态。
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
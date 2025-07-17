import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/enums.dart';
import '../../domain/models/user.dart';
import 'auth_providers.dart';
import 'repository_providers.dart';

// 本文件提供应用中与设置相关的 Provider。
//
// 主要分为两部分：
// 1. ThemeModeNotifier: 管理应用的主题（浅色、深色、跟随系统），并将其持久化到 SharedPreferences。
//    这是一个独立于用户的设备级设置。
// 2. GlobalSettings Provider: 管理所有与用户账户绑定的全局设置。
//    这些设置从当前登录用户的数据库记录中加载，并在修改后写回数据库。
//    对于游客模式，它会提供一套临时的默认设置。


// --- 同步设置 (设备级) ---

const String _syncEnabledKey = 'sync_enabled';
const String _syncConnectionStringKey = 'sync_connection_string';

/// 同步设置的状态模型
class SyncSettings {
  final bool isEnabled;
  final String connectionString;

  SyncSettings({this.isEnabled = false, this.connectionString = ''});

  SyncSettings copyWith({
    bool? isEnabled,
    String? connectionString,
  }) {
    return SyncSettings(
      isEnabled: isEnabled ?? this.isEnabled,
      connectionString: connectionString ?? this.connectionString,
    );
  }
}

/// 管理和持久化同步设置的 Notifier
class SyncSettingsNotifier extends StateNotifier<SyncSettings> {
  late final SharedPreferences? _prefs;

  SyncSettingsNotifier() : super(SyncSettings());

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final isEnabled = _prefs?.getBool(_syncEnabledKey) ?? false;
    final connectionString = _prefs?.getString(_syncConnectionStringKey) ?? '';
    state = SyncSettings(isEnabled: isEnabled, connectionString: connectionString);
  }

  Future<void> updateSettings(SyncSettings newSettings) async {
    state = newSettings;
    await _prefs?.setBool(_syncEnabledKey, newSettings.isEnabled);
    await _prefs?.setString(_syncConnectionStringKey, newSettings.connectionString);
  }
}

/// 提供 SyncSettingsNotifier 实例的全局 Provider
final syncSettingsProvider = StateNotifierProvider<SyncSettingsNotifier, SyncSettings>((ref) {
  return SyncSettingsNotifier();
});


// --- 主题设置 (设备级) ---

const String _themeModeKey = 'app_theme_mode'; // SharedPreferences Key

/// 管理和持久化应用主题的 Notifier。
class ThemeModeNotifier extends StateNotifier<ThemeModeSetting> {
  late final SharedPreferences? _prefs;

  ThemeModeNotifier() : super(ThemeModeSetting.system);

  /// 异步初始化，加载 SharedPreferences 并读取已存的主题设置。
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadThemeMode();
  }

  void _loadThemeMode() {
    final prefs = _prefs;
    if (prefs == null) return;

    final themeModeString = prefs.getString(_themeModeKey);
    if (themeModeString != null) {
      try {
        state = ThemeModeSetting.values.firstWhere((e) => e.toString() == themeModeString);
      } catch (e) {
        state = ThemeModeSetting.system;
      }
    } else {
      state = ThemeModeSetting.system;
    }
  }

  /// 更新主题设置并将其持久化到 SharedPreferences。
  Future<void> setThemeMode(ThemeModeSetting newMode) async {
    if (state != newMode) {
      state = newMode;
      final prefs = _prefs;
      if (prefs != null) {
        await prefs.setString(_themeModeKey, newMode.toString());
      }
    }
  }
}

/// 提供 ThemeModeNotifier 实例的全局 Provider。
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeModeSetting>((ref) {
  return ThemeModeNotifier();
});


// --- 全局应用设置 (用户级) ---

/// 从当前认证状态派生出全局设置。
///
/// 这个 Provider 监听 `authProvider`。
/// - 如果用户已登录，它会提供该用户的设置。
/// - 如果是游客模式，它会提供一个临时的、默认的设置实例。
///
/// 这种设计将设置与用户状态紧密绑定，取代了之前基于 SharedPreferences 的实现。
final globalSettingsProvider = Provider<User>((ref) {
  // 监听 authProvider 的状态
  final authState = ref.watch(authProvider);

  // 如果有当前登录的用户，则返回该用户的设置
  if (authState.currentUser != null) {
    return authState.currentUser!;
  }
  
  // 如果是游客模式或用户未登录，返回一个临时的游客用户实例
  return User.guest();
});

/// 全局设置操作的封装
///
/// 这个 Provider 提供了一个方便的接口来更新当前用户的全局设置。
/// 它内部封装了与 UserRepository 的交互逻辑。
final globalSettingsActionsProvider = Provider((ref) {
  return GlobalSettingsActions(ref);
});

class GlobalSettingsActions {
  final Ref _ref;

  GlobalSettingsActions(this._ref);

  /// 更新当前登录用户的设置。
  ///
  /// [newSettings] 包含更新后字段的 User 对象。
  /// 如果当前是游客模式，此操作将不执行任何数据库写入。
  Future<void> updateSettings(User newSettings) async {
    final userRepo = _ref.read(userRepositoryProvider);
    final currentUser = _ref.read(authProvider).currentUser;

    // 仅当用户登录时才执行更新
    if (currentUser != null) {
      // 确保我们是基于最新的用户状态进行更新
      final updatedUser = currentUser.copyWith(
        enableAutoTitleGeneration: newSettings.enableAutoTitleGeneration,
        titleGenerationPrompt: newSettings.titleGenerationPrompt,
        titleGenerationApiConfigId: newSettings.titleGenerationApiConfigId,
        clearTitleGenerationApiConfigId: newSettings.titleGenerationApiConfigId == null,
        enableResume: newSettings.enableResume,
        resumePrompt: newSettings.resumePrompt,
        resumeApiConfigId: newSettings.resumeApiConfigId,
        clearResumeApiConfigId: newSettings.resumeApiConfigId == null,
      );
      await userRepo.updateUserSettings(updatedUser);
    }
  }
}

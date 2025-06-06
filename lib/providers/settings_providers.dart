import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/enums.dart'; // 导入主题设置枚举
import 'core_providers.dart'; // 导入 sharedPreferencesProvider

// SharedPreferences 中用于存储主题设置的键
const String _themeModeKey = 'app_theme_mode';

// --- 主题设置状态 ---
// 定义主题设置的状态类，这里只包含一个 ThemeModeSetting
class ThemeSettingState {
  final ThemeModeSetting themeMode;
  ThemeSettingState(this.themeMode);
}

// --- ThemeModeNotifier ---
// StateNotifier 用于管理和持久化主题设置
class ThemeModeNotifier extends StateNotifier<ThemeModeSetting> {
  final SharedPreferences _prefs;

  ThemeModeNotifier(this._prefs) : super(_loadThemeMode(_prefs));

  // 从 SharedPreferences 加载主题设置
  static ThemeModeSetting _loadThemeMode(SharedPreferences prefs) {
    final themeModeString = prefs.getString(_themeModeKey);
    if (themeModeString != null) {
      try {
        return ThemeModeSetting.values.firstWhere((e) => e.toString() == themeModeString);
      } catch (e) {
        // 如果解析失败，返回默认值
        return ThemeModeSetting.system;
      }
    }
    return ThemeModeSetting.system; // 默认值为跟随系统
  }

  // 更新主题设置并持久化到 SharedPreferences
  Future<void> setThemeMode(ThemeModeSetting newMode) async {
    if (state != newMode) {
      state = newMode;
      await _prefs.setString(_themeModeKey, newMode.toString());
    }
  }
}

// --- themeModeProvider ---
// 提供 ThemeModeNotifier 实例的 StateNotifierProvider
// 它依赖于 sharedPreferencesProvider 来获取 SharedPreferences 实例
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeModeSetting>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemeModeNotifier(prefs);
});

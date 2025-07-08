import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/enums.dart'; // 导入主题设置枚举

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
  // SharedPreferences 现在是可空的，并且是 late final
  late final SharedPreferences? _prefs;

  ThemeModeNotifier() : super(ThemeModeSetting.system);

  // 提供一个异步的初始化方法
  Future<void> init() async {
    // 等待 SharedPreferences 加载完成
    _prefs = await SharedPreferences.getInstance();
    // 从 SharedPreferences 加载主题设置并更新状态
    _loadThemeMode();
  }

  // 从 SharedPreferences 加载主题设置
  void _loadThemeMode() {
    final prefs = _prefs;
    if (prefs == null) return; // 如果 prefs 未初始化，则不执行任何操作

    final themeModeString = prefs.getString(_themeModeKey);
    if (themeModeString != null) {
      try {
        state = ThemeModeSetting.values.firstWhere((e) => e.toString() == themeModeString);
      } catch (e) {
        state = ThemeModeSetting.system; // 如果解析失败，返回默认值
      }
    } else {
      state = ThemeModeSetting.system; // 默认值为跟随系统
    }
  }

  // 更新主题设置并持久化到 SharedPreferences
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

// --- themeModeProvider ---
// 提供 ThemeModeNotifier 实例的 StateNotifierProvider
// 不再直接依赖 sharedPreferencesProvider，而是在 Notifier 内部处理
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeModeSetting>((ref) {
  final notifier = ThemeModeNotifier();
  notifier.init(); // 调用异步初始化
  return notifier;
});

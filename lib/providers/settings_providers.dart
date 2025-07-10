import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/enums.dart'; // 导入主题设置枚举

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

// --- 全局应用设置 ---

// SharedPreferences Keys
const String _enableAutoTitleGenerationKey = 'global_enable_auto_title_generation';
const String _titleGenerationPromptKey = 'global_title_generation_prompt';
const String _titleGenerationApiConfigIdKey = 'global_title_generation_api_config_id';
const String _enableResumeKey = 'global_enable_resume';
const String _resumePromptKey = 'global_resume_prompt';
const String _resumeApiConfigIdKey = 'global_resume_api_config_id';
const String _enableHelpMeReplyKey = 'global_enable_help_me_reply';
const String _helpMeReplyPromptKey = 'global_help_me_reply_prompt';
const String _helpMeReplyApiConfigIdKey = 'global_help_me_reply_api_config_id';
const String _helpMeReplyTriggerModeKey = 'global_help_me_reply_trigger_mode';


const String defaultTitleGenerationPrompt = '根据对话，为本次聊天生成一个简洁的、不超过10个字的标题。（你的回复内容只能是纯标题，不能包含任何其他内容）';
const String defaultResumePrompt = '继续生成被中断的回复，请直接从最后一个字甚至是符号后继续，不要包含任何其他内容。';
const String defaultHelpMeReplyPrompt = '假如你是我，请根据以上对话，为我设想三个不同的回复，并使用序号1. 2. 3.分别标注。（不要包含任何其他非序号的回复内容。）';


@immutable
class GlobalSettings {
  final bool enableAutoTitleGeneration;
  final String titleGenerationPrompt;
  final String? titleGenerationApiConfigId;

  final bool enableResume;
  final String resumePrompt;
  final String? resumeApiConfigId;

  final bool enableHelpMeReply;
  final String helpMeReplyPrompt;
  final String? helpMeReplyApiConfigId;
  final String helpMeReplyTriggerMode; // 'manual' or 'auto'

  const GlobalSettings({
    this.enableAutoTitleGeneration = false,
    this.titleGenerationPrompt = defaultTitleGenerationPrompt,
    this.titleGenerationApiConfigId,
    this.enableResume = false,
    this.resumePrompt = defaultResumePrompt,
    this.resumeApiConfigId,
    this.enableHelpMeReply = false,
    this.helpMeReplyPrompt = defaultHelpMeReplyPrompt,
    this.helpMeReplyApiConfigId,
    this.helpMeReplyTriggerMode = 'manual',
  });

  GlobalSettings copyWith({
    bool? enableAutoTitleGeneration,
    String? titleGenerationPrompt,
    String? titleGenerationApiConfigId,
    bool clearTitleGenerationApiConfigId = false,
    bool? enableResume,
    String? resumePrompt,
    String? resumeApiConfigId,
    bool clearResumeApiConfigId = false,
    bool? enableHelpMeReply,
    String? helpMeReplyPrompt,
    String? helpMeReplyApiConfigId,
    bool clearHelpMeReplyApiConfigId = false,
    String? helpMeReplyTriggerMode,
  }) {
    return GlobalSettings(
      enableAutoTitleGeneration: enableAutoTitleGeneration ?? this.enableAutoTitleGeneration,
      titleGenerationPrompt: titleGenerationPrompt ?? this.titleGenerationPrompt,
      titleGenerationApiConfigId: clearTitleGenerationApiConfigId ? null : titleGenerationApiConfigId ?? this.titleGenerationApiConfigId,
      enableResume: enableResume ?? this.enableResume,
      resumePrompt: resumePrompt ?? this.resumePrompt,
      resumeApiConfigId: clearResumeApiConfigId ? null : resumeApiConfigId ?? this.resumeApiConfigId,
      enableHelpMeReply: enableHelpMeReply ?? this.enableHelpMeReply,
      helpMeReplyPrompt: helpMeReplyPrompt ?? this.helpMeReplyPrompt,
      helpMeReplyApiConfigId: clearHelpMeReplyApiConfigId ? null : helpMeReplyApiConfigId ?? this.helpMeReplyApiConfigId,
      helpMeReplyTriggerMode: helpMeReplyTriggerMode ?? this.helpMeReplyTriggerMode,
    );
  }
}

class GlobalSettingsNotifier extends StateNotifier<GlobalSettings> {
  late final SharedPreferences? _prefs;

  GlobalSettingsNotifier() : super(const GlobalSettings());

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSettings();
  }

  void _loadSettings() {
    final prefs = _prefs;
    if (prefs == null) return;

    state = GlobalSettings(
      enableAutoTitleGeneration: prefs.getBool(_enableAutoTitleGenerationKey) ?? false,
      titleGenerationPrompt: prefs.getString(_titleGenerationPromptKey) ?? defaultTitleGenerationPrompt,
      titleGenerationApiConfigId: prefs.getString(_titleGenerationApiConfigIdKey),
      enableResume: prefs.getBool(_enableResumeKey) ?? false,
      resumePrompt: prefs.getString(_resumePromptKey) ?? defaultResumePrompt,
      resumeApiConfigId: prefs.getString(_resumeApiConfigIdKey),
      enableHelpMeReply: prefs.getBool(_enableHelpMeReplyKey) ?? false,
      helpMeReplyPrompt: prefs.getString(_helpMeReplyPromptKey) ?? defaultHelpMeReplyPrompt,
      helpMeReplyApiConfigId: prefs.getString(_helpMeReplyApiConfigIdKey),
      helpMeReplyTriggerMode: prefs.getString(_helpMeReplyTriggerModeKey) ?? 'manual',
    );
  }

  Future<void> updateSettings(GlobalSettings newSettings) async {
    final prefs = _prefs;
    if (prefs == null) return;
    
    // Only update state if it has changed to avoid unnecessary rebuilds
    if (state != newSettings) {
      state = newSettings;
      await prefs.setBool(_enableAutoTitleGenerationKey, newSettings.enableAutoTitleGeneration);
      await prefs.setString(_titleGenerationPromptKey, newSettings.titleGenerationPrompt);
      if (newSettings.titleGenerationApiConfigId != null) {
        await prefs.setString(_titleGenerationApiConfigIdKey, newSettings.titleGenerationApiConfigId!);
      } else {
        await prefs.remove(_titleGenerationApiConfigIdKey);
      }

      await prefs.setBool(_enableResumeKey, newSettings.enableResume);
      await prefs.setString(_resumePromptKey, newSettings.resumePrompt);
      if (newSettings.resumeApiConfigId != null) {
        await prefs.setString(_resumeApiConfigIdKey, newSettings.resumeApiConfigId!);
      } else {
        await prefs.remove(_resumeApiConfigIdKey);
      }

      await prefs.setBool(_enableHelpMeReplyKey, newSettings.enableHelpMeReply);
      await prefs.setString(_helpMeReplyPromptKey, newSettings.helpMeReplyPrompt);
      if (newSettings.helpMeReplyApiConfigId != null) {
        await prefs.setString(_helpMeReplyApiConfigIdKey, newSettings.helpMeReplyApiConfigId!);
      } else {
        await prefs.remove(_helpMeReplyApiConfigIdKey);
      }
      await prefs.setString(_helpMeReplyTriggerModeKey, newSettings.helpMeReplyTriggerMode);
    }
  }
}

final globalSettingsProvider = StateNotifierProvider<GlobalSettingsNotifier, GlobalSettings>((ref) {
  final notifier = GlobalSettingsNotifier();
  notifier.init();
  return notifier;
});

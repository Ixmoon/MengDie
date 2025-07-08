// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';

// 本文件包含项目中使用的所有枚举类型。
// Most enums are now re-exported from Drift's common_enums.dart
// to ensure consistency with the database layer.

export '../data/database/drift/common_enums.dart'
	show
		LlmType,
		MessageRole,
		XmlAction,
		LocalHarmCategory,
		LocalHarmBlockThreshold,
		ContextManagementMode;

// --- 主题设置枚举 (UI specific, not in Drift common_enums) ---
enum ThemeModeSetting {
	system, // 跟随系统
	light, // 浅色模式
	dark; // 深色模式

	/// 将自定义枚举映射到 Flutter 的 [ThemeMode]。
	ThemeMode get toThemeMode {
		switch (this) {
			case ThemeModeSetting.light:
				return ThemeMode.light;
			case ThemeModeSetting.dark:
				return ThemeMode.dark;
			case ThemeModeSetting.system:
				return ThemeMode.system;
		}
	}
}

// --- 消息内容部分类型 ---
enum MessagePartType {
  text,
  image,
  file, // For generic file attachments
}



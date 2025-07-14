// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';

// 本文件包含项目中使用的所有枚举类型。
// Most enums are now re-exported from Drift's common_enums.dart
// to ensure consistency with the database layer.

export '../database/common_enums.dart'
	show
		LlmType,
		MessageRole,
		XmlAction,
		LocalHarmCategory,
		LocalHarmBlockThreshold,
		ContextManagementMode;

// --- “帮我回复”触发模式 ---
enum HelpMeReplyTriggerMode {
		manual, // 手动触发
		auto,   // 自动触发
}

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

// --- OpenAI 'reasoning_effort' setting ---
enum OpenAIReasoningEffort {
  auto,   // "自动" - 默认值, 发送 "auto" 值，由 API 决定。
  none,   // "关闭" - 对于支持的模型，此设置将禁用思考功能
  low,    // "低"
  medium, // "中"
  high;   // "高"

  /// 获取对应于API请求的字符串值
  String get toApiValue {
    return name; // The enum member names (e.g., "auto", "none", "low") match the API values
  }
}



// --- 聊天列表屏幕模式 ---
enum ChatListMode {
  /// 正常模式，浏览和管理聊天。
  normal,
  /// 模板选择模式，用于根据模板新建聊天。
  templateSelection,
  /// 模板管理模式，用于编辑和创建模板。
  templateManagement,
}

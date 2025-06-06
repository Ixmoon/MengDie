// ignore_for_file: constant_identifier_names

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
  light,  // 浅色模式
  dark,   // 深色模式
}



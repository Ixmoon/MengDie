import 'package:flutter/material.dart';

// 本文件包含应用的主题配置。

// --- 应用主题类 ---
// 定义了应用的浅色和深色主题。
class AppTheme {
 // --- 浅色主题 ---
 static final ThemeData lightTheme = ThemeData(
   useMaterial3: true, // 启用 Material 3 设计
   // 使用种子颜色生成颜色方案
   colorScheme: ColorScheme.fromSeed(
     seedColor: Colors.blueAccent, // 基础种子颜色
     brightness: Brightness.light, // 浅色模式
   ),
   // AppBar 主题配置
   appBarTheme: AppBarTheme(
backgroundColor: Colors.blueAccent.shade100.withValues(alpha: 0.8), // 半透明背景
      foregroundColor: Colors.black87, // 前景色 (标题、图标)
      elevation: 0.5, // 轻微阴影
   ),
    // Scaffold 背景色
    scaffoldBackgroundColor: Colors.grey.shade100,
    // Card 主题配置
    cardTheme: CardTheme(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // 圆角
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0), // 默认外边距
    ),
    // 输入框装饰主题
    inputDecorationTheme: InputDecorationTheme(
       border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), // 圆角边框
       contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0), // 内容边距
       filled: true, // 启用填充色
 fillColor: Colors.white.withValues(alpha: 0.8), // 半透明填充色
       floatingLabelBehavior: FloatingLabelBehavior.auto, // 标签行为
     ),
     // ElevatedButton 主题
     elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), // 圆角
           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // 内边距
        )
     ),
     // TextButton 主题
      textButtonTheme: TextButtonThemeData(
         style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // 内边距
         )
      )
 );

 // --- 深色主题 ---
 static final ThemeData darkTheme = ThemeData(
   useMaterial3: true,
   // 使用种子颜色生成颜色方案
   colorScheme: ColorScheme.fromSeed(
     seedColor: Colors.lightBlue, // 深色模式的种子颜色
     brightness: Brightness.dark, // 深色模式
   ),
    // AppBar 主题配置
    appBarTheme: AppBarTheme(
backgroundColor: Colors.grey.shade900.withValues(alpha: 0.8), // 半透明深色背景
      foregroundColor: Colors.white, // 前景色
       elevation: 0.5,
   ),
    // Scaffold 背景色
    scaffoldBackgroundColor: Colors.black,
     // Card 主题配置
     cardTheme: CardTheme(
      elevation: 1,
      color: Colors.grey.shade800, // 深色卡片背景
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
    ),
     // 输入框装饰主题
     inputDecorationTheme: InputDecorationTheme(
       border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
       contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
       filled: true,
       fillColor: Colors.grey.shade700.withValues(alpha: 0.8), // 深色半透明填充
       floatingLabelBehavior: FloatingLabelBehavior.auto,
     ),
     // ElevatedButton 主题
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        )
     ),
     // TextButton 主题
       textButtonTheme: TextButtonThemeData(
         style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
         )
      )
 );
}

// #############################################################################
// # 应用入口点 (main.dart) 与项目结构分析
// #############################################################################
//
// 本文件是 Flutter 应用的主入口点。其主要职责包括：
// 1. 初始化必要的服务（如 SharedPreferences）。
// 2. 设置 Riverpod ProviderScope，并覆盖需要预先初始化的 Provider。
// 3. 运行应用的根 Widget (MyApp)，并根据核心服务（如 Isar 数据库）的初始化状态构建 UI。
//
// #############################################################################

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 导入应用配置和核心 Provider
import 'config/theme.dart'; // 导入主题配置
import 'config/router.dart'; // 导入路由配置
import 'providers/core_providers.dart'; // 导入核心 Provider (Drift AppDatabase, SharedPreferences)
import 'providers/settings_providers.dart'; // 导入主题设置 Provider
import 'models/enums.dart'; // 导入主题设置枚举

// --- 应用主函数 ---
Future<void> main() async {
  // 确保 Flutter 绑定已初始化，这对于在 runApp 之前调用原生代码是必需的。
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 SharedPreferences，用于本地持久化存储简单键值对。
  final prefs = await SharedPreferences.getInstance();

  // 注意：Isar 数据库的初始化现在由 isarProvider (在 core_providers.dart 中定义) 处理。
  // 它是一个 FutureProvider，会在首次被读取时异步打开数据库。

  // 运行 Flutter 应用。
  // 使用 ProviderScope 包裹根 Widget，以便整个应用可以访问 Riverpod Providers。
  runApp(
    ProviderScope(
      // 覆盖需要预先初始化的 Provider。
      overrides: [
        // 将已初始化的 SharedPreferences 实例提供给 sharedPreferencesProvider。
        sharedPreferencesProvider.overrideWithValue(prefs),
        // isarProvider 不需要在这里覆盖，它会自行异步初始化。
      ],
      // MyApp 是应用的根 Widget。
      child: const MyApp(),
    ),
  );
}

// --- 应用根 Widget ---
// MyApp 是一个 ConsumerWidget，可以访问 Riverpod Providers。
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听路由 Provider 以获取 GoRouter 实例。
    final router = ref.watch(routerProvider);
    // AppDatabase is now provided by appDatabaseProvider.
    // We don't need to handle its async loading state directly in MyApp's build.
    // Repositories will depend on appDatabaseProvider.
    // final appDb = ref.watch(appDatabaseProvider); // Ensure it's initialized if needed early.
    
    // 监听主题设置 Provider
    final currentThemeSetting = ref.watch(themeModeProvider);

    // 将 ThemeModeSetting 转换为 Flutter 的 ThemeMode
    ThemeMode themeMode;
    switch (currentThemeSetting) {
      case ThemeModeSetting.light:
        themeMode = ThemeMode.light;
        break;
      case ThemeModeSetting.dark:
        themeMode = ThemeMode.dark;
        break;
      case ThemeModeSetting.system:
      default:
        themeMode = ThemeMode.system;
        break;
    }

    // The database is now initialized by appDatabaseProvider.
    // We assume it's ready when repositories need it.
    // No need for the .when() clause for database loading here.
    return MaterialApp.router(
      title: '梦蝶', // 应用标题
      theme: AppTheme.lightTheme, // 应用浅色主题
      darkTheme: AppTheme.darkTheme, // 应用深色主题
      themeMode: themeMode, // 根据 Provider 状态设置主题模式
      // 配置路由：使用从 routerProvider 获取的 GoRouter 实例。
      routerConfig: router,
      // 在调试模式下不显示右上角的 DEBUG 标志。
      debugShowCheckedModeBanner: false,
    );
  }
}

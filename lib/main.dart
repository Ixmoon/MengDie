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

// 导入应用配置和核心 Provider
import 'ui/theme.dart'; // 导入主题配置
import 'ui/router.dart'; // 导入路由配置
import 'providers/settings_providers.dart'; // 导入主题设置 Provider

// --- 应用主函数 ---
// 将 main 函数修改为 async 以便在启动前执行异步操作
void main() {
	// 确保 Flutter 绑定已初始化。
	WidgetsFlutterBinding.ensureInitialized();

	// 运行 Flutter 应用。
	// ProviderScope 是 Riverpod 的根，使 Provider 在整个应用中可用。
	runApp(
		const ProviderScope(
			child: MyApp(),
		),
	);
}

// --- 应用根 Widget ---
// MyApp 是一个 ConsumerWidget，可以响应 Riverpod Provider 的状态变化。
class MyApp extends ConsumerWidget {
	const MyApp({super.key});

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		// 监听路由和主题 Provider。
		final router = ref.watch(routerProvider);
		final themeModeSetting = ref.watch(themeModeProvider);

		// The database is now initialized by appDatabaseProvider.
		// We assume it's ready when repositories need it.
		// No need for the .when() clause for database loading here.
		return MaterialApp.router(
			title: '梦蝶', // 应用标题
			theme: AppTheme.lightTheme, // 应用浅色主题
			darkTheme: AppTheme.darkTheme, // 应用深色主题
			// 使用从模型层添加的 getter，将业务逻辑从 UI 组件中移除。
			themeMode: themeModeSetting.toThemeMode,
			// 配置路由：使用从 routerProvider 获取的 GoRouter 实例。
			routerConfig: router,
			// 在调试模式下不显示右上角的 DEBUG 标志。
			debugShowCheckedModeBanner: false,
		);
	}
}

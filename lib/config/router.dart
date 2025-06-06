import 'package:flutter/foundation.dart'; // for kDebugMode
import 'package:flutter/material.dart'; // for Scaffold
import 'package:flutter_riverpod/flutter_riverpod.dart'; // for Provider
import 'package:go_router/go_router.dart'; // for GoRouter, GoRoute

// 导入需要导航到的屏幕
import '../screens/chat_list_screen.dart';
import '../screens/global_settings_screen.dart';
import '../screens/gemini_api_keys_screen.dart'; // 导入新的密钥管理屏幕
import '../screens/openai_api_configs_screen.dart'; // 新增：导入 OpenAI 配置屏幕
import '../screens/chat_screen.dart';
import '../screens/chat_settings_screen.dart';
import '../screens/chat_gallery_screen.dart';
import '../screens/chat_debug_screen.dart';

// 本文件包含应用的路由配置。

// --- GoRouter Provider ---
// 提供 GoRouter 实例的 Provider。
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    // 应用的初始路由路径
    initialLocation: '/',
    // 仅在调试模式下打印路由日志
    debugLogDiagnostics: kDebugMode,
    // 定义应用的路由规则
    routes: [
      // --- 根路由：聊天列表 ---
      GoRoute(
        path: '/', // 路径为根目录
        builder: (context, state) => const ChatListScreen(), // 对应的屏幕 Widget
      ),
      // --- 全局设置路由 ---
      GoRoute(
        path: '/settings', // 路径为 /settings
        builder: (context, state) => const GlobalSettingsScreen(),
        routes: [ // 为全局设置添加子路由
          GoRoute(
            path: 'gemini-api-keys', // 相对路径，完整路径为 /settings/gemini-api-keys
            builder: (context, state) => const GeminiApiKeysScreen(),
          ),
          GoRoute( // 新增：OpenAI API 配置路由
            path: 'openai-api-configs', // 相对路径，完整路径为 /settings/openai-api-configs
            builder: (context, state) => const OpenAIAPIConfigsScreen(),
          ),
        ]
      ),
      // --- 聊天屏幕路由 (包含子路由) ---
      GoRoute(
        path: '/chat/:chatId', // 路径包含 chatId 参数
        builder: (context, state) {
          // 从路径参数中安全地解析 chatId
          final chatId = int.tryParse(state.pathParameters['chatId'] ?? '');
          // 如果 chatId 无效或解析失败
          if (chatId == null) {
             // 显示错误页面或重定向
             return const Scaffold(body: Center(child: Text('无效的聊天 ID')));
          }
          // 如果 chatId 有效，导航到 ChatScreen 并传递 chatId
          return ChatScreen(chatId: chatId);
        },
        // --- 聊天屏幕的子路由 ---
        routes: [
          // 聊天设置子路由
          GoRoute(
            path: 'settings', // 相对路径，完整路径为 /chat/:chatId/settings
            builder: (context, state) {
              final chatId = int.tryParse(state.pathParameters['chatId'] ?? '');
              if (chatId == null) return const Scaffold(body: Center(child: Text('无效的聊天 ID')));
              return ChatSettingsScreen(chatId: chatId); // 导航到聊天设置屏幕
            },
          ),
          // 聊天图库子路由
          GoRoute(
            path: 'gallery', // 相对路径，完整路径为 /chat/:chatId/gallery
            builder: (context, state) {
              final chatId = int.tryParse(state.pathParameters['chatId'] ?? '');
              if (chatId == null) return const Scaffold(body: Center(child: Text('无效的聊天 ID')));
              return ChatGalleryScreen(chatId: chatId); // 导航到聊天图库屏幕
            },
          ),
          // 聊天调试子路由
          GoRoute(
            path: 'debug', // 相对路径，完整路径为 /chat/:chatId/debug
            builder: (context, state) {
              final chatId = int.tryParse(state.pathParameters['chatId'] ?? '');
              if (chatId == null) return const Scaffold(body: Center(child: Text('无效的聊天 ID')));
              return ChatDebugScreen(chatId: chatId); // 导航到聊天调试屏幕
            },
          ),
        ],
      ),
    ],
    // --- 全局路由错误处理 ---
    // 当找不到匹配的路由时，显示此页面
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('页面未找到')),
      body: Center(child: Text('路由错误: ${state.error?.message ?? '未知错误'}')),
    ),
  );
});

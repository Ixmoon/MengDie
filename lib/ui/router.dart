import 'dart:async';

import 'package:flutter/foundation.dart'; // for kDebugMode
import 'package:flutter/material.dart'; // for Scaffold
import 'package:flutter_riverpod/flutter_riverpod.dart'; // for Provider
import 'package:go_router/go_router.dart'; // for GoRouter, GoRoute

import '../app/providers/auth_providers.dart';
import '../domain/enums.dart'; // 导入枚举
// 导入需要导航到的屏幕
import 'screens/main_screen.dart';
import 'screens/startup_screen.dart';
import 'screens/login_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/global_settings_screen.dart';
import 'screens/api_configs_screen.dart'; // 统一的 API 配置屏幕
import 'screens/gemini_api_keys_screen.dart'; // 新增
import 'screens/chat_screen.dart';
import 'screens/chat_settings_screen.dart';
import 'screens/chat_debug_screen.dart';
import 'screens/prompt_editor_screen.dart';
import 'screens/prompt_item_editor_screen.dart';

// 本文件包含应用的路由配置。

// --- GoRouter Provider ---
// 提供 GoRouter 实例的 Provider。
// --- Initial Location Provider ---
// 这个 Provider 决定了应用的初始页面。
// 默认是聊天列表 ('/'), 但可以在 main.dart 中被覆盖。

// --- GoRouter Provider ---
// 提供 GoRouter 实例的 Provider。
final rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authProvider.notifier);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/', // 总是从启动页开始
    debugLogDiagnostics: kDebugMode,
    refreshListenable: GoRouterRefreshStream(authNotifier.stream),
    redirect: (BuildContext context, GoRouterState state) {
      final authState = ref.read(authProvider);
      // A user is considered authenticated if they have a currentUser,
      // which includes guest mode.
      final bool isAuthenticated = authState.currentUser != null;
      
      final bool isStartup = state.matchedLocation == '/';
      final bool isLoggingIn = state.matchedLocation == '/login';

      // If the user is not authenticated at all, they should only be able to access the
      // startup and login pages.
      if (!isAuthenticated && !isLoggingIn && !isStartup) {
        return '/login';
      }

      // If the user is authenticated (either as a guest or a real user),
      // they should not be able to access the startup or login pages.
      if (isAuthenticated && (isLoggingIn || isStartup)) {
        return '/list';
      }

      // In all other cases, no redirect is necessary.
      return null;
    },
    routes: [
      GoRoute(
        path: '/login', // 登录页
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/', // 启动页，现在作为 ShellRoute 的父级
        builder: (context, state) => const StartupScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return MainScreen(child: child);
        },
        routes: [
          GoRoute(
            path: '/list',
            pageBuilder: (context, state) {
              // 从查询参数中获取 mode
              // 从查询参数中获取 mode
              final queryParams = state.uri.queryParameters;
              final modeString = queryParams['mode'] ?? 'normal';
              ChatListMode mode;
              switch (modeString) {
                case 'select':
                  mode = ChatListMode.templateSelection;
                  break;
                case 'manage':
                  mode = ChatListMode.templateManagement;
                  break;
                default:
                  mode = ChatListMode.normal;
              }

              // 新增：解析 from_folder_id
              final fromFolderIdString = queryParams['from_folder_id'];
              final fromFolderId = fromFolderIdString != null
                  ? int.tryParse(fromFolderIdString)
                  : null;

              return NoTransitionPage(
                child: ChatListScreen(mode: mode, fromFolderId: fromFolderId),
              );
            },
          ),
          GoRoute(
            path: '/chat',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ChatScreen()),
            routes: [
              GoRoute(
                path: 'settings',
                parentNavigatorKey: rootNavigatorKey, // 在根导航器上显示
                builder: (context, state) => const ChatSettingsScreen(),
              ),
              GoRoute(
                path: 'debug',
                parentNavigatorKey: rootNavigatorKey, // 在根导航器上显示
                builder: (context, state) => const ChatDebugScreen(),
              ),
              GoRoute(
                path: 'prompt-editor',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => const PromptEditorScreen(),
                routes: [
                  GoRoute(
                    path: 'item/:itemId',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final itemId = state.pathParameters['itemId']!;
                      final chatId = int.parse(state.uri.queryParameters['chatId']!);
                      final isGlobal = state.uri.queryParameters['isGlobal'] == 'true';
                      return PromptItemEditorScreen(
                        itemId: itemId,
                        chatId: chatId,
                        isGlobal: isGlobal,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: rootNavigatorKey, // 在根导航器上显示
        builder: (context, state) => const GlobalSettingsScreen(),
        routes: [
          GoRoute(
            path: 'api-configs',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => const ApiConfigsScreen(),
          ),
          GoRoute(
            path: 'gemini-api-keys',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => const GeminiApiKeysScreen(),
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

/// 一个将 Stream 转换为 ChangeNotifier 的辅助类。
///
/// GoRouter 的 `refreshListenable` 需要一个 `Listenable` (如 `ChangeNotifier`)。
/// 这个类可以监听任何 Stream (比如 Riverpod provider 的 stream)，
/// 并在 Stream 发出新事件时调用 `notifyListeners()`，从而触发 GoRouter 的重定向逻辑。
class GoRouterRefreshStream extends ChangeNotifier {
  /// 创建一个 GoRouterRefreshStream。
  ///
  /// 需要传入一个 Stream，构造函数会自动订阅它。
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  /// 清理资源。
  ///
  /// 当这个对象不再需要时，调用此方法以取消 Stream 订阅，防止内存泄漏。
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

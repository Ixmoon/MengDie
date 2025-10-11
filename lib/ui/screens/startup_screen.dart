import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers/auth_providers.dart';
import '../../app/providers/core_providers.dart';

/// 一个处理初始化并重定向到相应页面的屏幕。
class StartupScreen extends ConsumerStatefulWidget {
  const StartupScreen({super.key});

  @override
  ConsumerState<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends ConsumerState<StartupScreen> {
  @override
  void initState() {
    super.initState();
    // 使用 addPostFrameCallback 以确保在 build 之后安全地执行异步操作和导航。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAndRedirect();
    });
  }

  Future<void> _initializeAndRedirect() async {
    // 尝试自动登录
    await ref.read(authProvider.notifier).tryAutoLogin();

    // 并行初始化核心 providers
    final coreInitializers = ref.read(coreAsyncInitializersProvider);
    await Future.wait(
      coreInitializers.map((provider) {
        final notifier = ref.read(provider);
        // Assuming notifiers have an 'init' method.
        return (notifier as dynamic).init();
      }),
    );

    // 检查挂载状态以防止在已释放的 widget 上调用 setState
    if (!mounted) return;

    // 根据认证状态导航
    final authState = ref.read(authProvider);
    if (authState.currentUser != null) {
      context.replace('/list');
    } else {
      context.replace('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    // StartupScreen 本身只显示一个加载指示器。
    // 它的职责是执行初始化并在完成后重定向。
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

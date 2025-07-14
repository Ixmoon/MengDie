import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_providers.dart';

/// 一个处理初始化并重定向到相应页面的屏幕。
class StartupScreen extends ConsumerWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听 authProvider 的状态。
    // 之前的 ref.listen 逻辑在这里是有缺陷的，因为它只在状态 *变化* 时触发。
    // 由于自动登录在 main 函数中已经 await，当 StartupScreen 构建时，
    // 认证状态已经确定，不会再“变化”，导致 listen 回调永远不执行。
    final authState = ref.watch(authProvider);

    // 使用 addPostFrameCallback 确保导航操作在 build 方法完成后安全地执行。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (authState.currentUser != null) {
        // 如果存在当前用户（无论是自动登录还是游客），则导航到主列表。
        context.replace('/list');
      } else {
        // 如果没有用户（即初始状态），则导航到登录页面。
        context.replace('/login');
      }
    });

    // StartupScreen 本身只显示一个加载指示器。
    // 它的职责是根据最终的认证状态，在下一帧立即执行一次性重定向。
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
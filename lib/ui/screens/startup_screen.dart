import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/core_providers.dart';
import '../../providers/chat_state_providers.dart';

/// 一个处理初始化并重定向到相应页面的屏幕。
class StartupScreen extends ConsumerWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听 sharedPreferencesProvider。
    // 当它解析完成后，决定目标页面并导航。
    final prefsAsync = ref.watch(sharedPreferencesProvider);

    return prefsAsync.when(
      loading: () => const Scaffold(body: SizedBox.shrink()),
      error: (err, stack) => Scaffold(
        body: Center(
          child: Text('启动失败: $err'),
        ),
      ),
      data: (prefs) {
        // 使用 post-frame 回调来在构建完成后安排导航。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            final lastChatId = prefs.getInt('last_open_chat_id');
            if (lastChatId != null) {
              ref.read(activeChatIdProvider.notifier).state = lastChatId;
              context.replace('/chat');
            } else {
              context.replace('/list');
            }
          }
        });

        // 在安排导航时，显示一个加载指示器。
        return const Scaffold(body: SizedBox.shrink());
      },
    );
  }
}
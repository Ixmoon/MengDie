import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/models.dart';
import '../../data/sync/sync_service.dart';
import '../../app/providers/chat_state_providers.dart';
import 'chat_page_content.dart';
import '../../app/providers/chat_state/chat_data_providers.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBackButtonPressed; // 新增

  const ChatScreen({super.key, this.onBackButtonPressed}); // 新增

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  @override
  void dispose() {
    // SyncService is a singleton, no need to dispose, but force push is a good idea.
    SyncService.instance.forcePushChanges();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeChatId = ref.watch(activeChatIdProvider);

    if (activeChatId == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text("没有选择聊天。\n请从列表中选择一个。"),
        ),
      );
    }

    final chatAsync = ref.watch(currentChatProvider(activeChatId));

    return chatAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(
            leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/list'))),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(
            leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/list'))),
        body: Center(child: Text('无法加载聊天数据: $error')),
      ),
      data: (chat) {
        if (chat == null) {
          return Scaffold(
            appBar: AppBar(
                leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      ref.read(activeChatIdProvider.notifier).state = null;
                      context.go('/list');
                    })),
            body: const Center(child: Text('聊天未找到或已被删除')),
          );
        }

        final siblingChatsAsync = ref.watch(chatListProvider((parentFolderId: chat.parentFolderId, mode: ChatListMode.normal)));

        return siblingChatsAsync.when(
          loading: () => Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => Scaffold(
            appBar: AppBar(),
            body: Center(child: Text('无法加载聊天列表: $error')),
          ),
          data: (siblingChats) {
            final chats = siblingChats.where((c) => !c.isFolder).toList();
            final currentIndex = chats.indexWhere((c) => c.id == activeChatId);

            if (chats.length <= 1 || currentIndex == -1) {
              return ChatPageContent(
                key: ValueKey(activeChatId),
                chatId: activeChatId,
                onBackButtonPressed: widget.onBackButtonPressed, // 传递回调
              );
            }
            
            // 使用一个基于聊天列表ID的唯一Key来驱动一个新的StatefulWidget。
            // 当列表变化时，Key会变化，旧的_ChatPageView状态会被销毁，新的会被创建，
            // 从而确保PageController总是以正确的初始状态被创建。
            return _ChatPageView(
              key: ValueKey(Object.hashAll(chats.map((c) => c.id))),
              chats: chats,
              initialIndex: currentIndex,
              onBackButtonPressed: widget.onBackButtonPressed, // 传递回调
            );
          },
        );
      },
    );
  }
}

/// 一个有状态的Widget，用于封装PageView和其PageController。
/// 它的生命周期由传入的Key控制，确保在聊天列表变化时能够正确地重建。
class _ChatPageView extends ConsumerStatefulWidget {
  final List<Chat> chats;
  final int initialIndex;
  final VoidCallback? onBackButtonPressed; // 新增

  const _ChatPageView({
    super.key,
    required this.chats,
    required this.initialIndex,
    this.onBackButtonPressed, // 新增
  });

  @override
  ConsumerState<_ChatPageView> createState() => _ChatPageViewState();
}

class _ChatPageViewState extends ConsumerState<_ChatPageView> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.chats.length,
      onPageChanged: (index) {
        final newChatId = widget.chats[index].id;
        // 使用ref.read来避免在回调中监听provider
        if (ref.read(activeChatIdProvider) != newChatId) {
          ref.read(activeChatIdProvider.notifier).state = newChatId;
        }
      },
      itemBuilder: (context, index) {
        final chat = widget.chats[index];
        return ChatPageContent(
          key: ValueKey(chat.id),
          chatId: chat.id,
          onBackButtonPressed: widget.onBackButtonPressed, // 传递回调
        );
      },
    );
  }
}

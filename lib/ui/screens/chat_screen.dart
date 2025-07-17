import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/models.dart';
import '../../data/sync/sync_service.dart';
import '../../domain/models/chat.dart';
import '../../app/providers/chat_state_providers.dart';
import 'chat_page_content.dart';
import '../../app/providers/chat_state/chat_data_providers.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  PageController? _pageController;

  @override
  void dispose() {
    SyncService.instance.forcePushChanges();
    _pageController?.dispose();
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
              // Also apply ValueKey here for consistency, ensuring the widget
              // properly rebuilds if the activeChatId changes for any reason.
              return ChatPageContent(key: ValueKey(activeChatId), chatId: activeChatId);
            }

            if (_pageController == null) {
              _pageController = PageController(initialPage: currentIndex);
            } else {
              final controllerPage = _pageController!.hasClients ? _pageController!.page?.round() : -1;
              if (controllerPage != currentIndex) {
                 WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_pageController!.hasClients) {
                      _pageController!.jumpToPage(currentIndex);
                    }
                 });
              }
            }

            return PageView.builder(
              controller: _pageController,
              itemCount: chats.length,
              onPageChanged: (index) {
                final newChatId = chats[index].id;
                if (ref.read(activeChatIdProvider) != newChatId) {
                  ref.read(activeChatIdProvider.notifier).state = newChatId;
                }
              },
              itemBuilder: (context, index) {
                return ChatPageContent(key: ValueKey(chats[index].id), chatId: chats[index].id);
              },
            );
          },
        );
      },
    );
  }
}

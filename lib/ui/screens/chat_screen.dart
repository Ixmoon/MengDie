import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/models.dart';
import '../../data/sync/sync_service.dart';
import '../../app/providers/chat_state_providers.dart';
import 'chat_page_content.dart';
import '../../app/providers/ui_state_providers/chat_screen_providers.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBackButtonPressed;

  const ChatScreen({super.key, this.onBackButtonPressed});

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

    // Watch the single, aggregated data provider.
    // This encapsulates all the complex logic of fetching, combining,
    // and validating the data needed for this screen.
    final chatScreenDataAsync = ref.watch(chatScreenDataProvider(activeChatId));

    return chatScreenDataAsync.when(
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
                onPressed: () {
                  // On error, it's safer to reset the active chat.
                  ref.read(activeChatIdProvider.notifier).state = null;
                  context.go('/list');
                })),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('无法加载聊天数据: $error'),
          ),
        ),
      ),
      data: (data) {
        // If the sibling list contains only the current chat (or is empty for some reason),
        // we don't need the PageView.
        if (data.siblingChats.length <= 1) {
          return ChatPageContent(
            key: ValueKey(activeChatId),
            chatId: activeChatId,
            onBackButtonPressed: widget.onBackButtonPressed,
          );
        }

        // Use a unique key based on the chat list IDs to drive a new StatefulWidget.
        // When the list changes, the key changes, destroying the old _ChatPageView state
        // and creating a new one, ensuring the PageController is always created
        // with the correct initial state.
        return _ChatPageView(
          key: ValueKey(Object.hashAll(data.siblingChats.map((c) => c.id))),
          chats: data.siblingChats,
          initialIndex: data.currentIndex,
          onBackButtonPressed: widget.onBackButtonPressed,
        );
      },
    );
  }
}

/// A stateful widget that encapsulates the PageView and its PageController.
/// Its lifecycle is controlled by the incoming Key, ensuring it is rebuilt
/// correctly when the chat list changes.
class _ChatPageView extends ConsumerStatefulWidget {
  final List<Chat> chats;
  final int initialIndex;
  final VoidCallback? onBackButtonPressed;

  const _ChatPageView({
    super.key,
    required this.chats,
    required this.initialIndex,
    this.onBackButtonPressed,
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
        // Use ref.read to avoid listening to the provider in a callback.
        if (ref.read(activeChatIdProvider) != newChatId) {
          ref.read(activeChatIdProvider.notifier).state = newChatId;
        }
      },
      itemBuilder: (context, index) {
        final chat = widget.chats[index];
        return ChatPageContent(
          key: ValueKey(chat.id),
          chatId: chat.id,
          onBackButtonPressed: widget.onBackButtonPressed,
        );
      },
    );
  }
}

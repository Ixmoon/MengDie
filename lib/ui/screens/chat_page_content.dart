import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/models.dart';
import '../providers/chat_state/chat_data_providers.dart';
import '../providers/chat_state_providers.dart';
import '../widgets/cached_image.dart';
import '../widgets/chat/chat_app_bar.dart';
import '../widgets/chat/chat_input_bar.dart';
import '../widgets/chat/message_list.dart';
import '../widgets/top_message_banner.dart';
import 'chat_page_logic.dart';

class ChatPageContent extends ConsumerStatefulWidget {
  const ChatPageContent({super.key, required this.chatId});
  final int chatId;

  @override
  ConsumerState<ChatPageContent> createState() => _ChatPageContentState();
}

class _ChatPageContentState extends ConsumerState<ChatPageContent> {
  final ScrollController _scrollController = ScrollController();
  late final TextEditingController _messageController;
  late final ChatPageLogic _logic;

  @override
  void initState() {
    super.initState();
    debugPrint("[ChatPageContent] initState: chatId=${widget.chatId}");
    _messageController = TextEditingController();
    _logic = ChatPageLogic(
      ref: ref,
      chatId: widget.chatId,
      context: context,
      onStateChange: () => setState(() {}),
    );

    _scrollController.addListener(_scrollListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(animate: false);
    });
  }

  @override
  void didUpdateWidget(covariant ChatPageContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    debugPrint("[ChatPageContent] didUpdateWidget: oldChatId=${oldWidget.chatId}, newChatId=${widget.chatId}");
    if (oldWidget.chatId != widget.chatId) {
      debugPrint("[ChatPageContent] chatId changed! Re-initializing logic.");
      // chatId has changed, re-initialize the logic.
      _logic = ChatPageLogic(
        ref: ref,
        chatId: widget.chatId,
        context: context,
        onStateChange: () => setState(() {}),
      );
      // Optionally, clear the text field when switching chats.
      _messageController.clear();
    }
  }

  void _scrollListener() {
    final chatState = ref.read(chatStateNotifierProvider(widget.chatId));
    if (!chatState.isAutoHeightEnabled) return;

    final notifier = ref.read(chatStateNotifierProvider(widget.chatId).notifier);
    final isHalfHeight = chatState.isMessageListHalfHeight;

    if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
      if (!isHalfHeight) {
        notifier.setMessageListHeightMode(true);
      }
    } else if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
      if (isHalfHeight) {
        notifier.setMessageListHeightMode(false);
      }
    }
  }

  Future<void> _saveCurrentChatId(int chatId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_open_chat_id', chatId);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animate = true}) {
    if (!_scrollController.hasClients || !_scrollController.position.hasContentDimensions) {
      return;
    }
    const double position = 0.0;
    if (animate) {
      _scrollController.animateTo(
        position,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(position);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatId = widget.chatId;
    debugPrint("[ChatPageContent] build: chatId=$chatId");
    final chatAsync = ref.watch(currentChatProvider(chatId));
    final chatState = ref.watch(chatStateNotifierProvider(chatId));

    ref.listen<int?>(activeChatIdProvider, (previous, next) {
      if (next != null && next == widget.chatId) {
        _saveCurrentChatId(next);
      }
    });

    ref.listen<ChatScreenState>(chatStateNotifierProvider(chatId), (previous, next) {
      if ((next.isLoading && previous?.isLoading == false) ||
          (next.isStreaming && previous?.isStreaming == false)) {
        _scrollToBottom();
      }
    });

    return chatAsync.when(
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
              body: const Center(child: Text('聊天未找到或已被删除')));
        }

        final hasBackgroundImage = chat.coverImageBase64 != null && chat.coverImageBase64!.isNotEmpty;
        final screenSize = MediaQuery.of(context).size;
        final pixelRatio = MediaQuery.of(context).devicePixelRatio;

        return Stack(
          fit: StackFit.expand,
          children: [
            hasBackgroundImage
                ? CachedImageFromBase64(
                    base64String: chat.coverImageBase64!,
                    fit: BoxFit.cover,
                    cacheWidth: (screenSize.width * pixelRatio).round(),
                    cacheHeight: (screenSize.height * pixelRatio).round(),
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Theme.of(context).scaffoldBackgroundColor,
                    ),
                  )
                : Container(color: Theme.of(context).scaffoldBackgroundColor),
            Scaffold(
              backgroundColor: Colors.transparent,
              appBar: ChatAppBar(
                chat: chat,
                onSetCoverImage: () => _logic.pickAndSetCoverImageBase64(ImageSource.gallery),
                onExportCoverImage: _logic.exportImage,
                onRemoveCoverImage: _logic.removeCoverImage,
                onForcePush: _logic.handleForcePush,
                isPushing: _logic.isPushing,
              ),
              body: SafeArea(
                child: Column(
                  children: [
                    TopMessageBanner(
                      message: chatState.topMessageText,
                      backgroundColor: chatState.topMessageColor,
                      onDismiss: () {
                        if (!mounted) return;
                        ref.read(chatStateNotifierProvider(chatId).notifier).clearTopMessage();
                      },
                    ),
                    if (chatState.isMessageListHalfHeight) const Spacer(),
                    Flexible(
                      flex: 1,
                      child: chatState.isMessageListHalfHeight
                          ? ShaderMask(
                              shaderCallback: (Rect bounds) {
                                return LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: const [Colors.transparent, Colors.black],
                                  stops: const [0.0, 0.1],
                                ).createShader(bounds);
                              },
                              blendMode: BlendMode.dstIn,
                              child: MessageList(
                                chatId: chatId,
                                scrollController: _scrollController,
                                onMessageTap: (message, part, allMessages) => _logic.handleMessageTap(message, part, allMessages),
                                onSuggestionSelected: (suggestion) {
                                  _messageController.text = suggestion;
                                },
                              ),
                            )
                          : MessageList(
                              chatId: chatId,
                              scrollController: _scrollController,
                              onMessageTap: (message, part, allMessages) => _logic.handleMessageTap(message, part, allMessages),
                              onSuggestionSelected: (suggestion) {
                                _messageController.text = suggestion;
                              },
                            ),
                    ),
                    if ((chatState.isLoading || chatState.isProcessingInBackground) && !chatState.isStreaming)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 0),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    ChatInputBar(chatId: chatId, messageController: _messageController),
                  ],
                ),
              ),
            ),
          ],
        );
      },
      loading: () => Scaffold(
          appBar: AppBar(
              leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.go('/list'))),
          body: const SizedBox.shrink()),
      error: (error, stack) => Scaffold(
          appBar: AppBar(
              leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.go('/list'))),
          body: Center(child: Text('无法加载聊天数据: $error'))),
    );
  }
}
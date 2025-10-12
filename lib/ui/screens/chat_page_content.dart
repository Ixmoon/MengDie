import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/providers/chat_state_providers.dart';
import '../../app/providers/ui_state_providers/chat_page_providers.dart';
import '../../domain/models/models.dart';
import '../widgets/cached_image.dart';
import '../widgets/chat/chat_app_bar.dart';
import '../widgets/chat/chat_input_bar.dart';
import '../widgets/chat/message_list.dart';
import '../widgets/top_message_banner.dart';
import '../../app/tools/xml_processor.dart';
import '../widgets/widget_utils.dart';

/// A private class to hold selectors for the ChatScreenState.
/// This prevents the entire ChatPageContent from rebuilding when only a small
/// part of the chat state changes.
class _ChatStateSelectors {
  const _ChatStateSelectors._();

  static (String?, Color?) selectTopMessage(ChatScreenState state) =>
      (state.topMessageText, state.topMessageColor);

  static bool selectIsMessageListHalfHeight(ChatScreenState state) =>
      state.isMessageListHalfHeight;

  static String? selectCarriedOverXml(ChatScreenState state) =>
      state.carriedOverXml;

  static (bool, bool, bool) selectLoadingIndicators(ChatScreenState state) =>
      (state.isLoading, state.isProcessingInBackground, state.isStreaming);

  static (bool, bool) selectScrollListenerTriggers(ChatScreenState state) =>
      (state.isLoading, state.isStreaming);
}

class ChatPageContent extends ConsumerStatefulWidget {
  const ChatPageContent({
    super.key,
    required this.chatId,
    this.onBackButtonPressed,
  });
  final int chatId;
  final VoidCallback? onBackButtonPressed;

  @override
  ConsumerState<ChatPageContent> createState() => _ChatPageContentState();
}

class _ChatPageContentState extends ConsumerState<ChatPageContent> {
  final ScrollController _scrollController = ScrollController();
  late final TextEditingController _messageController;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();

    _scrollController.addListener(_scrollListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(animate: false);
    });
  }

  void _scrollListener() {
    final chatState = ref.read(chatStateNotifierProvider(widget.chatId));
    if (!chatState.isAutoHeightEnabled) return;

    final notifier =
        ref.read(chatStateNotifierProvider(widget.chatId).notifier);
    final isHalfHeight = chatState.isMessageListHalfHeight;

    const double scrollThreshold = 150.0;

    // Based on user feedback, the directions were inverted.
    // This is the corrected logic.

    // 手指向上（查看历史），期望展开为全高
    if (_scrollController.position.userScrollDirection ==
        ScrollDirection.reverse) {
      if (isHalfHeight && _scrollController.position.pixels > scrollThreshold) {
        notifier.setMessageListHeightMode(false); // false means full height
      }
    }
    // 手指向下（返回底部），期望收起为半高
    else if (_scrollController.position.userScrollDirection ==
        ScrollDirection.forward) {
      if (!isHalfHeight) {
        notifier.setMessageListHeightMode(true); // true means half height
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
    if (!_scrollController.hasClients ||
        !_scrollController.position.hasContentDimensions) {
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

    final chatAsync = ref.watch(currentChatProvider(chatId));
    final pageState = ref.watch(chatPageNotifierProvider(chatId));
    final pageNotifier = ref.read(chatPageNotifierProvider(chatId).notifier);

    ref.listen<int?>(activeChatIdProvider, (previous, next) {
      if (next != null && next == widget.chatId) {
        _saveCurrentChatId(next);
      }
    });

    // Listen for state changes that should trigger a scroll to the bottom.
    // Using `select` to only listen to the relevant fields.
    ref.listen(
      chatStateNotifierProvider(
        chatId,
      ).select(_ChatStateSelectors.selectScrollListenerTriggers),
      (previous, next) {
        final wasLoading = previous?.$1 ?? false;
        final wasStreaming = previous?.$2 ?? false;
        final isLoading = next.$1;
        final isStreaming = next.$2;

        if ((isLoading && !wasLoading) || (isStreaming && !wasStreaming)) {
          _scrollToBottom();
        }
      },
    );

    // Watch individual state properties instead of the whole state object.
    final topMessage = ref.watch(
      chatStateNotifierProvider(
        chatId,
      ).select(_ChatStateSelectors.selectTopMessage),
    );
    final isMessageListHalfHeight = ref.watch(
      chatStateNotifierProvider(
        chatId,
      ).select(_ChatStateSelectors.selectIsMessageListHalfHeight),
    );
    final carriedOverXml = ref.watch(
      chatStateNotifierProvider(
        chatId,
      ).select(_ChatStateSelectors.selectCarriedOverXml),
    );
    final loadingIndicators = ref.watch(
      chatStateNotifierProvider(
        chatId,
      ).select(_ChatStateSelectors.selectLoadingIndicators),
    );
    final isLoading = loadingIndicators.$1;
    final isProcessingInBackground = loadingIndicators.$2;
    final isStreaming = loadingIndicators.$3;

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
                },
              ),
            ),
            body: const Center(child: Text('聊天未找到或已被删除')),
          );
        }

        final hasBackgroundImage =
            chat.coverImageBase64 != null && chat.coverImageBase64!.isNotEmpty;
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
                onSetCoverImage: () => pageNotifier.pickAndSetCoverImageBase64(
                  ImageSource.gallery,
                ),
                onExportCoverImage: () async {
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  final path = await pageNotifier.exportImage();
                  if (!mounted) return;
                  if (path != null) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('封面已保存到: $path'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('已取消保存'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
                onRemoveCoverImage: pageNotifier.removeCoverImage,
                onForcePush: () async {
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  if (!mounted) return;
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('正在上传本地变更...'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  final success = await pageNotifier.handleForcePush();
                  if (!mounted) return;
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(success ? '上传成功' : '上传失败或无需上传'),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                },
                isPushing: pageState.isPushing,
                onAddMessageAtEnd: (role) async {
                  final newMessage = await pageNotifier.addMessageAtEnd(role);
                  if (newMessage != null) {
                    _showEditMessageDialog(newMessage);
                  }
                },
                onBackButtonPressed: widget.onBackButtonPressed,
              ),
              body: SafeArea(
                child: Column(
                  children: [
                    TopMessageBanner(
                      message: topMessage.$1,
                      backgroundColor: topMessage.$2,
                      onDismiss: () {
                        if (!mounted) return;
                        ref
                            .read(chatStateNotifierProvider(chatId).notifier)
                            .clearTopMessage();
                      },
                    ),
                    if (isMessageListHalfHeight) const Spacer(),
                    Flexible(
                      flex: 1,
                      child: MessageList(
                        chatId: chatId,
                        scrollController: _scrollController,
                        xmlRules: chat.xmlRules,
                        carriedOverXml: carriedOverXml,
                        onMessageTap: _handleMessageTap,
                        onSuggestionSelected: (suggestion) {
                          _messageController.text = suggestion;
                        },
                      ),
                    ),
                    if ((isLoading || isProcessingInBackground) && !isStreaming)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 0),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    ChatInputBar(
                      chatId: chatId,
                      messageController: _messageController,
                    ),
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
            onPressed: () => context.go('/list'),
          ),
        ),
        body: const SizedBox.shrink(),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/list'),
          ),
        ),
        body: Center(child: Text('无法加载聊天数据: $error')),
      ),
    );
  }

  void _handleMessageTap(
    Message message,
    MessagePart part,
    List<Message> allMessages,
  ) {
    if (ref.read(chatStateNotifierProvider(widget.chatId)).isLoading) return;

    final pageNotifier = ref.read(
      chatPageNotifierProvider(widget.chatId).notifier,
    );
    final isUser = message.role == MessageRole.user;
    final messageIndex = allMessages.indexWhere((m) => m.id == message.id);
    final isLastUserMessage =
        isUser &&
        messageIndex >= 0 &&
        (messageIndex == allMessages.length - 1 ||
            (messageIndex == allMessages.length - 2 &&
                allMessages.last.role == MessageRole.model));

    showModalBottomSheet(
      context: context,
      builder: (modalContext) {
        List<Widget> options = [];
        final isTextOnly = part.type == MessagePartType.text;

        options.add(
          ListTile(
            leading: Icon(
              isTextOnly ? Icons.edit_outlined : Icons.upload_file_outlined,
            ),
            title: Text(isTextOnly ? '编辑消息' : '重新上传'),
            onTap: () {
              Navigator.pop(modalContext);
              if (isTextOnly) {
                _showEditMessageDialog(message);
              } else {
                pageNotifier.replaceAttachment(message, part);
              }
            },
          ),
        );

        if (!isTextOnly) {
          options.add(
            ListTile(
              leading: const Icon(Icons.save_alt_outlined),
              title: const Text('另存为...'),
              onTap: () async {
                Navigator.pop(modalContext);
                final path = await pageNotifier.saveAttachment(message);
                if (!mounted) return;
                if (path != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('附件已保存到: $path'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
                // Notifier will show its own message for cancellation or error
              },
            ),
          );
        }

        options.add(
          ListTile(
            leading: const Icon(Icons.fork_right_outlined),
            title: const Text('从此消息分叉对话'),
            onTap: () {
              Navigator.pop(modalContext);
              pageNotifier.forkChatFromMessage(message);
            },
          ),
        );

        if (isLastUserMessage) {
          options.add(
            ListTile(
              leading: const Icon(Icons.refresh_outlined),
              title: const Text('重新生成回复'),
              onTap: () {
                Navigator.pop(modalContext);
                pageNotifier.regenerateResponse(message);
              },
            ),
          );
        }

        options.addAll(_buildInsertMessageOptions(modalContext, messageIndex));

        options.add(
          ListTile(
            leading: Icon(Icons.delete_outline, color: Colors.red.shade400),
            title: Text('删除消息', style: TextStyle(color: Colors.red.shade400)),
            onTap: () async {
              Navigator.pop(modalContext);
              final confirm =
                  await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('确认删除'),
                      content: const Text('确定删除这条消息吗？'),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          child: Text(
                            '删除',
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
                  ) ??
                  false;

              if (confirm) {
                pageNotifier.deleteMessagePart(message, part);
              }
            },
          ),
        );

        return SafeArea(child: Wrap(children: options));
      },
    );
  }

  List<Widget> _buildInsertMessageOptions(
    BuildContext modalContext,
    int messageIndex,
  ) {
    final pageNotifier = ref.read(
      chatPageNotifierProvider(widget.chatId).notifier,
    );

    void insertAndEdit(int index, MessageRole role) {
      Navigator.pop(modalContext);
      pageNotifier.insertMessageAndEdit(
        index: index,
        role: role,
        onMessageCreated: (newMessage) {
          _showEditMessageDialog(newMessage);
        },
      );
    }

    return [
      const Divider(),
      ListTile(
        leading: const Icon(Icons.vertical_align_top_outlined),
        title: const Text('在此之前插入用户消息'),
        onTap: () => insertAndEdit(messageIndex, MessageRole.user),
      ),
      ListTile(
        leading: const Icon(Icons.vertical_align_top_outlined),
        title: const Text('在此之前插入模型消息'),
        onTap: () => insertAndEdit(messageIndex, MessageRole.model),
      ),
      ListTile(
        leading: const Icon(Icons.vertical_align_bottom_outlined),
        title: const Text('在此之后插入用户消息'),
        onTap: () => insertAndEdit(messageIndex + 1, MessageRole.user),
      ),
      ListTile(
        leading: const Icon(Icons.vertical_align_bottom_outlined),
        title: const Text('在此之后插入模型消息'),
        onTap: () => insertAndEdit(messageIndex + 1, MessageRole.model),
      ),
    ];
  }

  void _showEditMessageDialog(Message message) {
    final chat = ref.read(currentChatProvider(widget.chatId)).value;
    if (chat == null) return;

    final textController = TextEditingController(text: message.rawText);
    final originalXmlController =
        TextEditingController(text: message.originalXmlContent ?? '');
    final secondaryXmlController =
        TextEditingController(text: message.secondaryXmlContent ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) {
        final isModelMessage = message.role == MessageRole.model;

        return AlertDialog(
          title: Text(message.role == MessageRole.user ? '编辑消息' : '编辑模型回复'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: textController,
                  autofocus: true,
                  maxLines: 5,
                  minLines: 1,
                  decoration: InputDecoration(
                    labelText: '用户可见内容',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.fullscreen),
                      tooltip: '全屏编辑',
                      onPressed: () async {
                        final newText = await showFullScreenTextEditor(
                          context,
                          initialText: textController.text,
                          title: '编辑消息内容',
                          initialLanguage: 'markdown',
                          chatId: widget.chatId,
                        );
                        if (newText != null) {
                          textController.text = newText;
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '原生XML:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: originalXmlController,
                  maxLines: 5,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: '用于逻辑处理的XML标签...',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.fullscreen),
                      tooltip: '全屏编辑',
                      onPressed: () async {
                        final newText = await showFullScreenTextEditor(
                          context,
                          initialText: originalXmlController.text,
                          title: '编辑原生XML内容',
                          initialLanguage: 'xml',
                          chatId: widget.chatId,
                        );
                        if (newText != null) {
                          originalXmlController.text = newText;
                        }
                      },
                    ),
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
                if (isModelMessage) ...[
                  const SizedBox(height: 16),
                  const Text(
                    '再生XML:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: secondaryXmlController,
                    maxLines: 5,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: '由AI生成的额外XML内容...',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.fullscreen),
                        tooltip: '全屏编辑',
                        onPressed: () async {
                          final newText = await showFullScreenTextEditor(
                            context,
                            initialText: secondaryXmlController.text,
                            title: '编辑再生XML内容',
                            initialLanguage: 'xml',
                            chatId: widget.chatId,
                          );
                          if (newText != null) {
                            secondaryXmlController.text = newText;
                          }
                        },
                      ),
                    ),
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ]
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                final notifier = ref.read(
                  chatStateNotifierProvider(widget.chatId).notifier,
                );
                final newModelsTextFromInput = textController.text;
                final newOriginalXml = originalXmlController.text;
                final newSecondaryXml = secondaryXmlController.text;

                if (newModelsTextFromInput.trim().isEmpty &&
                    !message.parts.any((p) => p.type != MessagePartType.text)) {
                  notifier.showTopMessage(
                    '消息内容不能为空',
                    backgroundColor: Colors.orange,
                  );
                  return;
                }

                final newParts = List<MessagePart>.from(
                  message.parts.where((p) => p.type != MessagePartType.text),
                );
                newParts.add(MessagePart.text(newModelsTextFromInput));

                final finalOriginalXml =
                    newOriginalXml.isNotEmpty ? newOriginalXml : null;
                final finalSecondaryXml =
                    newSecondaryXml.isNotEmpty ? newSecondaryXml : null;

                Message updatedMessage = message.copyWith(
                  parts: newParts,
                  originalXmlContent: finalOriginalXml,
                  clearOriginalXml: finalOriginalXml == null,
                  secondaryXmlContent: isModelMessage
                      ? finalSecondaryXml
                      : message.secondaryXmlContent,
                  clearSecondaryXml:
                      isModelMessage ? (finalSecondaryXml == null) : false,
                );

                Navigator.pop(dialogContext);
                await notifier.editMessage(
                  updatedMessage.id,
                  updatedMessage: updatedMessage,
                );
              },
              child: const Text('保存'),
            ),
            TextButton(
              onPressed: () async {
                final notifier = ref.read(
                  chatStateNotifierProvider(widget.chatId).notifier,
                );
                final newModelsTextFromInput = textController.text;
                final newOriginalXml = originalXmlController.text;
                final newSecondaryXml = secondaryXmlController.text;

                final processResult = XmlProcessor.processPostStream(
                  newModelsTextFromInput,
                  chat.xmlRules,
                );
                final finalCleanModelsText = processResult.modelsText;
                final newlyExtractedXml = processResult.extractedXml;

                final List<String> originalXmlParts = [];
                if (newOriginalXml.isNotEmpty) {
                  originalXmlParts.add(newOriginalXml);
                }
                if (newlyExtractedXml != null && newlyExtractedXml.isNotEmpty) {
                  originalXmlParts.add(newlyExtractedXml);
                }
                final finalOriginalXml = originalXmlParts.isEmpty
                    ? null
                    : originalXmlParts.join('\n');

                final finalSecondaryXml =
                    newSecondaryXml.isNotEmpty ? newSecondaryXml : null;

                final newParts = List<MessagePart>.from(
                  message.parts.where((p) => p.type != MessagePartType.text),
                );
                newParts.add(MessagePart.text(finalCleanModelsText));

                Message updatedMessage = message.copyWith(
                  parts: newParts,
                  originalXmlContent: finalOriginalXml,
                  clearOriginalXml: finalOriginalXml == null,
                  secondaryXmlContent: isModelMessage
                      ? finalSecondaryXml
                      : message.secondaryXmlContent,
                  clearSecondaryXml:
                      isModelMessage ? (finalSecondaryXml == null) : false,
                );

                Navigator.pop(dialogContext);
                await notifier.editMessage(
                  updatedMessage.id,
                  updatedMessage: updatedMessage,
                );
              },
              child: const Text('保存并应用'),
            ),
          ],
        );
      },
    );
  }
}

import 'dart:async'; // For Timer
import 'dart:convert'; // For base64Decode
import 'package:file_picker/file_picker.dart'; // For picking files and save location
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Import for kIsWeb
import 'package:flutter/services.dart'; // 导入键盘服务
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/rendering.dart'; // For ScrollDirection

import 'package:go_router/go_router.dart'; // For navigation
// import 'package:isar/isar.dart'; // Removed Isar import
import 'package:mime/mime.dart'; // For mime type lookup
import 'package:shared_preferences/shared_preferences.dart'; // 导入 shared_preferences

// 导入模型、Provider、仓库、服务和 Widget
import '../../data/models/models.dart';
import '../providers/chat_state_providers.dart';
import '../../service/process/chat_export_import.dart'; // 导入导出/导入服务
import '../widgets/message_bubble.dart';
import '../widgets/top_message_banner.dart'; // 导入顶部消息横幅 Widget
import '../widgets/cached_image.dart'; // 导入缓存图片组件
import '../providers/settings_providers.dart'; // 导入全局设置
 
 // 本文件包含单个聊天会话的屏幕界面。
 
// --- 聊天屏幕 ---
// 使用 ConsumerStatefulWidget 以便访问 Ref 并管理本地状态（控制器、滚动等）。
// 聊天屏幕，现在作为 PageView 的宿主
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  PageController? _pageController;

  @override
  void dispose() {
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

        final siblingChatsAsync = ref.watch(chatListProvider(chat.parentFolderId));

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

            // 如果只有一个聊天或当前聊天不在列表中，则不使用 PageView
            if (chats.length <= 1 || currentIndex == -1) {
              return ChatPageContent(chatId: activeChatId);
            }

            // 创建或更新 PageController
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

// 承载单个聊天页面内容的 Widget
class ChatPageContent extends ConsumerStatefulWidget {
  const ChatPageContent({super.key, required this.chatId});
  final int chatId;

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
    // 仅当用户通过菜单启用了此功能时，才执行滚动逻辑
    if (!chatState.isAutoHeightEnabled) return;

    final notifier = ref.read(chatStateNotifierProvider(widget.chatId).notifier);
    final isHalfHeight = chatState.isMessageListHalfHeight;

    // 用户手指向上滑动（内容向下滚动，朝向最新消息）-> ScrollDirection.forward -> 显示半高
    if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
      if (!isHalfHeight) {
        notifier.setMessageListHeightMode(true);
      }
    // 用户手指向下滑动（内容向上滚动，朝向历史消息）-> ScrollDirection.reverse -> 显示全高
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

  Widget _buildBottomSheetActionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
    TextStyle? textStyle,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(label, style: textStyle),
      onTap: onTap,
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem({
    required String value,
    required IconData icon,
    required String label,
    bool enabled = true,
  }) {
    return PopupMenuItem<String>(
      value: value,
      enabled: enabled,
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        dense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  void _handleMessageTap(Message message, List<Message> allMessages) {
    final chatId = widget.chatId;
    if (ref.read(chatStateNotifierProvider(chatId)).isLoading) return;

    final isUser = message.role == MessageRole.user;
    final messageIndex = allMessages.indexWhere((m) => m.id == message.id);
    final isLastUserMessage = isUser &&
        messageIndex >= 0 &&
        (messageIndex == allMessages.length - 1 ||
            (messageIndex == allMessages.length - 2 &&
                allMessages.last.role == MessageRole.model));

    showModalBottomSheet(
      context: context,
      builder: (modalContext) {
        List<Widget> options = [];
        final isTextOnly = message.parts.length == 1 && message.parts.first.type == MessagePartType.text;
        
        options.add(_buildBottomSheetActionItem(
          icon: isTextOnly ? Icons.edit_outlined : Icons.upload_file_outlined,
          label: isTextOnly ? '编辑消息' : '重新上传',
          onTap: () {
            Navigator.pop(modalContext);
            if (isTextOnly) {
              _showEditMessageDialog(message);
            } else {
              _replaceAttachment(message);
            }
          },
        ));

        if (!isTextOnly) {
          options.add(_buildBottomSheetActionItem(
            icon: Icons.save_alt_outlined,
            label: '另存为...',
            onTap: () {
              Navigator.pop(modalContext);
              _saveAttachment(message);
            },
          ));
        }

        options.add(_buildBottomSheetActionItem(
          icon: Icons.fork_right_outlined,
          label: '从此消息分叉对话',
          onTap: () {
            Navigator.pop(modalContext);
            _forkChatFromMessage(message, allMessages);
          },
        ));

        if (isLastUserMessage) {
          options.add(_buildBottomSheetActionItem(
            icon: Icons.refresh_outlined,
            label: '重新生成回复',
            onTap: () {
              Navigator.pop(modalContext);
              _regenerateResponse(message, allMessages);
            },
          ));
        }

        options.add(_buildBottomSheetActionItem(
          icon: Icons.delete_outline,
          label: '删除消息',
          iconColor: Colors.red.shade400,
          textStyle: TextStyle(color: Colors.red.shade400),
          onTap: () async {
            Navigator.pop(modalContext);
            final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('确认删除'),
                    content: const Text('确定删除这条消息吗？'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(false),
                          child: const Text('取消')),
                      TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(true),
                          child: Text('删除', style: TextStyle(color: Colors.red.shade700))),
                    ],
                  ),
                ) ?? false;

            if (!mounted) return;
            if (confirm) {
              _deleteMessage(message, allMessages);
            }
          },
        ));

        return SafeArea(
          child: Wrap(children: options),
        );
      },
    );
  }

  void _showEditMessageDialog(Message message) {
    final chatId = widget.chatId;
    final chat = ref.read(currentChatProvider(chatId)).value;
    if (chat == null) return;

    final textController = TextEditingController(text: message.rawText);
    final xmlController = TextEditingController();

    if (message.role == MessageRole.model) {
      final bool useSecondaryXml = chat.enableSecondaryXml;
      xmlController.text = useSecondaryXml
          ? (message.secondaryXmlContent ?? '')
          : (message.originalXmlContent ?? '');
    }
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isFullScreen = false;
        TextEditingController? activeController;
        String fullScreenTitle = '';

        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (isFullScreen && activeController != null) {
              return Dialog(
                insetPadding: EdgeInsets.zero,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                child: Scaffold(
                  appBar: AppBar(
                    title: Text(fullScreenTitle),
                    leading: IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: '关闭',
                      onPressed: () => setDialogState(() => isFullScreen = false),
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.check),
                        tooltip: '完成',
                        onPressed: () => setDialogState(() => isFullScreen = false),
                      ),
                    ],
                  ),
                  body: TextField(
                    controller: activeController,
                    autofocus: true,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(fontSize: 16),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
                    ),
                  ),
                ),
              );
            }

            void openFullScreenEditor(TextEditingController controller, String title) {
              setDialogState(() {
                isFullScreen = true;
                activeController = controller;
                fullScreenTitle = title;
              });
            }

            Widget dialogContent;
            if (message.role == MessageRole.model) {
              dialogContent = SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('显示文本:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: textController,
                      autofocus: true,
                      maxLines: 5,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: '用户可见的纯文本内容...',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.all(12),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.fullscreen),
                          tooltip: '全屏编辑',
                          onPressed: () => openFullScreenEditor(textController, '编辑显示文本'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('XML内容:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: xmlController,
                      maxLines: 5,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: '用于逻辑处理的XML标签...',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.all(12),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.fullscreen),
                          tooltip: '全屏编辑',
                          onPressed: () => openFullScreenEditor(xmlController, '编辑XML内容'),
                        ),
                      ),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ],
                ),
              );
            } else {
              dialogContent = TextField(
                controller: textController,
                autofocus: true,
                maxLines: 5,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: '输入修改后的内容...',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.fullscreen),
                    tooltip: '全屏编辑',
                    onPressed: () => openFullScreenEditor(textController, '编辑你的消息'),
                  ),
                ),
              );
            }

            return AlertDialog(
              title: Text(message.role == MessageRole.user ? '编辑你的消息' : '编辑模型回复'),
              content: dialogContent,
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () async {
                    final notifier = ref.read(chatStateNotifierProvider(chatId).notifier);
                    final newDisplayText = textController.text.trim();
                    final newXmlContent = xmlController.text.trim();

                    if (newDisplayText.isEmpty && message.parts.any((p) => p.type != MessagePartType.text)) {
                    } else if (newDisplayText.isEmpty) {
                      notifier.showTopMessage('消息内容不能为空', backgroundColor: Colors.orange);
                      return;
                    }

                    Message updatedMessage;
                    if (message.role == MessageRole.model) {
                      final bool useSecondaryXml = chat.enableSecondaryXml;
                      updatedMessage = message.copyWith({
                        'parts': [MessagePart.text(newDisplayText)],
                        'secondaryXmlContent': useSecondaryXml ? newXmlContent : message.secondaryXmlContent,
                        'originalXmlContent': !useSecondaryXml ? newXmlContent : message.originalXmlContent,
                      });
                    } else {
                      // For user messages, find the first text part and update it, preserving other parts (like images).
                      final newParts = List<MessagePart>.from(message.parts);
                      final textPartIndex = newParts.indexWhere((p) => p.type == MessagePartType.text);
                      if (textPartIndex != -1) {
                        newParts[textPartIndex] = MessagePart.text(newDisplayText);
                      } else {
                        // This case should ideally not happen if we are in _showEditMessageDialog
                        // which is only for text-only messages, but as a fallback, add a new text part.
                        newParts.add(MessagePart.text(newDisplayText));
                      }
                      updatedMessage = message.copyWith({'parts': newParts});
                    }
                    
                    Navigator.pop(dialogContext);
                    await notifier.editMessage(updatedMessage.id, updatedMessage: updatedMessage);
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _replaceAttachment(Message messageToReplace) async {
    final notifier = ref.read(chatStateNotifierProvider(widget.chatId).notifier);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final file = result.files.single;
        final mimeType = lookupMimeType(file.name) ?? 'application/octet-stream';
        
        MessagePart newPart;
        if (mimeType.startsWith('image/')) {
          newPart = MessagePart.image(
            mimeType: mimeType,
            base64Data: base64Encode(file.bytes!),
            fileName: file.name,
          );
        } else {
          newPart = MessagePart.file(
            mimeType: mimeType,
            base64Data: base64Encode(file.bytes!),
            fileName: file.name,
          );
        }
        
        await notifier.editMessage(messageToReplace.id, newParts: [newPart]);
      }
    } catch (e) {
      debugPrint("Error replacing attachment: $e");
      if (mounted) {
        notifier.showTopMessage('替换附件时出错: $e', backgroundColor: Colors.red);
      }
    }
  }

  Future<void> _saveAttachment(Message message) async {
    final notifier = ref.read(chatStateNotifierProvider(widget.chatId).notifier);
    if (message.parts.isEmpty) return;

    final part = message.parts.first;
    if (part.base64Data == null || part.fileName == null) {
      notifier.showTopMessage('无法保存：文件数据不完整', backgroundColor: Colors.red);
      return;
    }

    try {
      final bytes = base64Decode(part.base64Data!);
      final String? savePath = await FilePicker.platform.saveFile(
        dialogTitle: '请选择保存位置',
        fileName: part.fileName!,
        bytes: bytes,
      );

      if (savePath != null) {
        notifier.showTopMessage('文件已保存到: $savePath', backgroundColor: Colors.green);
      } else {
        notifier.showTopMessage('已取消保存', backgroundColor: Colors.orange);
      }
    } catch (e) {
      debugPrint("Error saving attachment: $e");
      if (mounted) {
        notifier.showTopMessage('保存文件时出错: $e', backgroundColor: Colors.red);
      }
    }
  }

  Future<void> _forkChatFromMessage(Message message, List<Message> allMessages) async {
    final notifier = ref.read(chatStateNotifierProvider(widget.chatId).notifier);
    final newChatId = await notifier.forkChat(message);

    if (mounted && newChatId != null) {
      ref.read(activeChatIdProvider.notifier).state = newChatId;
      context.go('/chat');
    }
  }

  Future<void> _regenerateResponse(Message userMessage, List<Message> allMessages) async {
    await ref.read(chatStateNotifierProvider(widget.chatId).notifier).regenerateResponse(userMessage);
  }

  Future<void> _deleteMessage(Message messageToDelete, List<Message> allMessages) async {
    await ref.read(chatStateNotifierProvider(widget.chatId).notifier).deleteMessage(messageToDelete.id);
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
              appBar: _ChatAppBar(
                chat: chat,
                buildPopupMenuItem: _buildPopupMenuItem,
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
                                  stops: const [0.0, 0.1], // Fade over top 10%
                                ).createShader(bounds);
                              },
                              blendMode: BlendMode.dstIn,
                              child: _MessageList(
                                chatId: chatId,
                                scrollController: _scrollController,
                                onMessageTap: _handleMessageTap,
                                onSuggestionSelected: (suggestion) {
                                  _messageController.text = suggestion;
                                },
                              ),
                            )
                          : _MessageList(
                              chatId: chatId,
                              scrollController: _scrollController,
                              onMessageTap: _handleMessageTap,
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
                    _ChatInputBar(chatId: chatId, messageController: _messageController),
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

class _ChatAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final Chat chat;
  final PopupMenuItem<String> Function({
    required String value,
    required IconData icon,
    required String label,
    bool enabled,
  }) buildPopupMenuItem;

  const _ChatAppBar({
    required this.chat,
    required this.buildPopupMenuItem,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatId = chat.id;
    final chatState = ref.watch(chatStateNotifierProvider(chatId));

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(
        shadows: <Shadow>[
          Shadow(color: Colors.black.withAlpha((255 * 0.5).round()), blurRadius: 1.0)
        ],
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: '返回列表',
        onPressed: () {
          ref.read(activeChatIdProvider.notifier).state = null;
          context.go('/list');
        },
      ),
      title: Text(
        chat.title ?? '聊天',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          shadows: <Shadow>[
            Shadow(color: Colors.black.withAlpha((255 * 0.5).round()), blurRadius: 1.0)
          ],
        ),
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          tooltip: '更多选项',
          onSelected: (String result) async {
            final notifier = ref.read(chatStateNotifierProvider(chatId).notifier);
            switch (result) {
              case 'settings':
                context.push('/chat/settings');
                break;
              case 'gallery':
                context.push('/chat/gallery');
                break;
              case 'toggleOutputMode':
                notifier.toggleOutputMode();
                break;
              case 'debug':
                context.push('/chat/debug');
                break;
              case 'toggleBubbleTransparency':
                notifier.toggleBubbleTransparency();
                break;
              case 'toggleBubbleWidth':
                notifier.toggleBubbleWidthMode();
                break;
              case 'toggleMessageListHeight':
                notifier.toggleMessageListHeightMode();
                break;
              case 'exportChat':
                notifier.showTopMessage('正在准备导出文件...', backgroundColor: Colors.blueGrey, duration: const Duration(days: 1));
                try {
                  final finalExportPath = await ref.read(chatExportImportServiceProvider).exportChat(chat.id);
                  if (!context.mounted) return;
                  if (finalExportPath != null) {
                    notifier.showTopMessage('聊天已成功导出到: $finalExportPath', backgroundColor: Colors.green, duration: const Duration(seconds: 4));
                  } else if (!kIsWeb) {
                    notifier.showTopMessage('导出操作已取消或未能成功完成。', backgroundColor: Colors.orange, duration: const Duration(seconds: 3));
                  }
                } catch (e) {
                  debugPrint("导出聊天时发生错误: $e");
                  if (context.mounted) {
                    notifier.showTopMessage('导出失败: $e', backgroundColor: Colors.red);
                  }
                } finally {
                  if (context.mounted && ref.read(chatStateNotifierProvider(chat.id)).topMessageText == '正在准备导出文件...') {
                    notifier.clearTopMessage();
                  }
                }
                break;
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            buildPopupMenuItem(value: 'settings', icon: Icons.tune, label: '聊天设置'),
            buildPopupMenuItem(value: 'gallery', icon: Icons.photo_library_outlined, label: '封面与背景'),
            const PopupMenuDivider(),
            buildPopupMenuItem(value: 'toggleOutputMode', icon: chatState.isStreamMode ? Icons.stream : Icons.chat_bubble, label: chatState.isStreamMode ? '切换为一次性输出' : '切换为流式输出'),
            buildPopupMenuItem(value: 'toggleBubbleTransparency', icon: chatState.isBubbleTransparent ? Icons.opacity : Icons.opacity_outlined, label: chatState.isBubbleTransparent ? '切换为不透明气泡' : '切换为半透明气泡'),
            buildPopupMenuItem(value: 'toggleBubbleWidth', icon: chatState.isBubbleHalfWidth ? Icons.width_normal : Icons.width_wide, label: chatState.isBubbleHalfWidth ? '切换为全宽气泡' : '切换为半宽气泡'),
            buildPopupMenuItem(value: 'toggleMessageListHeight', icon: chatState.isAutoHeightEnabled ? Icons.dynamic_feed : Icons.height, label: chatState.isAutoHeightEnabled ? '关闭智能半高' : '开启智能半高'),
            const PopupMenuDivider(),
            buildPopupMenuItem(value: 'exportChat', icon: Icons.upload_file, label: '导出聊天到文件'),
            buildPopupMenuItem(value: 'debug', icon: Icons.bug_report_outlined, label: '调试页面'),
          ],
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _MessageList extends ConsumerStatefulWidget {
  final int chatId;
  final ScrollController scrollController;
  final void Function(Message, List<Message>) onMessageTap;
  final Function(String) onSuggestionSelected;

  const _MessageList({
    required this.chatId,
    required this.scrollController,
    required this.onMessageTap,
    required this.onSuggestionSelected,
  });

  @override
  ConsumerState<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends ConsumerState<_MessageList> {
  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<Message>>>(chatMessagesProvider(widget.chatId), (previous, next) {
      final isLoading = ref.read(chatStateNotifierProvider(widget.chatId)).isLoading;
      if (isLoading) return;

      if (next is AsyncData) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(chatStateNotifierProvider(widget.chatId).notifier).calculateAndStoreTokenCount();
          }
        });
      }
    });

    ref.listen<ChatScreenState>(chatStateNotifierProvider(widget.chatId), (previous, next) {
      final wasLoading = previous?.isLoading ?? false;
      if (wasLoading && !next.isLoading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(chatStateNotifierProvider(widget.chatId).notifier).calculateAndStoreTokenCount();
          }
        });
      }
    });

    final messagesAsync = ref.watch(chatMessagesProvider(widget.chatId));
    final chatState = ref.watch(chatStateNotifierProvider(widget.chatId));

    return messagesAsync.when(
      data: (messages) {
        return ListView.builder(
          reverse: true,
          controller: widget.scrollController,
          padding: const EdgeInsets.all(8.0),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[messages.length - 1 - index];
            final isLastMessage = index == 0;

            Widget buildMessageItem() {
              return MessageBubble(
                key: ValueKey(message.id),
                message: message,
                isStreaming: isLastMessage && chatState.isStreaming,
                isTransparent: chatState.isBubbleTransparent,
                isHalfWidth: chatState.isBubbleHalfWidth,
                onTap: () => widget.onMessageTap(message, messages),
                totalTokens: isLastMessage && !chatState.isStreaming ? chatState.totalTokens : null,
              );
            }
            
            Widget buildActionButtons() {
              final chatState = ref.watch(chatStateNotifierProvider(widget.chatId));
              final canPerformAction = isLastMessage &&
                                    messages.isNotEmpty &&
                                    messages.last.role == MessageRole.model &&
                                    !chatState.isLoading &&
                                    !chatState.isStreaming;

              if (!canPerformAction) return const SizedBox.shrink();

              final globalSettings = ref.watch(globalSettingsProvider);
              final notifier = ref.read(chatStateNotifierProvider(widget.chatId).notifier);

              List<Widget> buttons = [];

              // Continue Button
              buttons.add(
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('续写'),
                  onPressed: notifier.continueGeneration,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              );

              // Resume Button
              if (globalSettings.enableResume) {
                buttons.add(const SizedBox(width: 8));
                buttons.add(
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.replay_circle_filled_rounded, size: 16),
                    label: const Text('中断恢复'),
                    onPressed: notifier.resumeGeneration,
                     style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                  ),
                );
              }

              // Help Me Reply Button
              if (globalSettings.enableHelpMeReply) {
                 buttons.add(const SizedBox(width: 8));
                 buttons.add(
                  FilledButton.tonalIcon(
                    icon: chatState.isGeneratingSuggestions
                          ? const SizedBox.shrink() // Hide icon when loading
                          : const Icon(Icons.quickreply_rounded, size: 16),
                    label: chatState.isGeneratingSuggestions
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('帮我回复'),
                    onPressed: chatState.isGeneratingSuggestions ? null : () {
                      notifier.generateHelpMeReply(
                        onSuggestionsReady: (suggestions) {
                          if (!mounted) return;
                          showDialog(
                            context: context,
                            builder: (dialogContext) => _HelpMeReplyDialog(
                              chatId: widget.chatId,
                              initialSuggestions: suggestions,
                              onSuggestionSelected: widget.onSuggestionSelected,
                            ),
                          );
                        },
                      );
                    },
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.only(top: 4.0, left: 16.0),
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  alignment: WrapAlignment.start,
                  children: buttons,
                ),
              );
            }

            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  buildMessageItem(),
                  buildActionButtons(),
                ],
              );
            }
            return buildMessageItem();
          },
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => Center(child: Text("无法加载消息: $err")),
    );
  }
}


class _HelpMeReplyDialog extends ConsumerStatefulWidget {
  final int chatId;
  final List<String> initialSuggestions;
  final Function(String) onSuggestionSelected;

  const _HelpMeReplyDialog({
    required this.chatId,
    required this.initialSuggestions,
    required this.onSuggestionSelected,
  });

  @override
  ConsumerState<_HelpMeReplyDialog> createState() => _HelpMeReplyDialogState();
}

class _HelpMeReplyDialogState extends ConsumerState<_HelpMeReplyDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatStateNotifierProvider(widget.chatId));
    final notifier = ref.read(chatStateNotifierProvider(widget.chatId).notifier);
    final allSuggestionPages = chatState.helpMeReplySuggestions ?? [];
    final pageIndex = chatState.helpMeReplyPageIndex;
    final currentSuggestions = (allSuggestionPages.isNotEmpty && pageIndex < allSuggestionPages.length)
        ? allSuggestionPages[pageIndex]
        : <String>[];
    final totalPages = allSuggestionPages.length;
    final isGenerating = chatState.isGeneratingSuggestions;

    // Control animation based on state
    if (isGenerating && !_animationController.isAnimating) {
      _animationController.repeat();
    } else if (!isGenerating && _animationController.isAnimating) {
      _animationController.stop();
    }

    Widget contentWidget;
    if (isGenerating && allSuggestionPages.isEmpty) {
      contentWidget = const Center(child: CircularProgressIndicator());
    } else if (allSuggestionPages.isEmpty) {
      contentWidget = const Center(child: Text('没有可用的建议。'));
    } else {
      contentWidget = Column(
        mainAxisSize: MainAxisSize.min, // Crucial for AlertDialog content sizing
        children: currentSuggestions.map((s) => ListTile(
          title: Text(s),
          onTap: () {
            widget.onSuggestionSelected(s);
            Navigator.of(context).pop();
          },
        )).toList(),
      );
    }

    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0),
      content: contentWidget,
      actionsPadding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 12.0),
      actions: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left-aligned pagination controls
            if (totalPages > 0)
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: (isGenerating || pageIndex <= 0) ? null : () => notifier.changeHelpMeReplyPage(-1),
                  ),
                  Text('${pageIndex + 1}/$totalPages'),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: (isGenerating || pageIndex >= totalPages - 1) ? null : () => notifier.changeHelpMeReplyPage(1),
                  ),
                ],
              )
            else
              const SizedBox(), // Placeholder to keep space
            
            // Right-aligned action buttons
            Row(
              children: [
                RotationTransition(
                  turns: _animationController,
                  child: IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: '获取新选项',
                    onPressed: isGenerating ? null : () {
                      notifier.generateHelpMeReply(
                        forceRefresh: true,
                        onSuggestionsReady: (suggestions) {
                          // The dialog will rebuild automatically via the provider
                        },
                      );
                    },
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('关闭'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _ChatInputBar extends ConsumerStatefulWidget {
 final int chatId;
 final TextEditingController messageController;
 const _ChatInputBar({required this.chatId, required this.messageController});

 @override
 ConsumerState<_ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends ConsumerState<_ChatInputBar> {
 final FocusNode _inputFocusNode = FocusNode();
 final FocusNode _keyboardListenerFocusNode = FocusNode();
 final List<PlatformFile> _attachments = [];

 @override
 void initState() {
   super.initState();
   // No longer need to listen to the controller to rebuild the whole widget
   // widget.messageController.addListener(_onTextChanged);
 }

 @override
 void dispose() {
   // widget.messageController.removeListener(_onTextChanged);
   _inputFocusNode.dispose();
   _keyboardListenerFocusNode.dispose();
   super.dispose();
 }

 Future<void> _sendMessage() async {
   final notifier = ref.read(chatStateNotifierProvider(widget.chatId).notifier);
   final text = widget.messageController.text.trim();

   if (text.isEmpty && _attachments.isEmpty) {
     return;
   }
   
   List<MessagePart> parts = [];
   if (text.isNotEmpty) {
     parts.add(MessagePart.text(text));
   }

   for (var file in _attachments) {
     if (file.bytes != null) {
       final mimeType = lookupMimeType(file.name) ?? 'application/octet-stream';
       if (mimeType.startsWith('image/')) {
         parts.add(MessagePart.image(
           mimeType: mimeType,
           base64Data: base64Encode(file.bytes!),
           fileName: file.name,
         ));
       } else {
         parts.add(MessagePart.file(
           mimeType: mimeType,
           base64Data: base64Encode(file.bytes!),
           fileName: file.name,
         ));
       }
     }
   }
   
   if (parts.isNotEmpty) {
     final currentChat = await ref.read(currentChatProvider(widget.chatId).future);
     if (currentChat == null) {
       notifier.showTopMessage('错误：无法获取当前聊天信息', backgroundColor: Colors.red);
       return;
     }
     if (currentChat.apiConfigId == null) {
       notifier.showTopMessage('请先在聊天设置中选择一个 API 配置', backgroundColor: Colors.orange);
       return;
     }

     notifier.sendMessage(userParts: parts);
     widget.messageController.clear();
     setState(() {
       _attachments.clear();
     });
     if(mounted) FocusScope.of(context).unfocus();
   }
 }

 Future<void> _pickFiles() async {
   final notifier = ref.read(chatStateNotifierProvider(widget.chatId).notifier);
   try {
     FilePickerResult? result = await FilePicker.platform.pickFiles(
       allowMultiple: true,
       type: FileType.any,
       withData: true,
     );

     if (result != null) {
       setState(() {
         _attachments.addAll(result.files.where((file) => file.bytes != null));
       });
     }
   } catch (e) {
     debugPrint("Error picking files: $e");
     if (mounted) {
       notifier.showTopMessage('选择文件时出错: $e', backgroundColor: Colors.red);
     }
   }
 }

 Widget _buildAttachmentsPreview() {
   if (_attachments.isEmpty) {
     return const SizedBox.shrink();
   }

   return Container(
     height: 100,
     padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
     child: ListView.builder(
       scrollDirection: Axis.horizontal,
       itemCount: _attachments.length,
       itemBuilder: (context, index) {
         final file = _attachments[index];
         final isImage = (lookupMimeType(file.name) ?? '').startsWith('image/');
         
         return Padding(
           padding: const EdgeInsets.symmetric(horizontal: 4.0),
           child: Stack(
             clipBehavior: Clip.none,
             children: [
               Container(
                 width: 80,
                 height: 80,
                 decoration: BoxDecoration(
                   borderRadius: BorderRadius.circular(8),
                   border: Border.all(color: Colors.grey.shade400),
                 ),
                 child: isImage
                     ? ClipRRect(
                         borderRadius: BorderRadius.circular(8),
                         child: CachedImageFromBase64(
                           base64String: base64Encode(file.bytes!),
                           fit: BoxFit.cover,
                           width: 80,
                           height: 80,
                           cacheWidth: (80 * MediaQuery.of(context).devicePixelRatio).round(),
                           cacheHeight: (80 * MediaQuery.of(context).devicePixelRatio).round(),
                         ),
                       )
                     : Column(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                           const Icon(Icons.insert_drive_file_outlined, size: 32),
                           Padding(
                             padding: const EdgeInsets.symmetric(horizontal: 4.0),
                             child: Text(
                               file.name,
                               maxLines: 2,
                               overflow: TextOverflow.ellipsis,
                               style: const TextStyle(fontSize: 10),
                               textAlign: TextAlign.center,
                             ),
                           ),
                         ],
                       ),
               ),
               Positioned(
                 top: -8,
                 right: -8,
                 child: Material(
                   color: Colors.transparent,
                   child: IconButton(
                     icon: const Icon(Icons.cancel),
                     iconSize: 20,
                     splashRadius: 16,
                     onPressed: () {
                       setState(() {
                         _attachments.removeAt(index);
                       });
                     },
                     visualDensity: VisualDensity.compact,
                     padding: EdgeInsets.zero,
                     style: IconButton.styleFrom(
                       backgroundColor: Colors.white.withAlpha(204),
                     ),
                   ),
                 ),
               ),
             ],
           ),
         );
       },
     ),
   );
 }

 @override
 Widget build(BuildContext context) {
   final chatState = ref.watch(chatStateNotifierProvider(widget.chatId));

   return Column(
     mainAxisSize: MainAxisSize.min,
     children: [
       _buildAttachmentsPreview(),
       SafeArea(
         child: Container(
           padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
           margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
           decoration: BoxDecoration(
               color: Theme.of(context).cardColor.withAlpha((255 * 0.95).round()),
               borderRadius: BorderRadius.circular(30.0),
               boxShadow: const [
                 BoxShadow(
                   color: Colors.black12,
                   blurRadius: 3,
                   offset: Offset(0, 1),
                 )
               ]),
           child: KeyboardListener(
             focusNode: _keyboardListenerFocusNode,
             onKeyEvent: (KeyEvent event) {
               if (!_inputFocusNode.hasFocus) return;
               if (event is KeyDownEvent) {
                 if (event.logicalKey == LogicalKeyboardKey.enter) {
                   if (HardwareKeyboard.instance.isShiftPressed) {
                     final currentSelection = widget.messageController.selection;
                     final newText = widget.messageController.text.replaceRange(
                       currentSelection.start,
                       currentSelection.end,
                       '\n',
                     );
                     widget.messageController.value = TextEditingValue(
                       text: newText,
                       selection: TextSelection.collapsed(offset: currentSelection.start + 1),
                     );
                   } else {
                     if ((widget.messageController.text.trim().isNotEmpty || _attachments.isNotEmpty) && !chatState.isLoading) {
                       _sendMessage();
                     }
                   }
                 }
               }
             },
             child: Row(
               crossAxisAlignment: CrossAxisAlignment.end,
               children: [
                 Flexible(
                   child: TextField(
                     controller: widget.messageController,
                     focusNode: _inputFocusNode,
                     decoration: InputDecoration(
                       hintText: (chatState.isLoading || chatState.isProcessingInBackground)
                           ? '处理中... (${chatState.elapsedSeconds ?? 0}s)'
                           : '输入消息',
                       border: OutlineInputBorder(
                         borderRadius: BorderRadius.circular(25.0),
                         borderSide: BorderSide.none,
                       ),
                       filled: true,
                       fillColor: Colors.transparent,
                       contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                       isDense: false,
                     ),
                     keyboardType: TextInputType.multiline,
                     textInputAction: TextInputAction.newline,
                     minLines: 1,
                     maxLines: 5,
                     style: Theme.of(context)
                         .textTheme
                         .bodyLarge
                         ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
                   ),
                 ),
                 const SizedBox(width: 4.0),
                 if (chatState.isLoading || chatState.isProcessingInBackground)
                   Padding(
                     padding: const EdgeInsets.only(right: 4.0),
                     child: IconButton(
                       icon: const Icon(Icons.cancel),
                       tooltip: '停止生成',
                       onPressed: () async {
                         if (!mounted) return;
                         final confirm = await showDialog<bool>(
                               context: context,
                               builder: (dialogContext) => AlertDialog(
                                 title: const Text('确认停止'),
                                 content: const Text('确定要停止当前的 AI 响应或后台任务吗？'),
                                 actions: [
                                   TextButton(
                                     onPressed: () => Navigator.of(dialogContext).pop(false),
                                     child: const Text('取消'),
                                   ),
                                   TextButton(
                                     onPressed: () => Navigator.of(dialogContext).pop(true),
                                     child: Text('确认停止', style: TextStyle(color: Colors.red.shade700)),
                                   ),
                                 ],
                               ),
                             ) ?? false;
                         if (mounted && confirm) {
                           ref.read(chatStateNotifierProvider(widget.chatId).notifier).cancelGeneration();
                         }
                       },
                       style: IconButton.styleFrom(
                         foregroundColor: Colors.redAccent,
                         padding: const EdgeInsets.all(12),
                       ),
                     ),
                   ),
                 if (!chatState.isLoading && !chatState.isProcessingInBackground)
                   ValueListenableBuilder<TextEditingValue>(
                     valueListenable: widget.messageController,
                     builder: (context, value, child) {
                       final isSendMode = value.text.trim().isNotEmpty;
                       final canSendMessage = (value.text.trim().isNotEmpty || _attachments.isNotEmpty);

                       if (isSendMode) {
                         // Send Button
                         return GestureDetector(
                           onLongPress: chatState.isLoading ? null : _pickFiles,
                           child: IconButton(
                             icon: const Icon(Icons.send),
                             tooltip: '发送 (长按添加文件)',
                             onPressed: canSendMessage ? _sendMessage : null,
                             style: IconButton.styleFrom(
                               padding: const EdgeInsets.all(12),
                             ).copyWith(
                               backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                                 (Set<WidgetState> states) {
                                   if (states.contains(WidgetState.disabled)) {
                                     return Colors.grey.shade300;
                                   }
                                   return Theme.of(context).colorScheme.primary;
                                 },
                               ),
                               foregroundColor: WidgetStateProperty.resolveWith<Color?>(
                                 (Set<WidgetState> states) {
                                   if (states.contains(WidgetState.disabled)) {
                                     return Colors.grey.shade700;
                                   }
                                   return Theme.of(context).colorScheme.onPrimary;
                                 },
                               ),
                             ),
                           ),
                         );
                       } else {
                         // Add File Button
                         return IconButton(
                           icon: const Icon(Icons.add_circle_outline),
                           tooltip: '添加文件',
                           onPressed: chatState.isLoading ? null : _pickFiles,
                           style: IconButton.styleFrom(
                             padding: const EdgeInsets.all(12),
                           ),
                         );
                       }
                     },
                   ),
               ],
             ),
           ),
         ),
       ),
     ],
   );
 }
}

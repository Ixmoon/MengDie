import 'dart:async'; // For Timer
import 'dart:convert'; // For base64Decode
import 'package:file_picker/file_picker.dart'; // For picking files and save location
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Import for kIsWeb
import 'package:flutter/services.dart'; // 导入键盘服务
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart'; // For navigation
// import 'package:isar/isar.dart'; // Removed Isar import
import 'package:mime/mime.dart'; // For mime type lookup

// 导入模型、Provider、仓库、服务和 Widget
import '../models/models.dart';
import '../providers/api_key_provider.dart';
import '../providers/chat_state_providers.dart';
import '../services/chat_export_import_service.dart'; // 导入导出/导入服务
import '../services/xml_processor.dart';
import '../widgets/message_bubble.dart';
import '../widgets/top_message_banner.dart'; // 导入顶部消息横幅 Widget
import '../widgets/cached_image.dart'; // 导入缓存图片组件

// 本文件包含单个聊天会话的屏幕界面。

// --- 聊天屏幕 ---
// 使用 ConsumerStatefulWidget 以便访问 Ref 并管理本地状态（控制器、滚动等）。
class ChatScreen extends ConsumerStatefulWidget {
  final int chatId; // 通过路由传递的聊天 ID
  const ChatScreen({super.key, required this.chatId}); // 使用 super.key

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scrollController = ScrollController(); // 消息列表滚动控制器

  // _topMessageText, _topMessageColor, _topMessageTimer REMOVED - Handled by ChatStateNotifier

  @override
  void initState() {
    super.initState();
    // 新增：页面加载完成后滚动到底部
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(animate: false); // 初始加载时不使用动画, 即使是 reverse list, 确保在 0.0
    });
  }

  @override
  void dispose() {
    _scrollController.dispose(); // 清理滚动控制器
    super.dispose();
  }

  // --- _showTopMessage method REMOVED - Handled by ChatStateNotifier ---

  // --- Helper for building action ListTiles for bottom sheet ---
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
  // --- End Helper ---

  // --- Helper for building PopupMenuItems ---
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
  // --- End Helper ---

  // --- 消息气泡点击处理 ---

  // 主处理函数，当消息气泡被点击时调用
  void _handleMessageTap(Message message, List<Message> allMessages) {
    // 如果正在加载或流式传输，则忽略点击
    if (ref.read(chatStateNotifierProvider(widget.chatId)).isLoading) return;

    // 判断消息角色和位置
    final isUser = message.role == MessageRole.user;
    // final isLastMessage = allMessages.isNotEmpty && allMessages.last.id == message.id;
    final messageIndex = allMessages.indexWhere((m) => m.id == message.id);
    // 判断是否是最后一条 *用户* 消息 (后面可能跟着模型消息)
    final isLastUserMessage = isUser &&
        messageIndex >= 0 &&
        (messageIndex == allMessages.length - 1 ||
            (messageIndex == allMessages.length - 2 &&
                allMessages.last.role == MessageRole.model));

    // 使用 ModalBottomSheet 显示可用操作选项
    showModalBottomSheet(
      context: context, // 此处的 context 是 builder 的，是安全的
      builder: (modalContext) {
        // 使用 modalContext 区分
        List<Widget> options = [];

        // 1. 编辑/重新上传选项
        final isTextOnly = message.parts.length == 1 && message.parts.first.type == MessagePartType.text;
        
        // 1. Edit / Re-upload Option
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

        // 2. Save As... Option (for non-text messages)
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

        // 2. 分叉对话选项 (任何消息都可用)
        options.add(_buildBottomSheetActionItem(
          icon: Icons.fork_right_outlined,
          label: '从此消息分叉对话',
          onTap: () {
            Navigator.pop(modalContext);
            _forkChatFromMessage(message, allMessages); // 执行分叉逻辑
          },
        ));

        // 3. 重新生成选项 (仅对最后一条用户消息可用)
        if (isLastUserMessage) {
          options.add(_buildBottomSheetActionItem(
            icon: Icons.refresh_outlined,
            label: '重新生成回复',
            onTap: () {
              Navigator.pop(modalContext);
              _regenerateResponse(message, allMessages); // 执行重新生成逻辑
            },
          ));
        }

        // 4. 删除选项 (任何消息都可用，建议添加确认)
        options.add(_buildBottomSheetActionItem(
          icon: Icons.delete_outline,
          label: '删除消息',
          iconColor: Colors.red.shade400,
          textStyle: TextStyle(color: Colors.red.shade400),
          onTap: () async {
            Navigator.pop(modalContext); // 先关闭底部菜单
            // 显示删除确认对话框
            // showDialog 的 context 是安全的
            final confirm = await showDialog<bool>(
                  context: context, // 使用 _ChatScreenState 的 context
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('确认删除'),
                    content: const Text('确定删除这条消息吗？'),
                    actions: [
                      TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          child: const Text('取消')),
                      TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          child: Text('删除',
                              style: TextStyle(color: Colors.red.shade700))),
                    ],
                  ),
                ) ??
                false; // 如果对话框被关闭则默认为 false

            // 确保在异步操作 showDialog 后检查 mounted
            if (!mounted) return; // 检查 _ChatScreenState 的 mounted
            if (confirm) {
              _deleteMessage(message, allMessages); // 执行删除逻辑
            }
          },
        ));

        // 使用 SafeArea 包裹选项，避免被系统 UI 遮挡
        return SafeArea(
          child: Wrap(children: options),
        );
      },
    );
  }

  // 显示编辑消息内容的对话框
  void _showEditMessageDialog(Message message) {
    // 为普通用户消息准备单个控制器
    final singleEditController = TextEditingController(text: message.rawText);

    // 为模型消息准备两个独立的控制器
    final displayController = TextEditingController();
    final xmlController = TextEditingController();

    // 如果是模型消息，则分离显示文本和XML内容
    if (message.role == MessageRole.model) {
      displayController.text = XmlProcessor.stripXmlContent(message.rawText);
      xmlController.text = XmlProcessor.extractXmlContent(message.rawText);
    }
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        // 根据消息角色动态决定对话框内容
        Widget dialogContent;
        if (message.role == MessageRole.model) {
          // 模型消息：显示两个输入框
          dialogContent = SingleChildScrollView( // 使用 SingleChildScrollView 防止内容溢出
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('显示文本:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: displayController,
                  autofocus: true,
                  maxLines: null,
                  decoration: const InputDecoration(
                    hintText: '用户可见的纯文本内容...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('XML内容:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: xmlController,
                  maxLines: null,
                  decoration: const InputDecoration(
                    hintText: '用于逻辑处理的XML标签...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12), // 使用等宽字体以优化XML显示
                ),
              ],
            ),
          );
        } else {
          // 用户消息：显示单个输入框
          dialogContent = TextField(
            controller: singleEditController,
            autofocus: true,
            maxLines: null,
            decoration: const InputDecoration(
              hintText: '输入修改后的内容...',
              border: OutlineInputBorder(),
            ),
          );
        }

        return AlertDialog(
          title: Text(message.role == MessageRole.user ? '编辑你的消息' : '编辑模型回复'),
          content: dialogContent, // 使用动态生成的内容
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                final notifier = ref.read(chatStateNotifierProvider(widget.chatId).notifier);
                String newText;

                // 根据角色合并文本
                if (message.role == MessageRole.model) {
                  final displayPart = displayController.text.trim();
                  final xmlPart = xmlController.text.trim();
                  // 合并两部分，如果都存在则用换行符分隔
                  newText = (displayPart.isNotEmpty && xmlPart.isNotEmpty)
                      ? '$displayPart\n$xmlPart'
                      : displayPart + xmlPart;
                } else {
                  newText = singleEditController.text.trim();
                }

                // 检查内容是否有效且已更改
                if (newText.isNotEmpty && newText != message.rawText) {
                  Navigator.pop(dialogContext);
                  await notifier.editMessage(message.id, newText: newText);
                } else if (newText.isEmpty) {
                  notifier.showTopMessage('消息内容不能为空', backgroundColor: Colors.orange);
                } else {
                  // 内容未更改，直接关闭
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _replaceAttachment(Message messageToReplace) async {
    final notifier = ref.read(chatStateNotifierProvider(widget.chatId).notifier);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false, // Only one file to replace
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

  // 从指定消息处创建新的分叉对话 (现在委托给 Notifier)
  Future<void> _forkChatFromMessage(Message message, List<Message> allMessages) async {
    final notifier = ref.read(chatStateNotifierProvider(widget.chatId).notifier);
    
    // 调用 notifier 方法，该方法处理所有业务逻辑并返回新的 ID
    final newChatId = await notifier.forkChat(message);

    if (mounted && newChatId != null) {
      // 使用返回的 ID 进行导航
      context.go('/chat/$newChatId');
      // 成功消息由 notifier 自己显示
    }
    // 失败消息也由 notifier 显示，UI 层无需处理
  }

  // 为最后一条用户消息重新生成模型回复 (现在委托给 Notifier)
  Future<void> _regenerateResponse(Message userMessage, List<Message> allMessages) async {
    // 调用 Notifier 中的方法，由其处理所有业务逻辑
    await ref.read(chatStateNotifierProvider(widget.chatId).notifier).regenerateResponse(userMessage);
    // 所有 UI 反馈（加载状态、错误消息等）均由 Notifier 处理
  }


  // 删除指定的消息 (现在委托给 Notifier)
  Future<void> _deleteMessage(Message messageToDelete, List<Message> allMessages) async {
    // 调用 Notifier 中的方法，由其处理业务逻辑和 UI 反馈
    await ref.read(chatStateNotifierProvider(widget.chatId).notifier).deleteMessage(messageToDelete.id);
  }

  // --- 滚动到底部 (对于 reverse: true 的列表，底部是 0.0) ---
  void _scrollToBottom({bool animate = true}) {
    if (!_scrollController.hasClients ||
        !_scrollController.position.hasContentDimensions) {
      // debugPrint("ChatScreen: _scrollToBottom called but ScrollController not ready or list has no dimensions.");
      return;
    }

    // 对于反向列表，底部是滚动偏移量 0.0
    const double position = 0.0; // _scrollController.position.minScrollExtent;

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
    // 监听所需 Provider
    final chatAsync = ref.watch(currentChatProvider(widget.chatId)); // 当前聊天数据流
    final chatState =
        ref.watch(chatStateNotifierProvider(widget.chatId)); // 聊天屏幕 UI 状态

    // --- 监听 UI 状态变化以执行副作用 (如滚动) ---
    // Top messages are now handled by the notifier updating its state, and TopMessageBanner reacting to it.
    ref.listen<ChatScreenState>(chatStateNotifierProvider(widget.chatId),
        (previous, next) {
      // 自动滚动 (加载开始或流式传输开始时)
      if ((next.isLoading && previous?.isLoading == false) ||
          (next.isStreaming && previous?.isStreaming == false)) {
        _scrollToBottom();
      }
      // Note: If next.errorMessage is set by the notifier, and you want a specific UI reaction
      // beyond the top banner (which now reads state.topMessageText), you could handle it here.
      // For now, assuming all user-facing messages/errors go through notifier's showTopMessage.
    });

    // --- 构建 UI ---
    return chatAsync.when(
      // 处理聊天数据加载状态
      data: (chat) {
        // 聊天数据加载成功
        if (chat == null) {
          // 处理聊天不存在的情况
          return Scaffold(
              appBar: AppBar(
                  leading: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => context.go('/'))),
              body: const Center(child: Text('聊天未找到或已被删除')));
        }

        final hasBackgroundImage = chat.coverImageBase64 != null && chat.coverImageBase64!.isNotEmpty;

        // --- 使用 Stack 实现背景图层和内容图层 ---
        return Stack(
          children: [
            // --- 背景层 ---
            Positioned.fill(
              child: hasBackgroundImage
                  ? CachedImageFromBase64(
                      base64String: chat.coverImageBase64!,
                      fit: BoxFit.cover,
                      // 如果解码失败，显示纯色背景作为回退
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Theme.of(context).scaffoldBackgroundColor,
                      ),
                    )
                  : Container(color: Theme.of(context).scaffoldBackgroundColor),
            ),
            // --- 内容层 (Scaffold) ---
            Scaffold(
              backgroundColor: Colors.transparent,
              appBar: _ChatAppBar(
                chatId: widget.chatId,
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
                        ref.read(chatStateNotifierProvider(widget.chatId).notifier).clearTopMessage();
                      },
                    ),
                    if (chatState.isMessageListHalfHeight) const Spacer(),
                    Flexible(
                      flex: 1,
                      child: _MessageList(
                        chatId: widget.chatId,
                        scrollController: _scrollController,
                        onMessageTap: _handleMessageTap,
                      ),
                    ),
                    if (chatState.isLoading && !chatState.isStreaming && chatState.generationStartTime == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 0),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    _ChatInputBar(chatId: widget.chatId),
                  ],
                ),
              ),
            ),
          ], // 结束 Stack children
        );
      },
      // --- 聊天数据加载状态 ---
      loading: () => Scaffold(
          appBar: AppBar(
              leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.go('/'))),
          body: const Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(
          appBar: AppBar(
              leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.go('/'))),
          body: Center(child: Text('无法加载聊天数据: $error'))),
   );
 }
}

// --- 封装的私有小部件 ---

/// 聊天屏幕的 AppBar
class _ChatAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final int chatId;
  final Chat chat;
  final PopupMenuItem<String> Function({
    required String value,
    required IconData icon,
    required String label,
    bool enabled,
  }) buildPopupMenuItem;

  const _ChatAppBar({
    required this.chatId,
    required this.chat,
    required this.buildPopupMenuItem,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(chatStateNotifierProvider(chatId));

    return AppBar(
      elevation: Theme.of(context).appBarTheme.elevation,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: '返回列表',
        onPressed: () => context.go('/'),
      ),
      title: Text(chat.title ?? '聊天', maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          tooltip: '更多选项',
          onSelected: (String result) async {
            final notifier = ref.read(chatStateNotifierProvider(chatId).notifier);
            switch (result) {
              case 'settings':
                context.push('/chat/$chatId/settings');
                break;
              case 'gallery':
                context.push('/chat/$chatId/gallery');
                break;
              case 'toggleOutputMode':
                notifier.toggleOutputMode();
                break;
              case 'debug':
                context.push('/chat/$chatId/debug');
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
                  final finalExportPath = await ref.read(chatExportImportServiceProvider).exportChat(chatId);
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
                  if (context.mounted && ref.read(chatStateNotifierProvider(chatId)).topMessageText == '正在准备导出文件...') {
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
            buildPopupMenuItem(value: 'toggleMessageListHeight', icon: chatState.isMessageListHalfHeight ? Icons.height : Icons.unfold_more, label: chatState.isMessageListHalfHeight ? '切换为全高列表' : '切换为半高列表'),
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


/// 聊天消息列表
class _MessageList extends ConsumerWidget {
  final int chatId;
  final ScrollController scrollController;
  final void Function(Message, List<Message>) onMessageTap;

  const _MessageList({
    required this.chatId,
    required this.scrollController,
    required this.onMessageTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(chatMessagesProvider(chatId));
    final chatState = ref.watch(chatStateNotifierProvider(chatId));

    return messagesAsync.when(
      data: (messages) {
        // Trigger initial token calculation when messages are first loaded.
        // Using a post-frame callback ensures that the notifier call doesn't happen
        // during the build phase, which is an anti-pattern.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (ref.read(chatStateNotifierProvider(chatId)).totalTokens == null && messages.isNotEmpty) {
            ref.read(chatStateNotifierProvider(chatId).notifier).calculateAndStoreTokenCount();
          }
        });

        return ListView.builder(
          reverse: true,
          controller: scrollController,
          padding: const EdgeInsets.all(8.0),
          itemCount: messages.length + (chatState.isStreaming ? 1 : 0),
          itemBuilder: (context, index) {
            final bool isLastMessage = !chatState.isStreaming && index == 0;

            if (chatState.isStreaming) {
              if (index == 0) {
                final streamingMessage = Message.create(
                  chatId: chatId,
                  rawText: chatState.streamingMessageContent ?? "",
                  role: MessageRole.model,
                  timestamp: chatState.streamingTimestamp,
                );
                return MessageBubble(message: streamingMessage, isStreaming: true);
              } else {
                final message = messages[messages.length - index];
                return MessageBubble(
                  key: ValueKey(message.id),
                  message: message,
                  isTransparent: chatState.isBubbleTransparent,
                  isHalfWidth: chatState.isBubbleHalfWidth,
                  onTap: () => onMessageTap(message, messages),
                );
              }
            } else {
              final message = messages[messages.length - 1 - index];
              return MessageBubble(
                key: ValueKey(message.id),
                message: message,
                isTransparent: chatState.isBubbleTransparent,
                isHalfWidth: chatState.isBubbleHalfWidth,
                onTap: () => onMessageTap(message, messages),
                totalTokens: isLastMessage ? chatState.totalTokens : null,
              );
            }
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text("无法加载消息: $err")),
    );
  }
}

// --- 独立的输入栏 Widget ---
class _ChatInputBar extends ConsumerStatefulWidget {
 final int chatId;
 const _ChatInputBar({required this.chatId});

 @override
 ConsumerState<_ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends ConsumerState<_ChatInputBar> {
 final TextEditingController _messageController = TextEditingController();
 final FocusNode _inputFocusNode = FocusNode();
 final FocusNode _keyboardListenerFocusNode = FocusNode();
 final List<PlatformFile> _attachments = [];

 @override
 void dispose() {
   _messageController.dispose();
   _inputFocusNode.dispose();
   _keyboardListenerFocusNode.dispose();
   super.dispose();
 }

 Future<void> _sendMessage() async {
   final notifier = ref.read(chatStateNotifierProvider(widget.chatId).notifier);
   final text = _messageController.text.trim();

   if (text.isEmpty && _attachments.isEmpty) {
     return; // Nothing to send
   }
   // API Key check now happens in the notifier
   
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
     // Check for API keys before sending
     if (ref.read(apiKeyNotifierProvider).keys.isEmpty) {
        notifier.showTopMessage('请先在全局设置中添加 API Key', backgroundColor: Colors.orange);
        return;
     }
     notifier.sendMessage(userParts: parts);
     _messageController.clear();
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
       withData: true, // Ensure bytes are loaded
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
                         child: Image.memory(file.bytes!, fit: BoxFit.cover),
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
   // Listen to the chat state for loading indicators, etc.
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
                     final currentSelection = _messageController.selection;
                     final newText = _messageController.text.replaceRange(
                       currentSelection.start,
                       currentSelection.end,
                       '\n',
                     );
                     _messageController.value = TextEditingValue(
                       text: newText,
                       selection: TextSelection.collapsed(offset: currentSelection.start + 1),
                     );
                   } else {
                     if ((_messageController.text.trim().isNotEmpty || _attachments.isNotEmpty) && !chatState.isLoading) {
                       _sendMessage();
                     }
                   }
                 }
               }
             },
             child: Row(
               crossAxisAlignment: CrossAxisAlignment.end,
               children: [
                 Padding(
                   padding: const EdgeInsets.only(left: 4.0, right: 4.0, bottom: 4.0),
                   child: IconButton(
                     icon: const Icon(Icons.add_circle_outline),
                     tooltip: '添加文件',
                     onPressed: chatState.isLoading ? null : _pickFiles,
                   ),
                 ),
                 Flexible(
                   child: TextField(
                     controller: _messageController,
                     focusNode: _inputFocusNode,
                     decoration: InputDecoration(
                       hintText: '输入消息 (Shift+Enter 换行)...',
                       border: OutlineInputBorder(
                         borderRadius: BorderRadius.circular(25.0),
                         borderSide: BorderSide.none,
                       ),
                       filled: true,
                       fillColor: Colors.transparent,
                       contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                       isDense: false,
                       prefixIcon: chatState.generationStartTime != null
                           ? Padding(
                               padding: const EdgeInsets.only(left: 12.0, right: 8.0),
                               child: Row(
                                 mainAxisSize: MainAxisSize.min,
                                 children: [
                                   const SizedBox(
                                       width: 12,
                                       height: 12,
                                       child: CircularProgressIndicator(strokeWidth: 2)),
                                   const SizedBox(width: 8),
                                   Text(
                                     '思考中... (${chatState.elapsedSeconds ?? 0}s)',
                                     style: Theme.of(context)
                                         .textTheme
                                         .bodySmall
                                         ?.copyWith(color: Colors.grey.shade600),
                                     overflow: TextOverflow.ellipsis,
                                   ),
                                 ],
                               ),
                             )
                           : null,
                     ),
                     keyboardType: TextInputType.multiline,
                     textInputAction: TextInputAction.newline,
                     enabled: !chatState.isLoading,
                     minLines: 1,
                     maxLines: 5,
                     style: Theme.of(context)
                         .textTheme
                         .bodyLarge
                         ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
                   ),
                 ),
                 const SizedBox(width: 4.0),
                 if (chatState.generationStartTime != null)
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
                                 title: const Text('确认停止生成'),
                                 content: const Text('确定要停止当前的 AI 响应生成吗？已生成的部分将保留。'),
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
                 if (chatState.generationStartTime == null)
                   IconButton(
                     icon: const Icon(Icons.send),
                     onPressed: chatState.isLoading || (_messageController.text.trim().isEmpty && _attachments.isEmpty) ? null : _sendMessage,
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
                     tooltip: '发送',
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

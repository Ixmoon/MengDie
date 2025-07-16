import 'dart:async'; // For Timer
import 'dart:convert'; // For base64Decode
import 'package:file_picker/file_picker.dart'; // For picking files and save location
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Import for kIsWeb
import 'package:flutter/services.dart'; // 导入键盘服务
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/rendering.dart'; // For ScrollDirection

import 'package:go_router/go_router.dart'; // For navigation
import 'package:image_picker/image_picker.dart';
// import 'package:isar/isar.dart'; // Removed Isar import
import 'package:mime/mime.dart'; // For mime type lookup
import 'package:shared_preferences/shared_preferences.dart'; // 导入 shared_preferences

// 导入模型、Provider、仓库、服务和 Widget
import '../../data/models/models.dart';
import '../providers/repository_providers.dart';
import '../providers/chat_state_providers.dart';
import '../../service/process/chat_export_import.dart'; // 导入导出/导入服务
import '../widgets/message_bubble.dart';
import '../widgets/top_message_banner.dart'; // 导入顶部消息横幅 Widget
import '../widgets/cached_image.dart'; // 导入缓存图片组件
import '../providers/settings_providers.dart'; // 导入全局设置
import '../providers/api_key_provider.dart';
import '../../data/database/sync/sync_service.dart'; // 导入同步服务

// 本文件包含了应用的核心聊天界面。
//
// #############################################################################
// # 核心设计与关键问题修复记录
// #############################################################################
//
// 1. **异步操作后的安全导航 (Safe Navigation After Async Operations)**:
//    - **问题**: 在 `_ChatAppBar` 的菜单中，如果一个菜单项的操作包含 `await`（例如“另存为模板”），
//      并且在 `await` 之后立即调用 `context.push()` 进行导航，会引发 "deactivated widget" 错误。
//    - **根源**: 这是 `PopupMenuButton` 的生命周期与 `GoRouter` 导航之间的竞态条件。`onSelected`
//      回调是同步触发的，当 `await` 暂停函数执行时，`PopupMenu` 开始关闭动画并自我销毁。当 `await`
//      完成后，`PopupMenu` 的 `context` 已失效或处于不稳定状态，此时执行导航就会崩溃。
//    - **最终解决方案**: 将 `PopupMenuButton` 重构为手动的 `IconButton` + `showMenu` 调用。
//      `showMenu` 函数返回一个 `Future`，该 `Future` 会在菜单完全关闭后完成。通过 `await showMenu(...)`，
//      我们可以确保在执行任何后续操作（包括导航）之前，弹出菜单的生命周期已完全结束，从而根除此问题。
//      这是处理 Flutter 中异步UI事件流的黄金标准。
//
// 2. **PageView 与 Riverpod 状态同步**:
//    - `ChatScreen` 使用 `PageController` 来同步 `activeChatIdProvider` 的状态。当用户滑动页面时，
//      `onPageChanged` 会更新 `activeChatIdProvider`。反之，当 `activeChatIdProvider` 从外部
//      改变时（例如，从列表页点击进入），`_ChatScreenState` 的 `build` 方法会检测到索引不一致，
//      并通过 `jumpToPage` 更新 `PageController` 的位置，实现了双向同步。
//
// #############################################################################
//
// 主要功能和组件包括：
// 1. **ChatScreen**: 使用 PageView 实现的可左右滑动的聊天容器，用于在同一文件夹内的聊天之间切换。
// 2. **ChatPageContent**: 单个聊天页面的完整内容，包括消息列表、输入框和应用栏。
// 3. **_ChatAppBar**: 顶部的应用栏，显示聊天标题并提供一个通过 `showMenu` 实现的、生命周期安全的操作菜单。
// 4. **_MessageList**: 显示聊天消息的列表，支持无限滚动加载和消息项的交互。
// 5. **_ChatInputBar**: 底部的输入区域，支持文本和文件附件的发送。
// 6. **封面图片管理**: 提供了从菜单直接设置、导出和移除聊天背景封面的功能。
//
// 文件结构：
// - `ChatScreen` (StatefulWidget): 作为 PageView 的宿主，管理页面切换逻辑。
// - `_ChatPageContentState` (State): 管理单个聊天页面的状态和核心业务逻辑。
// - `_ChatAppBar` (ConsumerWidget): 接收回调函数以处理菜单操作。
// - `_MessageList` (ConsumerStatefulWidget): 负责消息的展示和相关UI逻辑。
// - `_ChatInputBar` (ConsumerStatefulWidget): 负责用户输入的处理。
  
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
    // 当整个 ChatScreen 被销毁时（例如，用户返回到列表页），触发一次最终的静默同步。
    // 这是确保“退出时保存”的正确位置，因为它不受内部 PageView 页面切换的影响。
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
  bool _isPushing = false;

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
    // 退出时自动保存的逻辑已被移除，因为它会导致在克隆等非导航操作中意外触发。
    // 数据的持久化应由更明确的操作（如发送消息、编辑、手动同步）来保证。
    // SyncService.instance.forcePushChanges();

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

    // Check for data integrity first
    if (part.base64Data == null) {
      notifier.showTopMessage('无法保存：文件数据为空', backgroundColor: Colors.red);
      return;
    }

    String fileName;
    // Special handling for generated images that don't have an initial file name
    if (part.type == MessagePartType.generatedImage) {
      // For generated images, the prompt is stored in the 'text' field.
      final promptText = part.text ?? 'generated_image';
      // Sanitize and shorten the prompt to create a valid file name.
      final sanitizedPrompt = promptText.replaceAll(RegExp(r'[\s\\/:*?"<>|]+'), '_');
      final snippet = sanitizedPrompt.substring(0, sanitizedPrompt.length > 50 ? 50 : sanitizedPrompt.length);
      fileName = '${snippet}_${DateTime.now().millisecondsSinceEpoch}.png';
    } else if (part.fileName == null) {
      // For other types, if fileName is still null, then it's an error
      notifier.showTopMessage('无法保存：文件名丢失', backgroundColor: Colors.red);
      return;
    } else {
      fileName = part.fileName!;
    }

    try {
      final bytes = base64Decode(part.base64Data!);
      final String? savePath = await FilePicker.platform.saveFile(
        dialogTitle: '请选择保存位置',
        fileName: fileName, // Use the determined or generated file name
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
    // forkChat 现在会自动处理用户绑定
    final newChatId = await notifier.forkChat(message);

    if (mounted && newChatId != null) {
      ref.read(activeChatIdProvider.notifier).state = newChatId;
      // 页面将通过 activeChatIdProvider 的变化自动更新
    }
  }

  Future<void> _regenerateResponse(Message userMessage, List<Message> allMessages) async {
    await ref.read(chatStateNotifierProvider(widget.chatId).notifier).regenerateResponse(userMessage);
  }

  Future<void> _deleteMessage(Message messageToDelete, List<Message> allMessages) async {
    await ref.read(chatStateNotifierProvider(widget.chatId).notifier).deleteMessage(messageToDelete.id);
  }

  // --- 业务逻辑：手动触发差异化推送 ---
  Future<void> _handleForcePush() async {
    if (_isPushing) return;

    setState(() => _isPushing = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('正在上传本地变更...'),
        duration: Duration(seconds: 2),
      ),
    );

    final success = await SyncService.instance.forcePushChanges();
    
    if (mounted) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(success ? '上传成功' : '上传失败或无需上传'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      setState(() => _isPushing = false);
    }
  }

  // --- 业务逻辑：选择并设置封面图片 (Base64) ---
  Future<void> _pickAndSetCoverImageBase64(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: source);
      if (image == null) {
        debugPrint("图片选择已取消。");
        return;
      }

      final Uint8List imageBytes = await image.readAsBytes();
      final String newBase64String = base64Encode(imageBytes);

      final chat = ref.read(currentChatProvider(widget.chatId)).value;
      if (chat != null) {
        final chatToUpdate = chat.copyWith({'coverImageBase64': newBase64String});
        await ref.read(chatRepositoryProvider).saveChat(chatToUpdate);
        if (mounted) {
          ref.read(chatStateNotifierProvider(widget.chatId).notifier).showTopMessage('封面图片已更新', backgroundColor: Colors.green);
        }
      }
    } catch (e) {
      debugPrint("设置封面图片 (Base64) 时出错: $e");
      if (mounted) {
        ref.read(chatStateNotifierProvider(widget.chatId).notifier).showTopMessage('图片处理失败: $e', backgroundColor: Colors.red);
      }
    }
  }

  // --- 业务逻辑：导出封面图片 ---
  Future<void> _exportImage() async {
    final notifier = ref.read(chatStateNotifierProvider(widget.chatId).notifier);
    final chat = ref.read(currentChatProvider(widget.chatId)).value;
    final String? base64String = chat?.coverImageBase64;

    if (base64String == null || base64String.isEmpty) {
      notifier.showTopMessage('没有可导出的图片', backgroundColor: Colors.orange);
      return;
    }

    try {
      final Uint8List imageBytes = base64Decode(base64String);
      final sanitizedTitle = chat?.title?.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_') ?? 'chat_${widget.chatId}';
      final suggestedFileName = 'cover_$sanitizedTitle.jpg';
      
      // 使用 file_picker 保存文件
      final String? savePath = await FilePicker.platform.saveFile(
        dialogTitle: '请选择封面保存位置',
        fileName: suggestedFileName,
        bytes: imageBytes,
      );

      if (mounted) {
        if (savePath != null) {
          notifier.showTopMessage('封面已保存到: $savePath', backgroundColor: Colors.green);
        } else {
          notifier.showTopMessage('已取消保存', backgroundColor: Colors.orange);
        }
      }
    } catch (e) {
      debugPrint("导出封面时出错: $e");
      if (mounted) {
        notifier.showTopMessage('导出封面失败: $e', backgroundColor: Colors.red);
      }
    }
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
                onSetCoverImage: () => _pickAndSetCoverImageBase64(ImageSource.gallery),
                onExportCoverImage: _exportImage,
                onRemoveCoverImage: () async {
                  final chatToUpdate = ref.read(currentChatProvider(widget.chatId)).value;
                  if (chatToUpdate != null) {
                    final updatedChat = chatToUpdate.copyWith({'coverImageBase64': null});
                    await ref.read(chatRepositoryProvider).saveChat(updatedChat);
                    if (mounted) {
                      ref.read(chatStateNotifierProvider(widget.chatId).notifier).showTopMessage('封面图片已移除', backgroundColor: Colors.green);
                    }
                  }
                },
                onForcePush: _handleForcePush,
                isPushing: _isPushing,
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
  final VoidCallback onSetCoverImage;
  final VoidCallback onExportCoverImage;
  final VoidCallback onRemoveCoverImage;
  final VoidCallback onForcePush;
  final bool isPushing;

  const _ChatAppBar({
    required this.chat,
    required this.buildPopupMenuItem,
    required this.onSetCoverImage,
    required this.onExportCoverImage,
    required this.onRemoveCoverImage,
    required this.onForcePush,
    required this.isPushing,
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
        isPushing
            ? const Padding(
                padding: EdgeInsets.all(12.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.0),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.upload_outlined),
                tooltip: '上传本地变更',
                onPressed: onForcePush,
              ),
        IconButton(
          icon: const Icon(Icons.more_vert),
          tooltip: '更多选项',
          onPressed: () async {
            final renderBox = context.findRenderObject() as RenderBox;
            final position = renderBox.localToGlobal(Offset.zero) & renderBox.size;

            final String? result = await showMenu<String>(
              context: context,
              position: RelativeRect.fromLTRB(position.right, position.top, position.right, position.bottom),
              items: <PopupMenuEntry<String>>[
                buildPopupMenuItem(value: 'settings', icon: Icons.tune, label: '聊天设置'),
                const PopupMenuDivider(),
                buildPopupMenuItem(value: 'setCoverImage', icon: Icons.photo_library_outlined, label: '设置封面'),
                buildPopupMenuItem(
                  value: 'exportCoverImage',
                  icon: Icons.upload_file_outlined,
                  label: '导出封面',
                  enabled: chat.coverImageBase64 != null && chat.coverImageBase64!.isNotEmpty,
                ),
                buildPopupMenuItem(
                  value: 'removeCoverImage',
                  icon: Icons.delete_outline,
                  label: '移除封面',
                  enabled: chat.coverImageBase64 != null && chat.coverImageBase64!.isNotEmpty,
                ),
                const PopupMenuDivider(),
                buildPopupMenuItem(value: 'toggleOutputMode', icon: chatState.isStreamMode ? Icons.stream : Icons.chat_bubble, label: chatState.isStreamMode ? '切换为一次性输出' : '切换为流式输出'),
                buildPopupMenuItem(value: 'toggleBubbleTransparency', icon: chatState.isBubbleTransparent ? Icons.opacity : Icons.opacity_outlined, label: chatState.isBubbleTransparent ? '切换为不透明气泡' : '切换为半透明气泡'),
                buildPopupMenuItem(value: 'toggleBubbleWidth', icon: chatState.isBubbleHalfWidth ? Icons.width_normal : Icons.width_wide, label: chatState.isBubbleHalfWidth ? '切换为全宽气泡' : '切换为半宽气泡'),
                buildPopupMenuItem(value: 'toggleMessageListHeight', icon: chatState.isAutoHeightEnabled ? Icons.dynamic_feed : Icons.height, label: chatState.isAutoHeightEnabled ? '关闭智能半高' : '开启智能半高'),
                const PopupMenuDivider(),
                buildPopupMenuItem(value: 'exportChat', icon: Icons.file_download_outlined, label: '导出到文件'),
                buildPopupMenuItem(value: 'exportAsTemplate', icon: Icons.flip_to_front_outlined, label: '另存为模板'),
                buildPopupMenuItem(value: 'exportAsChat', icon: Icons.control_point_duplicate_outlined, label: '克隆为新聊天'),
                const PopupMenuDivider(),
                buildPopupMenuItem(value: 'debug', icon: Icons.bug_report_outlined, label: '调试页面'),
              ],
            );

            // 在 await 之后，PopupMenu 已经完全关闭，可以安全地执行任何操作。
            if (result == null || !context.mounted) return;

            final notifier = ref.read(chatStateNotifierProvider(chatId).notifier);
            switch (result) {
              case 'settings':
                context.push('/chat/settings');
                break;
              case 'setCoverImage':
                onSetCoverImage();
                break;
              case 'exportCoverImage':
                onExportCoverImage();
                break;
              case 'removeCoverImage':
                onRemoveCoverImage();
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
              case 'exportAsTemplate':
                try {
                  final repo = ref.read(chatRepositoryProvider);
                  await repo.cloneChat(chat.id, asTemplate: true);
                  if (!context.mounted) return;
                  notifier.showTopMessage('已成功另存为模板', backgroundColor: Colors.green);
                  ref.invalidate(chatListProvider((parentFolderId: null, mode: ChatListMode.templateManagement)));
                  // 导航已移除，以避免触发额外的保存操作。用户可手动返回查看。
                } catch (e) {
                  if (context.mounted) {
                    notifier.showTopMessage('另存为模板失败: $e', backgroundColor: Colors.red);
                  }
                }
                break;
              case 'exportAsChat':
                try {
                  final repo = ref.read(chatRepositoryProvider);
                  final newChatId = await repo.cloneChat(chat.id, asTemplate: false);
                  if (!context.mounted) return;
                  notifier.showTopMessage('已成功克隆为新聊天', backgroundColor: Colors.green);
                  // 自动切换页面已移除，以避免触发额外的保存操作。新聊天可在列表中找到。
                } catch (e) {
                  if (context.mounted) {
                    notifier.showTopMessage('克隆为新聊天失败: $e', backgroundColor: Colors.red);
                  }
                }
                break;
            }
          },
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
      // 当消息列表数据更新时，或首次加载时，重新计算 Token 数量。
      // 这是Token计算的唯一触发点，以避免重复计算。
      
      // 1. 利用 AsyncValue 的 `==` 操作符，仅在状态确实发生变化时才继续。
      //    这能处理从 loading -> data，以及 data -> new data 的情况。
      if (previous == next) return;

      // 2. 我们只关心包含有效数据的状态。
      if (next is! AsyncData || !next.hasValue || next.requireValue.isEmpty) {
        return;
      }

      // 3. 如果正在进行其他加载操作，则不计算。
      final chatState = ref.read(chatStateNotifierProvider(widget.chatId));
      if (chatState.isLoading) return;
      
      // 4. 执行计算。
      ref.read(chatStateNotifierProvider(widget.chatId).notifier).calculateAndStoreTokenCount();
    });

    final messagesAsync = ref.watch(chatMessagesProvider(widget.chatId));
    final chatState = ref.watch(chatStateNotifierProvider(widget.chatId));

    return messagesAsync.when(
      data: (dbMessages) {
        // 当UI构建时，如果发现没有 token 数据，则主动触发一次计算。
        if ((chatState.totalTokens ?? 0) == 0 && !chatState.isLoading && dbMessages.isNotEmpty) {
          // 关键修复：在触发计算之前，同样检查API配置是否存在，以避免不必要的重复调用。
          final apiConfigs = ref.read(apiKeyNotifierProvider).apiConfigs;
          if (apiConfigs.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ref.read(chatStateNotifierProvider(widget.chatId).notifier).calculateAndStoreTokenCount();
              }
            });
          }
        }
        
        final streamingMessage = chatState.streamingMessage;
        final List<Message> allMessages;

        if (chatState.isStreamingMessageVisible && streamingMessage != null) {
          // If a streaming/processing message exists, use it as the source of truth.
          // Remove any message from the DB list that has the same ID to prevent duplicates.
          final tempMessages = dbMessages.where((m) => m.id != streamingMessage.id).toList();
          tempMessages.add(streamingMessage);
          allMessages = tempMessages;
        } else {
          // Otherwise, just use the messages from the database.
          allMessages = dbMessages;
        }

        return ListView.builder(
          reverse: true,
          controller: widget.scrollController,
          padding: const EdgeInsets.all(8.0),
          itemCount: allMessages.length,
          itemBuilder: (context, index) {
            final message = allMessages[allMessages.length - 1 - index];
            final isLastMessage = index == 0;
            // A message is considered "streaming" if it's the one currently in the state's cache.
            final isThisMessageStreaming = chatState.isStreaming && streamingMessage != null && message.id == streamingMessage.id;

            Widget buildMessageItem() {
              return MessageBubble(
                key: ValueKey(message.id),
                message: message,
                isStreaming: isThisMessageStreaming,
                isTransparent: chatState.isBubbleTransparent,
                isHalfWidth: chatState.isBubbleHalfWidth,
                onTap: () => widget.onMessageTap(message, allMessages),
                totalTokens: isLastMessage && !isThisMessageStreaming ? chatState.totalTokens : null,
              );
            }
            
            Widget buildActionButtons() {
              final chatState = ref.watch(chatStateNotifierProvider(widget.chatId));
              // The action buttons should only appear when the entire generation process is complete.
              // This is now solely determined by the `isLoading` flag.
              final canPerformAction = isLastMessage &&
                                     allMessages.isNotEmpty &&
                                     allMessages.last.role == MessageRole.model &&
                                     !chatState.isLoading;

              if (!canPerformAction) return const SizedBox.shrink();

              final chat = ref.watch(currentChatProvider(widget.chatId)).value;
              final globalSettings = ref.watch(globalSettingsProvider);
              final notifier = ref.read(chatStateNotifierProvider(widget.chatId).notifier);

              if (chat == null) return const SizedBox.shrink();

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

              // Help Me Reply / Cancel Button
              if (chat.enableHelpMeReply) {
                buttons.add(const SizedBox(width: 8));
                if (chatState.isGeneratingSuggestions) {
                  // Show a contextual cancel button
                  buttons.add(
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('取消'),
                      onPressed: () => notifier.cancelGeneration(),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        backgroundColor: Colors.red.withAlpha((255 * 0.1).round()),
                        foregroundColor: Colors.red.shade700,
                      ),
                    ),
                  );
                } else {
                  // Show the "Help Me Reply" button
                  buttons.add(
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.quickreply_rounded, size: 16),
                      label: const Text('帮我回复'),
                      onPressed: () {
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
      contentWidget = Container(
        width: double.maxFinite, // 让ListView.builder正确工作
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6, // 限制最大高度
        ),
        child: ListView( // 使用ListView替代Column以获得滚动能力
          shrinkWrap: true, // 使ListView的高度适应其内容
          children: currentSuggestions.map((s) => ListTile(
            title: Text(s),
            onTap: () {
              widget.onSuggestionSelected(s);
              Navigator.of(context).pop();
            },
          )).toList(),
        ),
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
 bool _isImageGenerationMode = false;

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

   // 如果文本和附件都为空，并且不是在图片生成模式下，则不执行任何操作
   if (text.isEmpty && _attachments.isEmpty) {
     return;
   }

   // 图片生成模式逻辑
   if (_isImageGenerationMode) {
     if (text.isNotEmpty) {
       notifier.generateImage(text);
       widget.messageController.clear();
       if (mounted) FocusScope.of(context).unfocus();
     } else {
       notifier.showTopMessage('请输入图片描述。', backgroundColor: Colors.orange);
     }
     return; // 图片生成后直接返回
   }

   // 普通聊天模式逻辑
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
       } else if (mimeType.startsWith('audio/')) {
         parts.add(MessagePart.audio(
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
     final apiConfigs = ref.read(apiKeyNotifierProvider).apiConfigs;
     if (apiConfigs.isEmpty) {
       notifier.showTopMessage('请先在全局设置中添加至少一个 API 配置', backgroundColor: Colors.orange);
       return;
     }

     notifier.sendMessage(userParts: parts);
     widget.messageController.clear();
     setState(() {
       _attachments.clear();
     });
     if (mounted) FocusScope.of(context).unfocus();
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
         final mimeType = lookupMimeType(file.name) ?? '';
         final isImage = mimeType.startsWith('image/');
         final isAudio = mimeType.startsWith('audio/');

         Widget previewChild;
         if (isImage) {
           previewChild = ClipRRect(
             borderRadius: BorderRadius.circular(8),
             child: CachedImageFromBase64(
               base64String: base64Encode(file.bytes!),
               fit: BoxFit.cover,
               width: 80,
               height: 80,
               cacheWidth: (80 * MediaQuery.of(context).devicePixelRatio).round(),
               cacheHeight: (80 * MediaQuery.of(context).devicePixelRatio).round(),
             ),
           );
         } else if (isAudio) {
           previewChild = Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               const Icon(Icons.audiotrack_outlined, size: 32),
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
           );
         } else {
           previewChild = Column(
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
           );
         }
         
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
                 child: previewChild,
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
                // --- 切换图片生成模式按钮 ---
                IconButton(
                  icon: const Icon(Icons.image_outlined),
                  tooltip: '切换图片生成模式',
                  color: _isImageGenerationMode ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                  style: _isImageGenerationMode
                    ? IconButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1))
                    : null,
                  onPressed: () {
                    setState(() {
                      _isImageGenerationMode = !_isImageGenerationMode;
                      if (_isImageGenerationMode && _attachments.isNotEmpty) {
                        _attachments.clear(); // 进入图片模式时清除附件
                        ref.read(chatStateNotifierProvider(widget.chatId).notifier)
                          .showTopMessage('附件已清除，图片生成模式不支持附件', backgroundColor: Colors.orange);
                      }
                    });
                  },
                ),
                 Flexible(
                   child: TextField(
                     controller: widget.messageController,
                     focusNode: _inputFocusNode,
                     decoration: InputDecoration(
                       hintText: _isImageGenerationMode
                          ? '输入图片描述...'
                          : ((chatState.isLoading || chatState.isProcessingInBackground)
                              ? '处理中... (${chatState.elapsedSeconds ?? 0}s)'
                              : '输入消息'),
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
                 if (chatState.isLoading || chatState.isProcessingInBackground) // Removed isGeneratingSuggestions check
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

                       if (isSendMode || _isImageGenerationMode) {
                         // Send Button
                         return GestureDetector(
                           onLongPress: (chatState.isLoading || _isImageGenerationMode) ? null : _pickFiles,
                           child: IconButton(
                             icon: const Icon(Icons.send),
                             tooltip: _isImageGenerationMode ? '生成图片' : '发送 (长按添加文件)',
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
                           onPressed: (chatState.isLoading || _isImageGenerationMode) ? null : _pickFiles,
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

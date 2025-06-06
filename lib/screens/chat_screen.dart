import 'dart:async'; // For Timer
import 'dart:convert'; // For base64Decode
import 'dart:typed_data'; // For Uint8List
import 'dart:io'; // For File operations (file picker, file copy, IF background image were still path based)
import 'package:file_picker/file_picker.dart'; // For picking files and save location
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Import for kIsWeb
import 'package:flutter/services.dart'; // 导入键盘服务
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p; // For path manipulation
import 'package:go_router/go_router.dart'; // For navigation
// import 'package:isar/isar.dart'; // Removed Isar import

// 导入模型、Provider、仓库、服务和 Widget
import '../models/models.dart';
import '../providers/api_key_provider.dart';
import '../providers/chat_state_providers.dart';
import '../repositories/chat_repository.dart';
import '../repositories/message_repository.dart';
import '../services/chat_export_import_service.dart'; // 导入导出/导入服务
import '../widgets/message_bubble.dart';
import '../widgets/top_message_banner.dart'; // 导入顶部消息横幅 Widget

// Helper class for _forkChatFromMessage prerequisites
class _ForkPrerequisites {
  final Chat originalChat;
  final List<Message> messagesToKeep;
  _ForkPrerequisites({required this.originalChat, required this.messagesToKeep});
}

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
  final TextEditingController _messageController =
      TextEditingController(); // 消息输入框控制器
  final ScrollController _scrollController = ScrollController(); // 消息列表滚动控制器
  final FocusNode _inputFocusNode = FocusNode(); // 输入框焦点节点
  final FocusNode _keyboardListenerFocusNode =
      FocusNode(); // RawKeyboardListener 的焦点节点
  int? _previousMessagesCount; // 用于检测消息数量变化以触发自动滚动
  ChatScreenState? _previousChatState; // 用于比较状态变化以触发滚动

  // --- 用于稳定背景图片的成员变量 ---
  ImageProvider? _stableBackgroundImageProvider;
  String? _currentBackgroundImageBase64;
  // --- 结束 用于稳定背景图片的成员变量 ---

  // _topMessageText, _topMessageColor, _topMessageTimer REMOVED - Handled by ChatStateNotifier

  @override
  void initState() {
    super.initState();
    // 可选：如果希望进入页面时输入框自动获取焦点
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   _inputFocusNode.requestFocus();
    // });

  // 新增：页面加载完成后滚动到底部
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _scrollToBottom(animate: false); // 初始加载时不使用动画, 即使是 reverse list, 确保在 0.0
  });
  }

  @override
  void dispose() {
    // _timer 已被移除，无需在此处 cancel
    _messageController.dispose(); // 清理输入控制器
    _scrollController.dispose(); // 清理滚动控制器
    _inputFocusNode.dispose(); // 清理输入框焦点节点
    _keyboardListenerFocusNode.dispose(); // 清理 Listener 焦点节点
    // _topMessageTimer?.cancel(); // REMOVED - Handled by ChatStateNotifier
    super.dispose();
  }

  // --- _showTopMessage method REMOVED - Handled by ChatStateNotifier ---

  // --- 发送消息逻辑 ---
  void _sendMessage() {
    final text = _messageController.text.trim(); // 获取输入文本并去除首尾空格
    if (text.isNotEmpty) {
      // 确保输入不为空
      // 发送前检查 API Key
      if (ref.read(apiKeyNotifierProvider).keys.isEmpty) {
        ref.read(chatStateNotifierProvider(widget.chatId).notifier).showTopMessage('请先在全局设置中添加 API Key', backgroundColor: Colors.orange);
        return; // 阻止发送
      }

      // 调用 ChatStateNotifier 中的 sendMessage 方法处理发送逻辑
      ref
          .read(chatStateNotifierProvider(widget.chatId).notifier)
          .sendMessage(text);
      _messageController.clear(); // 清空输入框
      // 同步操作，无需检查 mounted
      FocusScope.of(context).unfocus(); // 收起键盘
    }
  }

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

        // 1. 编辑选项 (用户和模型消息都可用)
        options.add(_buildBottomSheetActionItem(
          icon: Icons.edit_outlined,
          label: '编辑消息',
          onTap: () {
            Navigator.pop(modalContext); // 关闭底部菜单
            _showEditMessageDialog(message); // 显示编辑对话框
          },
        ));

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
    final editController =
        TextEditingController(text: message.rawText); // 初始化编辑框内容
    // showDialog 的 context 是安全的
    showDialog(
      context: context, // 使用 _ChatScreenState 的 context
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(message.role == MessageRole.user ? '编辑你的消息' : '编辑模型回复'),
          content: TextField(
            controller: editController,
            autofocus: true, // 自动获取焦点
            maxLines: null, // 允许多行编辑
            decoration: const InputDecoration(
              hintText: '输入修改后的内容...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                final newText = editController.text.trim();
                // 检查内容是否有效且已更改
                if (newText.isNotEmpty && newText != message.rawText) {
                  try {
                    final messageRepo = ref.read(messageRepositoryProvider);
                    // 更新消息对象的文本
                    message.rawText = newText;
                    // 先关闭对话框，避免在异步操作后使用可能无效的 dialogContext
                    Navigator.pop(dialogContext);

                    await messageRepo.saveMessage(message); // 保存更改到数据库

                    // 检查 mounted 状态 (针对 _ChatScreenState)，以安全地使用 context
                    if (!mounted) return; // 如果 Widget 已卸载，则不执行后续操作
                    ref.read(chatStateNotifierProvider(widget.chatId).notifier).showTopMessage('消息已更新', backgroundColor: Colors.green, duration: const Duration(seconds: 2));
                  } catch (e) {
                    debugPrint("保存编辑消息时出错: $e");
                    // 检查 mounted 状态 (针对 _ChatScreenState)，以安全地使用 context
                    if (!mounted) return;
                    // 注意：对话框已在 try 块开始时关闭，catch 中只显示错误信息
                    ref.read(chatStateNotifierProvider(widget.chatId).notifier).showTopMessage('保存编辑失败: $e', backgroundColor: Colors.red);
                  }
                } else if (newText.isEmpty) {
                  // 如果内容为空，提示用户
                  ref.read(chatStateNotifierProvider(widget.chatId).notifier).showTopMessage('消息内容不能为空', backgroundColor: Colors.orange);
                } else {
                  // 如果内容未更改，直接关闭对话框
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

  // --- Helper methods for _forkChatFromMessage ---
_ForkPrerequisites? _prepareForkPrerequisites(Message message, List<Message> allMessages) {
  final originalChat = ref.read(currentChatProvider(widget.chatId)).value;
  if (originalChat == null) {
    if (mounted) {
      ref.read(chatStateNotifierProvider(widget.chatId).notifier).showTopMessage('无法分叉：原始聊天数据丢失', backgroundColor: Colors.red);
    }
    return null;
  }

  final forkIndex = allMessages.indexWhere((m) => m.id == message.id);
  if (forkIndex == -1) {
    if (mounted) {
      ref.read(chatStateNotifierProvider(widget.chatId).notifier).showTopMessage('无法分叉：未找到消息', backgroundColor: Colors.red);
    }
    return null;
  }
  final messagesToKeep = allMessages.sublist(0, forkIndex + 1);
  return _ForkPrerequisites(originalChat: originalChat, messagesToKeep: messagesToKeep);
}

Future<int?> _createNewChatEntityForFork(Chat originalChat) async {
  try {
    final chatRepo = ref.read(chatRepositoryProvider);
    String newTitle;
    final baseTitle = originalChat.title ?? "无标题";
    final RegExp titleRegex = RegExp(r'^(.*)-(\d+)$');
    final Match? match = titleRegex.firstMatch(baseTitle);

    if (match != null) {
      final namePart = match.group(1);
      final numberPart = int.tryParse(match.group(2) ?? '');
      if (namePart != null && numberPart != null) {
        newTitle = '$namePart-${numberPart + 1}';
      } else {
        newTitle = '$baseTitle-1';
      }
    } else {
      newTitle = '$baseTitle-1';
    }

    final newChat = Chat()
      ..title = newTitle
      ..parentFolderId = originalChat.parentFolderId
      ..systemPrompt = originalChat.systemPrompt
      ..coverImageBase64 = originalChat.coverImageBase64
      ..backgroundImagePath = originalChat.backgroundImagePath
      ..generationConfig = originalChat.generationConfig
      ..contextConfig = originalChat.contextConfig
      ..xmlRules = List.from(originalChat.xmlRules)
      ..apiType = originalChat.apiType
      ..selectedOpenAIConfigId = originalChat.selectedOpenAIConfigId
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();
    
    return await chatRepo.saveChat(newChat);
  } catch (e) {
    debugPrint("创建新聊天实体以进行分叉时出错: $e");
    if (mounted) {
      ref.read(chatStateNotifierProvider(widget.chatId).notifier).showTopMessage('创建新聊天实体失败: $e', backgroundColor: Colors.red);
    }
    return null;
  }
}

Future<bool> _copyMessagesToForkedChat(List<Message> messagesToKeep, int newChatId) async {
  try {
    final messageRepo = ref.read(messageRepositoryProvider);
    final List<Message> newMessages = messagesToKeep.map((originalMsg) {
      return Message.create(
        chatId: newChatId,
        rawText: originalMsg.rawText,
        role: originalMsg.role,
      )..timestamp = originalMsg.timestamp;
    }).toList();
    await messageRepo.saveMessages(newMessages);
    return true;
  } catch (e) {
    debugPrint("复制消息到分叉聊天时出错: $e");
    if (mounted) {
      ref.read(chatStateNotifierProvider(widget.chatId).notifier).showTopMessage('复制消息失败: $e', backgroundColor: Colors.red);
    }
    return false;
  }
}
  // --- End Helper methods for _forkChatFromMessage ---

  // 从指定消息处创建新的分叉对话
  Future<void> _forkChatFromMessage(
      Message message, List<Message> allMessages) async {
    final prerequisites = _prepareForkPrerequisites(message, allMessages);
    if (prerequisites == null) {
      return;
    }

    final originalChat = prerequisites.originalChat;
    final messagesToKeep = prerequisites.messagesToKeep;

    // 可选：显示加载指示器 (可以移到 Notifier 如果需要更全局的加载状态)
    // ref.read(chatStateNotifierProvider(widget.chatId).notifier).state = ref.read(chatStateNotifierProvider(widget.chatId)).copyWith(isLoading: true);
    
    final int? newChatId = await _createNewChatEntityForFork(originalChat);
    if (newChatId == null) {
      // Error message shown by helper
      // if (mounted) ref.read(chatStateNotifierProvider(widget.chatId).notifier).state = ref.read(chatStateNotifierProvider(widget.chatId)).copyWith(isLoading: false);
      return;
    }

    final bool messagesCopied = await _copyMessagesToForkedChat(messagesToKeep, newChatId);
    if (!messagesCopied) {
      // Error message shown by helper
      // Consider deleting the newly created chat if message copy fails
      // final chatRepo = ref.read(chatRepositoryProvider);
      // await chatRepo.deleteChat(newChatId); // Example cleanup
      // if (mounted) ref.read(chatStateNotifierProvider(widget.chatId).notifier).state = ref.read(chatStateNotifierProvider(widget.chatId)).copyWith(isLoading: false);
      return;
    }

    if (!mounted) return;
    context.go('/chat/$newChatId');
    
    // Ensure mounted before showing final message, as go() is async.
    // A short delay might be needed if go() is very fast and the new screen's notifier isn't ready.
    // However, usually, the message is for the *current* screen context before navigation fully completes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) { // Re-check mounted after go and post frame callback
        ref.read(chatStateNotifierProvider(newChatId).notifier) // Show on the new chat screen's notifier
            .showTopMessage('已创建分叉对话', backgroundColor: Colors.green, duration: const Duration(seconds: 2));
      }
    });

    // if (mounted) ref.read(chatStateNotifierProvider(widget.chatId).notifier).state = ref.read(chatStateNotifierProvider(widget.chatId)).copyWith(isLoading: false);
  }

  // --- Helper methods for _regenerateResponse ---
  bool _canRegenerate(Message userMessage, List<Message> allMessages, ChatScreenState currentState, Chat? chatData, AsyncValue<Chat?> chatAsync) {
// Removed old _forkChatFromMessage body as it's now refactored.
    final messageIndex = allMessages.indexWhere((m) => m.id == userMessage.id);
    final isLastUserMsg = userMessage.role == MessageRole.user &&
        messageIndex >= 0 &&
        (messageIndex == allMessages.length - 1 ||
            (messageIndex == allMessages.length - 2 &&
                allMessages.last.role == MessageRole.model));

    if (!mounted) return false;

    if (!isLastUserMsg) {
      ref.read(chatStateNotifierProvider(widget.chatId).notifier).showTopMessage('只能为最后的用户消息重新生成回复', backgroundColor: Colors.orange);
      return false;
    }

    if (currentState.isLoading) {
      debugPrint("重新生成取消：已在加载中。");
      return false;
    }
    if (ref.read(apiKeyNotifierProvider).keys.isEmpty) {
      ref.read(chatStateNotifierProvider(widget.chatId).notifier).showTopMessage('请先在全局设置中添加 API Key', backgroundColor: Colors.orange);
      return false;
    }
    if (chatAsync.isLoading || chatAsync.hasError || chatData == null) {
      ref.read(chatStateNotifierProvider(widget.chatId).notifier).showTopMessage('无法重新生成：聊天数据未加载或出错', backgroundColor: Colors.red);
      return false;
    }
    return true;
  }

  Future<bool> _deletePreviousModelResponsesForRegen(Message userMessage, List<Message> allMessages) async {
    final messageIndex = allMessages.indexWhere((m) => m.id == userMessage.id);
    try {
      final messageRepo = ref.read(messageRepositoryProvider);
      List<int> messagesToDelete = [];
      if (messageIndex != -1 && messageIndex < allMessages.length - 1) {
        for (int i = messageIndex + 1; i < allMessages.length; i++) {
          if (allMessages[i].role == MessageRole.model) {
            messagesToDelete.add(allMessages[i].id);
          }
        }
      }

      if (messagesToDelete.isNotEmpty) {
        debugPrint("为重新生成删除 ${messagesToDelete.length} 条模型消息: $messagesToDelete");
        for (final msgId in messagesToDelete) {
          await messageRepo.deleteMessage(msgId);
        }
        await Future.delayed(const Duration(milliseconds: 150));
        if (!mounted) return false; // Check mounted after delay
      } else {
        debugPrint("未找到需要为重新生成删除的模型消息。");
      }
      return true;
    } catch (e, stacktrace) {
      debugPrint("删除旧消息以进行重新生成时出错: $e\n$stacktrace");
      if (mounted) {
        ref.read(chatStateNotifierProvider(widget.chatId).notifier).showTopMessage('删除旧回复失败: $e', backgroundColor: Colors.red);
      }
      return false;
    }
  }
  // --- End Helper methods for _regenerateResponse ---

  // 为最后一条用户消息重新生成模型回复
  Future<void> _regenerateResponse(
      Message userMessage, List<Message> allMessages) async {
    final notifier = ref.read(chatStateNotifierProvider(widget.chatId).notifier);
    final currentState = ref.read(chatStateNotifierProvider(widget.chatId));
    final chatAsync = ref.watch(currentChatProvider(widget.chatId)); // Use watch for latest data
    final chatData = chatAsync.value;

    if (!_canRegenerate(userMessage, allMessages, currentState, chatData, chatAsync)) {
      return;
    }
    
    debugPrint("开始为用户消息 ID: ${userMessage.id} 重新生成, 文本: ${userMessage.rawText}");

    await notifier.cancelGeneration(); // Notifier handles isLoading internally

    final bool deletionSuccess = await _deletePreviousModelResponsesForRegen(userMessage, allMessages);
    if (!mounted || !deletionSuccess) {
      return; // Error message already shown by helper or mounted check failed
    }
    
    debugPrint("从 _regenerateResponse 调用 notifier.sendMessage，输入: ${userMessage.rawText}");
    await notifier.sendMessage(userMessage.rawText, isRegeneration: true);
  }


  // 删除指定的消息
  Future<void> _deleteMessage(
      Message messageToDelete, List<Message> allMessages) async {
    try {
      final messageRepo = ref.read(messageRepositoryProvider);
      final deleted = await messageRepo.deleteMessage(messageToDelete.id);
      // 检查 mounted 状态
      if (!mounted) return;
      if (deleted) {
        ref.read(chatStateNotifierProvider(widget.chatId).notifier).showTopMessage('消息已删除', backgroundColor: Colors.green, duration: const Duration(seconds: 2));
        // 可选：如果删除影响上下文，可能需要进一步处理
      } else {
        // 检查 mounted 状态
        if (!mounted) return;
        ref.read(chatStateNotifierProvider(widget.chatId).notifier).showTopMessage('删除消息失败', backgroundColor: Colors.orange);
      }
    } catch (e) {
      debugPrint("删除消息时出错: $e");
      // 检查 mounted 状态
      if (!mounted) return;
      ref.read(chatStateNotifierProvider(widget.chatId).notifier).showTopMessage('删除消息出错: $e', backgroundColor: Colors.red);
    }
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
    final messagesAsync =
        ref.watch(chatMessagesProvider(widget.chatId)); // 当前聊天消息流
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
                      icon: const Icon(Icons.arrow_back), // const
                      onPressed: () => context.go('/'))),
              body: const Center(child: Text('聊天未找到或已被删除'))); // const
        }

        // --- 处理并稳定背景图片 Provider ---
        if (chat.coverImageBase64 != _currentBackgroundImageBase64) {
          _currentBackgroundImageBase64 = chat.coverImageBase64;
          if (_currentBackgroundImageBase64 != null && _currentBackgroundImageBase64!.isNotEmpty) {
            try {
              final Uint8List imageBytes = base64Decode(_currentBackgroundImageBase64!);
              _stableBackgroundImageProvider = MemoryImage(imageBytes);
            } catch (e) {
              debugPrint("ChatScreen: 解码背景图片 (来自coverImageBase64) 失败: $e");
              _stableBackgroundImageProvider = null; // 解码失败则清空
            }
          } else {
            _stableBackgroundImageProvider = null; // 没有 base64 字符串也清空
          }
        }
        // --- 结束 处理并稳定背景图片 Provider ---

        // --- 使用 Stack 实现背景图层和内容图层 ---
        return Stack(
          children: [
            // --- 背景层 ---
            Positioned.fill(
              child: Container(
                decoration: _stableBackgroundImageProvider != null // 使用 state 中的 provider
                    ? BoxDecoration(
                        // 如果有背景图
                        image: DecorationImage(
                          image: _stableBackgroundImageProvider!, // 使用 state 中的 provider
                          fit: BoxFit.cover, // 覆盖整个区域
                          // 移除了固定的暗色滤镜
                        ),
                      )
                    : BoxDecoration( // 如果没有背景图片，则使用主题的背景色
                        color: Theme.of(context).scaffoldBackgroundColor,
                      ),
              ),
            ),
            // --- 内容层 (Scaffold) ---
            Scaffold(
              // 根据是否有背景图片和当前主题来决定 Scaffold 的背景颜色
              backgroundColor: _stableBackgroundImageProvider != null // 使用 state 中的 provider
                  ? Colors.transparent // 有背景图，则 Scaffold 透明以显示 Stack 背景
                  : Theme.of(context).scaffoldBackgroundColor, // 无背景图，则使用主题的 scaffoldBackgroundColor
              appBar: AppBar(
                // AppBar 背景也应适应主题，让主题控制
                // backgroundColor: Theme.of(context)
                //     .appBarTheme
                //     .backgroundColor
                //     ?.withAlpha(204), 
                elevation: Theme.of(context).appBarTheme.elevation,
                leading: IconButton(
                  // 返回按钮
                  icon: const Icon(Icons.arrow_back), // const
                  tooltip: '返回列表',
                  onPressed: () => context.go('/'), // 使用 go 返回，替换当前路由
                ),
                title: Text(chat.title ?? '聊天',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                actions: [
                  // AppBar 右侧按钮 - 整合到 PopupMenuButton
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert), // const: 使用垂直三点图标
                    tooltip: '更多选项',
                    onSelected: (String result) async {
                      // 使用 async 因为导出是异步的
                      switch (result) {
                        case 'settings':
                          context.push('/chat/${widget.chatId}/settings');
                          break;
                        case 'gallery':
                          context.push('/chat/${widget.chatId}/gallery');
                          break;
                        case 'toggleOutputMode':
                          ref
                              .read(chatStateNotifierProvider(widget.chatId)
                                  .notifier)
                              .toggleOutputMode();
                          // Feedback is now handled by the notifier itself via showTopMessage
                          break;
                        case 'debug':
                          context.push('/chat/${widget.chatId}/debug');
                          break;
                        case 'toggleBubbleTransparency':
                          ref
                              .read(chatStateNotifierProvider(widget.chatId)
                                  .notifier)
                              .toggleBubbleTransparency();
                          break;
                        case 'toggleBubbleWidth':
                          ref
                              .read(chatStateNotifierProvider(widget.chatId)
                                  .notifier)
                              .toggleBubbleWidthMode();
                          break;
                        case 'toggleMessageListHeight':
                          ref
                              .read(chatStateNotifierProvider(widget.chatId)
                                  .notifier)
                              .toggleMessageListHeightMode();
                          break;
                        case 'exportChat':
                          // 导出逻辑
                          final notifier = ref.read(chatStateNotifierProvider(widget.chatId).notifier);
                          notifier.showTopMessage('正在准备导出文件...', backgroundColor: Colors.blueGrey, duration: const Duration(days: 1)); // Use notifier
                          String? finalExportPath;
                          try {
                            finalExportPath = await ref
                                .read(chatExportImportServiceProvider)
                                .exportChat(widget.chatId);

                            if (!mounted) return; // Check mounted after await
                            if (finalExportPath != null) {
                              notifier.showTopMessage('聊天已成功导出到: $finalExportPath', backgroundColor: Colors.green, duration: const Duration(seconds: 4));
                            } else {
                              if (!kIsWeb) {
                                notifier.showTopMessage('导出操作已取消或未能成功完成。', backgroundColor: Colors.orange, duration: const Duration(seconds: 3));
                              }
                              // For web, exportChat returns null on success. Message will be cleared by finally.
                            }
                          } catch (e) {
                            debugPrint("导出聊天时发生错误: $e");
                            if (!mounted) return; // Check mounted after await
                            notifier.showTopMessage('导出失败: $e', backgroundColor: Colors.red);
                          } finally {
                            if (!mounted) return; // Check mounted
                            // Clear long "preparing" message if it's still showing
                            // The notifier's showTopMessage has its own timer, but for very long durations,
                            // we might want to clear it explicitly if another message didn't replace it.
                            // This specific check might be tricky if other messages appeared.
                            // A robust way is if showTopMessage in notifier cancels previous timer. (It does)
                            // So, if a new message (success/fail) was shown, the "preparing" is gone.
                            // If export failed very fast before any other message, this explicit clear might be needed.
                            // However, the notifier's own timer for "preparing" would eventually clear it.
                            // For simplicity, we rely on the notifier's timer or subsequent messages.
                            // If the "正在准备导出文件..." is still the current topMessageText in chatState, then clear.
                            final currentTopMessage = ref.read(chatStateNotifierProvider(widget.chatId)).topMessageText;
                            if (currentTopMessage == '正在准备导出文件...') {
                                notifier.clearTopMessage();
                            }
                          }
                          break;
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      _buildPopupMenuItem(
                        value: 'settings',
                        icon: Icons.tune,
                        label: '聊天设置',
                      ),
                      _buildPopupMenuItem(
                        value: 'gallery',
                        icon: Icons.photo_library_outlined,
                        label: '封面与背景',
                      ),
                      const PopupMenuDivider(),
                      _buildPopupMenuItem(
                        value: 'toggleOutputMode',
                        icon: chatState.isStreamMode ? Icons.stream : Icons.chat_bubble,
                        label: chatState.isStreamMode ? '切换为一次性输出' : '切换为流式输出',
                      ),
                      _buildPopupMenuItem(
                        value: 'toggleBubbleTransparency',
                        icon: chatState.isBubbleTransparent ? Icons.opacity : Icons.opacity_outlined,
                        label: chatState.isBubbleTransparent ? '切换为不透明气泡' : '切换为半透明气泡',
                      ),
                      _buildPopupMenuItem(
                        value: 'toggleBubbleWidth',
                        icon: chatState.isBubbleHalfWidth ? Icons.width_normal : Icons.width_wide,
                        label: chatState.isBubbleHalfWidth ? '切换为全宽气泡' : '切换为半宽气泡',
                      ),
                      _buildPopupMenuItem(
                        value: 'toggleMessageListHeight',
                        icon: chatState.isMessageListHalfHeight ? Icons.height : Icons.unfold_more,
                        label: chatState.isMessageListHalfHeight ? '切换为全高列表' : '切换为半高列表',
                      ),
                      const PopupMenuDivider(),
                      _buildPopupMenuItem(
                        value: 'exportChat',
                        icon: Icons.upload_file,
                        label: '导出聊天到文件',
                      ),
                      _buildPopupMenuItem(
                        value: 'debug',
                        icon: Icons.bug_report_outlined,
                        label: '调试页面',
                      ),
                    ],
                  ),
                ],
              ),
              body: SafeArea(
                // 避免内容被系统 UI 遮挡
                child: Column(
                  children: [
                    // --- 顶部消息横幅 ---
                    TopMessageBanner(
                      message: chatState.topMessageText, // Read from chatState
                      backgroundColor: chatState.topMessageColor, // Read from chatState
                      onDismiss: () {
                        if (!mounted) return;
                        ref.read(chatStateNotifierProvider(widget.chatId).notifier).clearTopMessage();
                      },
                    ),
                    // --- 如果是半高模式，先添加一个 Spacer 占据上半部分空间 ---
                    if (chatState.isMessageListHalfHeight)
                      const Spacer(), // Spacer 会填充上半部分空间
                    // --- 消息列表区域 ---
                    // 使用 Flexible 以便在半高模式下正常工作
                    Flexible(
                        flex: 1, // 保持 flex 为 1，占据剩余空间（全高或下半部分）
                        child: messagesAsync.when(
                          // 处理消息加载状态
                          data: (messages) {
                            // 在帧结束后检查是否需要滚动
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (messages.length >
                                      (_previousMessagesCount ?? -1) ||
                                  (chatState.isStreaming !=
                                      (_previousChatState?.isStreaming ??
                                          false))) {
                                _scrollToBottom();
                              }
                              _previousMessagesCount =
                                  messages.length; // 更新消息计数
                            });
                            _previousChatState = chatState; // 更新上一个状态

                            // 使用 ListView.builder 构建消息列表
                            return ListView.builder(
                              reverse: true, // <--- 修改：列表反向排列，从底部开始
                              controller: _scrollController, // 绑定滚动控制器
                              padding: const EdgeInsets.all(8.0), // const
                              // 如果正在流式传输，列表项数量 +1 用于显示临时气泡
                              itemCount: messages.length +
                                  (chatState.isStreaming ? 1 : 0),
                              itemBuilder: (context, index) {
                                // 新逻辑：流式消息始终在底部 (index 0 for reverse: true)
                                if (chatState.isStreaming) {
                                  if (index == 0) { // 流式消息气泡在最底部
                                    final streamingMessage = Message.create(
                                      chatId: widget.chatId,
                                      rawText: chatState.streamingMessageContent ?? "",
                                      role: MessageRole.model,
                                    );
                                    if (chatState.streamingTimestamp != null) {
                                      streamingMessage.timestamp = chatState.streamingTimestamp!;
                                    }
                                    return MessageBubble(
                                      message: streamingMessage,
                                      isStreaming: true,
                                    );
                                  } else { // 已有消息，显示在流式气泡之上
                                    // messages 列表是 [最旧, ..., 最新]
                                    // 由于 reverse: true 且流式气泡占用了 index 0,
                                    // index 1 应该对应 messages.length - 1 (最新消息)
                                    // index 2 应该对应 messages.length - 2
                                    // ...
                                    // index messages.length 应该对应 messages[0] (最旧消息)
                                    final messageRealIndex = messages.length - index;
                                    if (messageRealIndex < 0 || messageRealIndex >= messages.length) {
                                      return const SizedBox.shrink(); // 边界检查
                                    }
                                    final message = messages[messageRealIndex];
                                    return MessageBubble(
                                      message: message,
                                      isTransparent: chatState.isBubbleTransparent,
                                      isHalfWidth: chatState.isBubbleHalfWidth,
                                      onTap: () => _handleMessageTap(message, messages),
                                    );
                                  }
                                } else { // 非流式状态，保持原有逻辑 (但索引计算相同)
                                  // messages 列表是 [最旧, ..., 最新]
                                  // index 0 应该对应 messages.length - 1 (最新消息)
                                  // index 1 应该对应 messages.length - 2
                                  final messageRealIndex = messages.length - 1 - index;
                                  if (messageRealIndex < 0 || messageRealIndex >= messages.length) {
                                    return const SizedBox.shrink(); // 边界检查
                                  }
                                  final message = messages[messageRealIndex];
                                  return MessageBubble(
                                    message: message,
                                    isTransparent: chatState.isBubbleTransparent,
                                    isHalfWidth: chatState.isBubbleHalfWidth,
                                    onTap: () => _handleMessageTap(message, messages),
                                  );
                                }
                              },
                            );
                          },
                          loading: () =>
                              const Center(child: CircularProgressIndicator()), // const
                          error: (err, stack) =>
                              Center(child: Text("无法加载消息: $err")),
                        )),
                    // --- 加载指示器 (仅在非流式加载且无计时器时显示) ---
                    // 注意：计时器已被移至输入框内
                    if (chatState.isLoading &&
                        !chatState.isStreaming &&
                        chatState.generationStartTime == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 0), // const
                        child: LinearProgressIndicator(minHeight: 2), // const
                      ),
                    // --- 输入区域 ---
                    SafeArea(
                      // 再次使用 SafeArea 避免输入框被键盘遮挡
                      child: Container(
                        padding: const EdgeInsets.symmetric( // const
                            horizontal: 10.0, vertical: 6.0),
                        margin: const EdgeInsets.symmetric( // const
                            horizontal: 8.0, vertical: 8.0),
                        decoration: BoxDecoration(
                            color: Theme.of(context).cardColor.withAlpha(
                                (255 * 0.95).round()), // 使用 withAlpha
                            borderRadius:
                                BorderRadius.circular(30.0), // 增加圆角半径，使其更圆润
                            boxShadow: const [ // const
                              // 轻微阴影
                              BoxShadow(
                                color: Colors.black12, // const Color.fromRGBO(0,0,0,0.12)
                                blurRadius: 3,
                                offset: Offset(0, 1), // const
                              )
                            ]),
                        // 使用 RawKeyboardListener 包裹 Row 来监听键盘事件
                        child: KeyboardListener(
                          focusNode:
                              _keyboardListenerFocusNode, // 绑定独立的 FocusNode
                          onKeyEvent: (KeyEvent event) {
                            // 确保 TextField 有焦点时才处理
                            if (!_inputFocusNode.hasFocus) return;
                            // 只处理按键按下的事件
                            if (event is KeyDownEvent) {
                              // 检查是否按下了 Enter 键
                              if (event.logicalKey ==
                                  LogicalKeyboardKey.enter) {
                                // 检查是否同时按下了 Shift 键
                                if (HardwareKeyboard.instance.isShiftPressed) {
                                  // Shift + Enter: 插入换行符
                                  // 获取当前光标位置
                                  final currentSelection =
                                      _messageController.selection;
                                  // 在光标位置插入换行符
                                  final newText =
                                      _messageController.text.replaceRange(
                                    currentSelection.start,
                                    currentSelection.end,
                                    '\n',
                                  );
                                  // 更新文本和光标位置
                                  _messageController.value = TextEditingValue(
                                    text: newText,
                                    selection: TextSelection.collapsed(
                                        offset: currentSelection.start + 1),
                                  );
                                } else {
                                  // Enter: 发送消息 (如果输入框不为空且不在加载中)
                                  if (_messageController.text
                                          .trim()
                                          .isNotEmpty &&
                                      !chatState.isLoading) {
                                    _sendMessage();
                                  }
                                  // 阻止事件传播，防止 TextField 执行默认的换行操作
                                  // 注意：这里不需要显式阻止，因为 TextField 的 onSubmitted 被移除了
                                }
                              }
                            }
                          },
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.end, // 底部对齐，适应多行输入
                            children: [
                              Expanded(
                                // 始终显示 TextField，将计时器放入 prefixIcon
                                child: TextField(
                                  controller: _messageController,
                                  focusNode: _inputFocusNode, // 绑定 FocusNode 到 TextField
                                  decoration: InputDecoration(
                                    hintText: '输入消息 (Shift+Enter 换行)...',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(25.0), // const
                                      borderSide: BorderSide.none, // const
                                    ),
                                    filled: true,
                                    fillColor: Colors.transparent,
                                    contentPadding: const EdgeInsets.symmetric( // const
                                        horizontal: 16.0, vertical: 12.0),
                                    isDense: false,
                                    // --- 在 prefixIcon 中显示计时器 ---
                                    prefixIcon: chatState.generationStartTime != null
                                        ? Padding(
                                            padding: const EdgeInsets.only( // const
                                                left: 12.0,
                                                right: 8.0), // 调整内边距
                                            child: Row(
                                              mainAxisSize: MainAxisSize
                                                  .min, // 关键：限制 prefixIcon 大小
                                              children: [
                                                const SizedBox( // const
                                                    width: 12,
                                                    height: 12,
                                                    child:
                                                        CircularProgressIndicator(
                                                            strokeWidth: 2)),
                                                const SizedBox(width: 8), // const
                                                Text(
                                                  // 使用较短的文本
                                                  '思考中... (${chatState.elapsedSeconds ?? 0}s)',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                          color: Colors
                                                              .grey.shade600),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          )
                                        : null, // 不生成时不显示 prefixIcon
                                    // --- prefixIcon 结束 ---
                                  ),
                                  keyboardType: TextInputType.multiline,
                                  textInputAction:
                                      TextInputAction.newline, // 修改为 newline
                                  // onSubmitted: (_) => _sendMessage(), // 移除 onSubmitted，由 RawKeyboardListener 处理
                                  enabled: true, // <-- 始终允许输入
                                  minLines: 1,
                                  maxLines: null, // 允许多行
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface),
                                ),
                              ),
                              const SizedBox(width: 4.0), // const
                              // --- 停止按钮 (仅在计时器激活时可见) ---
                              if (chatState.generationStartTime != null)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4.0), // const
                                  child: IconButton(
                                    icon: const Icon( // const
                                        Icons.cancel), // 修改图标为 cancel
                                    tooltip: '停止生成',
                                    // --- 修改 onPressed 以显示确认对话框 ---
                                    onPressed: () async {
                                      // 改为 async
                                      // 检查 mounted 状态，因为 showDialog 是异步的
                                      if (!mounted) return;
                                      final confirm = await showDialog<bool>(
                                            context:
                                                context, // 使用 _ChatScreenState 的 context
                                            builder: (dialogContext) =>
                                                AlertDialog(
                                              title: const Text('确认停止生成'), // const
                                              content: const Text( // const
                                                  '确定要停止当前的 AI 响应生成吗？已生成的部分将保留。'), // 提示用户保留已生成部分
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.of(
                                                          dialogContext)
                                                      .pop(false), // 返回 false
                                                  child: const Text('取消'), // const
                                                ),
                                                TextButton(
                                                  onPressed: () => Navigator.of(
                                                          dialogContext)
                                                      .pop(true), // 返回 true
                                                  child: Text('确认停止',
                                                      style: TextStyle(
                                                          color: Colors
                                                              .red.shade700)),
                                                ),
                                              ],
                                            ),
                                          ) ??
                                          false; // 如果对话框关闭则默认为 false

                                      // 再次检查 mounted 状态，并在确认后执行操作
                                      if (mounted && confirm) {
                                        // 调用 notifier 中的取消方法
                                        // cancelGeneration 应该只停止接收新数据，不清除已有的 streamingMessageContent
                                        ref
                                            .read(chatStateNotifierProvider(
                                                    widget.chatId)
                                                .notifier)
                                            .cancelGeneration();
                                      }
                                    },
                                    // --- 确认对话框逻辑结束 ---
                                    style: IconButton.styleFrom(
                                      foregroundColor: Colors.redAccent, // 红色图标
                                      padding: const EdgeInsets.all(12), // const
                                    ),
                                  ),
                                ),
                              // --- 发送按钮 (仅在计时器未激活时可见) ---
                              if (chatState.generationStartTime == null)
                                IconButton(
                                  icon: const Icon(Icons.send), // const
                                  onPressed:
                                      _sendMessage, // 现在可以直接调用，因为外部条件已处理禁用状态
                                  style: IconButton.styleFrom(
                                    padding: const EdgeInsets.all(12), // const
                                  ).copyWith(
                                    // 使用 WidgetStateProperty 处理不同状态颜色
                                    backgroundColor:
                                        WidgetStateProperty.resolveWith<Color?>(
                                      (Set<WidgetState> states) {
                                        // 使用 WidgetState
                                        if (states
                                            .contains(WidgetState.disabled)) { // 添加花括号
                                          return Colors.grey.shade300;
                                        }
                                        return Theme.of(context)
                                            .colorScheme
                                            .primary;
                                      },
                                    ),
                                    foregroundColor:
                                        WidgetStateProperty.resolveWith<Color?>(
                                      (Set<WidgetState> states) {
                                        // 使用 WidgetState
                                        if (states
                                            .contains(WidgetState.disabled)) { // 添加花括号
                                          return Colors.grey.shade700;
                                        }
                                        return Theme.of(context)
                                            .colorScheme
                                            .onPrimary;
                                      },
                                    ),
                                  ),
                                  tooltip: '发送',
                                ),
                            ],
                          ),
                        ), // 结束 RawKeyboardListener
                      ),
                    ),
                  ],
                ),
              ),
            ), // 结束 Scaffold
          ], // 结束 Stack children
        );
      },
      // --- 聊天数据加载状态 ---
      loading: () => Scaffold( // const Scaffold
          appBar: AppBar(
              leading: IconButton(
                  icon: const Icon(Icons.arrow_back), // const
                  onPressed: () => context.go('/'))),
          body: const Center(child: CircularProgressIndicator())), // const
      error: (error, stack) => Scaffold( // const Scaffold
          appBar: AppBar(
              leading: IconButton(
                  icon: const Icon(Icons.arrow_back), // const
                  onPressed: () => context.go('/'))),
          body: Center(child: Text('无法加载聊天数据: $error'))),
    );
  }
}

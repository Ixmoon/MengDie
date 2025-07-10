import 'dart:async'; // For StreamSubscription, Timer

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart'; // Added for Color type

import 'package:drift/drift.dart' show Value;
import '../models/models.dart';
import '../repositories/chat_repository.dart';
import '../repositories/message_repository.dart';
import '../services/llm_service.dart'; // Import the generic LLM service and types
import '../process/context_xml_service.dart'; // Import the new service
import 'package:collection/collection.dart'; // Import for lastWhereOrNull
import '../process/xml_processor.dart'; // Added import
import '../providers/settings_providers.dart';


// 本文件包含与聊天数据和聊天界面状态相关的 Riverpod 提供者。

// --- 当前激活的聊天 ID Provider ---
// 这个 Provider 允许我们拥有一个单一的 ChatScreen 实例，
// 该实例根据此状态更新其内容，而不是为每个聊天推送新的路由。
final activeChatIdProvider = StateProvider<int?>((ref) => null);

// --- 当前文件夹 ID Provider ---
final currentFolderIdProvider = StateProvider<int?>((ref) => null);

// --- 聊天列表 Provider (Stream Family) ---
final chatListProvider = StreamProvider.family<List<Chat>, int?>((ref, parentFolderId) {
  try {
     final repo = ref.watch(chatRepositoryProvider);
      debugPrint("chatListProvider(folderId: $parentFolderId): 正在监听聊天/文件夹。");
      return repo.watchChatsInFolder(parentFolderId);
   } catch (e) {
      debugPrint("chatListProvider(folderId: $parentFolderId) 错误: $e");
     return Stream.error(e);
   }
});


// --- 当前聊天 Provider (Stream for specific chat) ---
final currentChatProvider = StreamProvider.family<Chat?, int>((ref, chatId) {
   try {
     final repo = ref.watch(chatRepositoryProvider);
     debugPrint("currentChatProvider($chatId): 正在监听聊天。");
     return repo.watchChat(chatId);
   } catch (e) {
     debugPrint("currentChatProvider($chatId) 错误: $e");
     return Stream.error(e);
   }
});

// --- 聊天消息 Provider (Stream for specific chat's messages) ---
final chatMessagesProvider = StreamProvider.family<List<Message>, int>((ref, chatId) {
   try {
      final repo = ref.watch(messageRepositoryProvider);
      debugPrint("chatMessagesProvider($chatId): 正在监听消息。");
      return repo.watchMessagesForChat(chatId);
   } catch (e) {
      debugPrint("chatMessagesProvider($chatId) 错误: $e");
      return Stream.error(e);
   }
});

// --- 最后一条模型消息 Provider (响应式) ---
final lastModelMessageProvider = Provider.family<Message?, int>((ref, chatId) {
  final messagesAsyncValue = ref.watch(chatMessagesProvider(chatId));
  return messagesAsyncValue.when(
    data: (messages) {
      final lastModelMsg = messages.lastWhereOrNull((msg) => msg.role == MessageRole.model);
      return lastModelMsg;
    },
    loading: () => null,
    error: (error, stack) {
      debugPrint("lastModelMessageProvider($chatId): 消息流错误: $error");
      return null;
    },
  );
});


// --- 聊天屏幕状态 ---
@immutable
class ChatScreenState {
  final bool isLoading;
  final String? errorMessage; // For critical errors, might still be useful
  final String? topMessageText; // For general informational messages
  final Color? topMessageColor; // Color for the top message banner
  final DateTime? generationStartTime;
  final bool isStreaming; // Still useful to know if a stream is active overall
  final bool isStreamMode;
  final int? elapsedSeconds;
  final bool isBubbleTransparent;
  final bool isBubbleHalfWidth;
  final bool isMessageListHalfHeight;
  final bool isAutoHeightEnabled; // New state for the feature toggle
  final int? totalTokens;
  final List<String>? helpMeReplySuggestions;
  final bool isProcessingInBackground; // New state for background tasks

  const ChatScreenState({
    this.isLoading = false,
    this.generationStartTime,
    this.errorMessage,
    this.topMessageText,
    this.topMessageColor,
    this.isStreaming = false,
    this.isStreamMode = true,
    this.elapsedSeconds,
    this.isBubbleTransparent = false,
    this.isBubbleHalfWidth = false,
    this.isMessageListHalfHeight = false,
    this.isAutoHeightEnabled = false, // Default to false
    this.totalTokens,
    this.helpMeReplySuggestions,
    this.isProcessingInBackground = false, // Default to false
  });

  ChatScreenState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false, // If true, sets errorMessage to null
    String? topMessageText,
    Color? topMessageColor,
    bool clearTopMessage = false, // If true, sets topMessageText and topMessageColor to null
    DateTime? generationStartTime,
    bool clearGenerationStartTime = false,
    bool? isStreaming,
    bool clearStreaming = false,
    bool? isStreamMode,
    int? elapsedSeconds,
    bool clearElapsedSeconds = false,
    bool? isBubbleTransparent,
    bool? isBubbleHalfWidth,
    bool? isMessageListHalfHeight,
    bool? isAutoHeightEnabled,
    int? totalTokens,
    bool clearTotalTokens = false,
    List<String>? helpMeReplySuggestions,
    bool clearHelpMeReplySuggestions = false,
    bool? isProcessingInBackground,
  }) {
    return ChatScreenState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      topMessageText: clearTopMessage ? null : (topMessageText ?? this.topMessageText),
      topMessageColor: clearTopMessage ? null : (topMessageColor ?? this.topMessageColor),
      generationStartTime: clearGenerationStartTime ? null : (generationStartTime ?? this.generationStartTime),
      isStreaming: clearStreaming ? false : (isStreaming ?? this.isStreaming),
      isStreamMode: isStreamMode ?? this.isStreamMode,
      elapsedSeconds: clearElapsedSeconds ? null : (elapsedSeconds ?? this.elapsedSeconds),
      isBubbleTransparent: isBubbleTransparent ?? this.isBubbleTransparent,
      isBubbleHalfWidth: isBubbleHalfWidth ?? this.isBubbleHalfWidth,
      isMessageListHalfHeight: isMessageListHalfHeight ?? this.isMessageListHalfHeight,
      isAutoHeightEnabled: isAutoHeightEnabled ?? this.isAutoHeightEnabled,
      totalTokens: clearTotalTokens ? null : (totalTokens ?? this.totalTokens),
      helpMeReplySuggestions: clearHelpMeReplySuggestions ? null : (helpMeReplySuggestions ?? this.helpMeReplySuggestions),
      isProcessingInBackground: isProcessingInBackground ?? this.isProcessingInBackground,
    );
  }
}

// --- 聊天屏幕状态 StateNotifierProvider ---
final chatStateNotifierProvider = StateNotifierProvider.family<ChatStateNotifier, ChatScreenState, int>(
  (ref, chatId) => ChatStateNotifier(ref, chatId),
);

// --- 聊天屏幕状态 StateNotifier ---
class ChatStateNotifier extends StateNotifier<ChatScreenState> {
  final Ref _ref;
  final int _chatId;
  StreamSubscription<LlmStreamChunk>? _llmStreamSubscription;
  Timer? _updateTimer;
  Timer? _topMessageTimer; // Timer for top messages
  bool _isCancelling = false; // Flag to prevent reentry into cancelGeneration
  bool _isFinalizing = false; // Flag to prevent reentry into _finalizeStreamedMessage
  bool _isBackgroundTaskCancelled = false; // Cancellation flag for background tasks

  ChatStateNotifier(this._ref, this._chatId) : super(const ChatScreenState());

  // --- Top Message Logic ---
  void showTopMessage(String text, {Color? backgroundColor, Duration duration = const Duration(seconds: 3)}) {
    if (!mounted) return;
    _topMessageTimer?.cancel();
    state = state.copyWith(
      topMessageText: text,
      topMessageColor: backgroundColor ?? Colors.blueGrey, // Default color if null
      clearTopMessage: false,
    );
    _topMessageTimer = Timer(duration, () {
      if (mounted) {
        clearTopMessage();
      }
    });
  }

  void clearTopMessage() {
    if (!mounted) return;
    _topMessageTimer?.cancel();
    _topMessageTimer = null;
    // Only clear if there's actually a message to prevent unnecessary rebuilds
    if (state.topMessageText != null) {
      state = state.copyWith(clearTopMessage: true);
    }
  }
  // --- End Top Message Logic ---

  void toggleOutputMode() {
    state = state.copyWith(isStreamMode: !state.isStreamMode);
    // Example of using the new showTopMessage for feedback
    showTopMessage('输出模式已切换为: ${state.isStreamMode ? "流式" : "一次性"}');
    debugPrint("Chat ($_chatId) 输出模式切换为: ${state.isStreamMode ? "流式" : "一次性"}");
  }

  void toggleBubbleTransparency() {
    state = state.copyWith(isBubbleTransparent: !state.isBubbleTransparent);
    showTopMessage('气泡已切换为: ${state.isBubbleTransparent ? "半透明" : "不透明"}');
    debugPrint("Chat ($_chatId) 气泡透明度切换为: ${state.isBubbleTransparent}");
  }

  void toggleBubbleWidthMode() {
    state = state.copyWith(isBubbleHalfWidth: !state.isBubbleHalfWidth);
    showTopMessage('气泡宽度已切换为: ${state.isBubbleHalfWidth ? "半宽" : "全宽"}');
    debugPrint("Chat ($_chatId) 气泡宽度模式切换为: ${state.isBubbleHalfWidth ? "半宽" : "全宽"}");
  }

  void toggleMessageListHeightMode() {
    final newAutoHeightState = !state.isAutoHeightEnabled;
    state = state.copyWith(
      isAutoHeightEnabled: newAutoHeightState,
      // When turning off, force full height. When turning on, force half height.
      isMessageListHalfHeight: newAutoHeightState,
    );
    showTopMessage('智能半高模式已: ${newAutoHeightState ? "开启" : "关闭"}');
    debugPrint("Chat ($_chatId) 智能半高模式切换为: $newAutoHeightState");
  }

  void setMessageListHeightMode(bool isHalfHeight) {
    if (state.isMessageListHalfHeight == isHalfHeight) return; // 避免不必要的状态更新
    state = state.copyWith(isMessageListHalfHeight: isHalfHeight);
    debugPrint("Chat ($_chatId) 消息列表高度模式设置为: ${isHalfHeight ? "半高" : "全高"}");
  }

  // --- Token Counting ---
  Future<void> calculateAndStoreTokenCount() async {
    if (!mounted) return;

    // Give a brief moment for the message list stream to update after a change
    await Future.delayed(const Duration(milliseconds: 100));

    final chat = _ref.read(currentChatProvider(_chatId)).value;
    final messages = _ref.read(chatMessagesProvider(_chatId)).value;

    if (chat == null || messages == null || messages.isEmpty) {
      if (mounted) state = state.copyWith(clearTotalTokens: true);
      return;
    }

    try {
      final llmService = _ref.read(llmServiceProvider);
      final contextXmlService = _ref.read(contextXmlServiceProvider);
      
      // Build context as if we're about to send a new message for an accurate count
      final apiRequestContext = await contextXmlService.buildApiRequestContext(
        chat: chat,
        currentUserMessage: messages.last, // Base context on the latest message
      );
      
      final count = await llmService.countTokens(
        llmContext: apiRequestContext.contextParts,
        chat: chat,
      );

      if (mounted) {
        state = state.copyWith(totalTokens: count > 0 ? count : null);
        debugPrint("ChatStateNotifier($_chatId): Token count updated to $count");
      }
    } catch (e) {
      debugPrint("ChatStateNotifier($_chatId): Error calculating token count: $e");
      if (mounted) {
        state = state.copyWith(clearTotalTokens: true);
      }
    }
  }
  // --- End Token Counting ---

  // --- 消息操作方法 ---

  Future<void> deleteMessage(int messageId) async {
    if (!mounted) return;
    try {
      final messageRepo = _ref.read(messageRepositoryProvider);
      final deleted = await messageRepo.deleteMessage(messageId);
      if (mounted) {
        if (deleted) {
          showTopMessage('消息已删除', backgroundColor: Colors.green, duration: const Duration(seconds: 2));
          calculateAndStoreTokenCount(); // Recalculate tokens
          // 清除上下文摘要，因为它现在可能已失效
          final chatRepo = _ref.read(chatRepositoryProvider);
          final chat = await chatRepo.getChat(_chatId);
          if (chat != null && chat.contextSummary != null) {
            await chatRepo.saveChat(chat.copyWith(contextSummary: const Value(null)));
            debugPrint("ChatStateNotifier($_chatId): 因消息删除已清除上下文摘要。");
          }
        } else {
          showTopMessage('删除消息失败，可能已被删除', backgroundColor: Colors.orange);
        }
      }
    } catch (e) {
      debugPrint("Notifier 删除消息时出错: $e");
      if (mounted) {
        showTopMessage('删除消息出错: $e', backgroundColor: Colors.red);
      }
    }
  }

  Future<void> editMessage(int messageId, {String? newText, List<MessagePart>? newParts, Message? updatedMessage}) async {
    if (!mounted) return;
    try {
      final messageRepo = _ref.read(messageRepositoryProvider);
      
      Message? messageToSave = updatedMessage;

      if (messageToSave == null) {
        final message = await messageRepo.getMessageById(messageId);
        if (message == null) {
          showTopMessage('无法编辑：未找到消息', backgroundColor: Colors.red);
          return;
        }
        if (newParts != null) {
          messageToSave = message.copyWith(parts: newParts);
        } else if (newText != null) {
          messageToSave = message.copyWith(rawText: newText);
        } else {
          return; // Nothing to update
        }
      }
      
      await messageRepo.saveMessage(messageToSave);

      if (mounted) {
        showTopMessage('消息已更新', backgroundColor: Colors.green, duration: const Duration(seconds: 2));
        calculateAndStoreTokenCount(); // Recalculate tokens
        // 清除上下文摘要，因为它现在可能已失效
        final chatRepo = _ref.read(chatRepositoryProvider);
        final chat = await chatRepo.getChat(_chatId);
        if (chat != null && chat.contextSummary != null) {
          await chatRepo.saveChat(chat.copyWith(contextSummary: const Value(null)));
          debugPrint("ChatStateNotifier($_chatId): 因消息编辑已清除上下文摘要。");
        }
      }
    } catch (e) {
      debugPrint("Notifier 更新消息时出错: $e");
      if (mounted) {
        showTopMessage('保存编辑失败: $e', backgroundColor: Colors.red);
      }
    }
  }

  Future<int?> forkChat(Message fromMessage) async {
    if (!mounted) return null;

    final chatRepo = _ref.read(chatRepositoryProvider);
    final messageRepo = _ref.read(messageRepositoryProvider);
    final allMessagesAsync = _ref.read(chatMessagesProvider(_chatId));
    final originalChat = _ref.read(currentChatProvider(_chatId)).value;

    if (originalChat == null || allMessagesAsync.value == null) {
      showTopMessage('无法分叉：原始数据丢失', backgroundColor: Colors.red);
      return null;
    }

    final allMessages = allMessagesAsync.value!;
    final forkIndex = allMessages.indexWhere((m) => m.id == fromMessage.id);
    if (forkIndex == -1) {
      showTopMessage('无法分叉：未找到消息', backgroundColor: Colors.red);
      return null;
    }

    final messagesToKeep = allMessages.sublist(0, forkIndex + 1);

    try {
      // 1. 创建新的 Chat 实体
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
        ..apiConfigId = originalChat.apiConfigId
        ..contextConfig = originalChat.contextConfig
        ..xmlRules = List.from(originalChat.xmlRules)
        ..enablePreprocessing = originalChat.enablePreprocessing
        ..preprocessingPrompt = originalChat.preprocessingPrompt
        ..preprocessingApiConfigId = originalChat.preprocessingApiConfigId
        ..contextSummary = null // Forked chat starts fresh
        ..enableSecondaryXml = originalChat.enableSecondaryXml
        ..secondaryXmlPrompt = originalChat.secondaryXmlPrompt
        ..secondaryXmlApiConfigId = originalChat.secondaryXmlApiConfigId
        ..continuePrompt = originalChat.continuePrompt
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();
      
      final newChatId = await chatRepo.saveChat(newChat);

      // 2. 复制消息
      final List<Message> newMessages = messagesToKeep.map((originalMsg) {
        return Message.create(
          chatId: newChatId,
          parts: originalMsg.parts, // Keep original parts
          role: originalMsg.role,
          timestamp: originalMsg.timestamp,
          // FIX: Ensure forked messages retain their complete XML history
          originalXmlContent: originalMsg.originalXmlContent,
          secondaryXmlContent: originalMsg.secondaryXmlContent,
        );
      }).toList();
      await messageRepo.saveMessages(newMessages);

      // 3. 返回新的 chat ID
      showTopMessage('已创建分叉对话', backgroundColor: Colors.green);
      return newChatId;

    } catch (e) {
      debugPrint("Notifier 分叉对话时出错: $e");
      if (mounted) {
        showTopMessage('分叉对话失败: $e', backgroundColor: Colors.red);
      }
      return null;
    }
  }

  Future<void> regenerateResponse(Message userMessage) async {
    if (!mounted) return;

    final allMessages = _ref.read(chatMessagesProvider(_chatId)).value ?? [];
    
    // 1. 检查是否可以重新生成
    final messageIndex = allMessages.indexWhere((m) => m.id == userMessage.id);
    final isLastUserMsg = userMessage.role == MessageRole.user &&
        messageIndex >= 0 &&
        (messageIndex == allMessages.length - 1 ||
            (messageIndex == allMessages.length - 2 &&
                allMessages.last.role == MessageRole.model));

    if (!isLastUserMsg) {
      showTopMessage('只能为最后的用户消息重新生成回复', backgroundColor: Colors.orange);
      return;
    }
    if (state.isLoading) {
      debugPrint("重新生成取消：已在加载中。");
      return;
    }

    await cancelGeneration(); // 确保之前的任何生成都已停止

    // 2. 删除之前的模型回复
    try {
      final messageRepo = _ref.read(messageRepositoryProvider);
      List<int> messagesToDelete = [];
      if (messageIndex != -1 && messageIndex < allMessages.length - 1) {
        for (int i = messageIndex + 1; i < allMessages.length; i++) {
          if (allMessages[i].role == MessageRole.model) {
            messagesToDelete.add(allMessages[i].id);
          }
        }
      }
      if (messagesToDelete.isNotEmpty) {
        for (final msgId in messagesToDelete) {
          await messageRepo.deleteMessage(msgId);
        }
        // 短暂延迟以确保数据库更新反映到流中
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } catch (e) {
        showTopMessage('删除旧回复失败: $e', backgroundColor: Colors.red);
        return;
    }

    if (!mounted) return;

    // 3. 调用 sendMessage 进行重新生成
    // For regeneration, we pass the original user message object
    await sendMessage(userMessage: userMessage, isRegeneration: true);
  }

  Future<void> continueGeneration() async {
    if (state.isLoading) {
      debugPrint("续写操作取消：已在加载中。");
      return;
    }

    final allMessages = _ref.read(chatMessagesProvider(_chatId)).value ?? [];
    if (allMessages.isEmpty || allMessages.last.role != MessageRole.model) {
      showTopMessage('只能在模型回复后进行续写', backgroundColor: Colors.orange);
      return;
    }

    await sendMessage(isContinuation: true);
  }

  Future<void> sendMessage({
    List<MessagePart>? userParts,
    Message? userMessage, // Used for regeneration
    bool isRegeneration = false,
    bool isContinuation = false,
  }) async {
    if (state.isLoading && !isRegeneration && !isContinuation) {
      debugPrint("sendMessage ($_chatId) 取消：已在加载中。");
      return;
    }
    
    final chat = _ref.read(currentChatProvider(_chatId)).value;
    if (chat == null) {
      showTopMessage('无法发送消息：聊天数据未加载。', backgroundColor: Colors.red);
      return;
    }

    // Determine the message to send for context, and the list of messages to save
    Message messageForContext;
    List<Message> messagesToSave = [];

    if (isRegeneration && userMessage != null) {
      messageForContext = userMessage;
      debugPrint("重新生成操作，使用现有消息作为上下文。");
    } else if (isContinuation) {
      final allMessages = _ref.read(chatMessagesProvider(_chatId)).value ?? [];
      if (allMessages.isEmpty) return;
      messageForContext = allMessages.last;
      debugPrint("续写操作，使用现有历史作为上下文。");
    } else if (userParts != null && userParts.isNotEmpty) {
      // Create a separate message for each part
      for (var part in userParts) {
        messagesToSave.add(Message.create(
          chatId: _chatId,
          role: MessageRole.user,
          parts: [part], // Each message now has only one part
        ));
      }
      if (messagesToSave.isEmpty) return; // Should not happen if userParts is not empty
      messageForContext = messagesToSave.last; // Use the last part for context building
    } else {
      return; // Nothing to send
    }

    // --- Start loading state ---
    state = state.copyWith(
        isLoading: true,
        clearError: true,
        clearTopMessage: true,
        clearStreaming: true,
        clearHelpMeReplySuggestions: true, // 清除建议缓存
        generationStartTime: DateTime.now(),
        elapsedSeconds: 0);
    _startUpdateTimer();
    
    // --- Save new user messages (if not regenerating or continuing) ---
    if (!isRegeneration && !isContinuation) {
      try {
        final messageRepo = _ref.read(messageRepositoryProvider);
        await messageRepo.saveMessages(messagesToSave); // Batch save
        final chatRepo = _ref.read(chatRepositoryProvider);
        chat.updatedAt = DateTime.now();
        await chatRepo.saveChat(chat);
        debugPrint("用户发送的 ${messagesToSave.length} 条原子消息已保存。");
      } catch (e) {
        debugPrint("保存用户消息时出错: $e");
        if (mounted) {
          showTopMessage('无法保存您的消息: $e', backgroundColor: Colors.red);
          state = state.copyWith(isLoading: false, clearGenerationStartTime: true, clearElapsedSeconds: true);
          _stopUpdateTimer();
        }
        return;
      }
    }

    // --- Build API context ---
    List<LlmContent> llmApiContext;
    String? carriedOverXmlForThisTurn;
    try {
      final contextXmlService = _ref.read(contextXmlServiceProvider);
      
      Chat chatForContext = chat;
      String? lastMessageOverride;

      if (isContinuation && (chat.continuePrompt?.isNotEmpty ?? false)) {
        lastMessageOverride = chat.continuePrompt;
        // For continuation, we keep the original system prompt.
        // The line clearing it has been removed.
        debugPrint("续写操作：将续写提示词作为最后的用户消息。");
      }

      final apiRequestContext = await contextXmlService.buildApiRequestContext(
        chat: chatForContext,
        currentUserMessage: messageForContext, // Pass the representative message for context
        lastMessageOverride: lastMessageOverride,
      );
      
      llmApiContext = apiRequestContext.contextParts;
      carriedOverXmlForThisTurn = apiRequestContext.carriedOverXml;

    } catch (e) {
        debugPrint("ChatStateNotifier:sendMessage($_chatId): 构建 API 上下文时出错: $e");
        if (mounted) {
          showTopMessage('构建请求上下文失败: $e', backgroundColor: Colors.red);
          state = state.copyWith(isLoading: false, clearGenerationStartTime: true, clearElapsedSeconds: true);
          _stopUpdateTimer();
        }
        return;
     }

     final llmService = _ref.read(llmServiceProvider);

     if (state.isStreamMode) {
       // The new stream handling logic now returns a Future
       await _handleStreamResponse(llmService, chat, llmApiContext);
     } else {
       await _handleSingleResponse(llmService, chat, llmApiContext, carriedOverXmlForThisTurn);
     }
   }

 // --- Post-Generation Processing ---
 Future<void> _runAsyncProcessingTasks(Message modelMessage) async {
   if (!mounted) return;
   final chat = _ref.read(currentChatProvider(_chatId)).value;
   if (chat == null) return;

   // 1. Reset cancellation flag and set background processing state
   _isBackgroundTaskCancelled = false;
   if (mounted) {
     state = state.copyWith(isProcessingInBackground: true);
   }

   List<Future> tasks = [];

   // 2. Gather all tasks
   tasks.add(_executeAutoTitleGeneration(chat, modelMessage));
   tasks.add(_executePostGenerationProcessing(chat, modelMessage));
   if (chat.enablePreprocessing && (chat.preprocessingPrompt?.isNotEmpty ?? false)) {
     tasks.add(_executePreprocessing(chat));
   }
   final globalSettings = _ref.read(globalSettingsProvider);
   if (globalSettings.enableHelpMeReply && globalSettings.helpMeReplyTriggerMode == 'auto') {
     tasks.add(generateHelpMeReply());
   }

   // 3. Run tasks and clear state in a finally block
   if (tasks.isNotEmpty) {
     try {
       await Future.wait(tasks);
       debugPrint("ChatStateNotifier($_chatId): Async processing tasks completed.");
       // Show completion message only on success and if not cancelled
       // The "Completed" message is now shown by the caller contexts
       // (_finalizeStreamedMessage or _handleSingleResponse) after this whole process finishes.
     } catch (e) {
       if (!_isBackgroundTaskCancelled) { // Only show error if not cancelled by user
         debugPrint("ChatStateNotifier($_chatId): Error during async processing tasks: $e");
         if (mounted) {
           showTopMessage("后台处理任务出错: $e", backgroundColor: Colors.red.withAlpha(204));
         }
       }
     } finally {
       if (mounted) {
         // Clear all processing states together, including the timer.
         state = state.copyWith(
           isProcessingInBackground: false,
           clearGenerationStartTime: true,
           clearElapsedSeconds: true,
         );
         _stopUpdateTimer();
         debugPrint("ChatStateNotifier($_chatId): Background processing state and timer cleared.");
       }
     }
   } else {
     // If there are no tasks, ensure the state is cleared immediately.
     if (mounted) {
       state = state.copyWith(isProcessingInBackground: false);
     }
   }
 }

 Future<void> _executePostGenerationProcessing(Chat chat, Message modelMessage) async {
   if (_isBackgroundTaskCancelled) return; // Check for cancellation
   debugPrint("ChatStateNotifier($_chatId): Starting post-generation processing for an existing message...");
   final messageRepo = _ref.read(messageRepositoryProvider);

   var messageToUpdate = await messageRepo.getMessageById(modelMessage.id);
   if (messageToUpdate == null) {
     debugPrint("ChatStateNotifier($_chatId): Post-processing failed: message to update not found.");
     return;
   }
   
   if (_isBackgroundTaskCancelled) return; // Check again before heavy lifting
   final finalMessage = await _getFinalProcessedMessage(chat, messageToUpdate);

   if (_isBackgroundTaskCancelled) return; // Check again before saving

   if (finalMessage.rawText != messageToUpdate.rawText ||
       finalMessage.originalXmlContent != messageToUpdate.originalXmlContent ||
       finalMessage.secondaryXmlContent != messageToUpdate.secondaryXmlContent) {
     await messageRepo.saveMessage(finalMessage);
     debugPrint("ChatStateNotifier($_chatId): Existing message has been updated with post-processing.");
   } else {
     debugPrint("ChatStateNotifier($_chatId): No changes for existing message after post-processing. Skipping save.");
   }
 }

 Future<void> _executePreprocessing(Chat chat) async {
   if (_isBackgroundTaskCancelled) return; // Check for cancellation
   debugPrint("ChatStateNotifier($_chatId): Executing pre-processing (summarization)...");
   final contextXmlService = _ref.read(contextXmlServiceProvider);
   final llmService = _ref.read(llmServiceProvider);
   final chatRepo = _ref.read(chatRepositoryProvider);

   final placeholderMessage = Message.create(chatId: _chatId, role: MessageRole.user, rawText: "[Preprocessing Placeholder]");
   final apiRequestContext = await contextXmlService.buildApiRequestContext(chat: chat, currentUserMessage: placeholderMessage);
   final droppedMessages = apiRequestContext.droppedMessages;

   if (droppedMessages.isEmpty) {
     debugPrint("ChatStateNotifier($_chatId): No messages dropped, skipping summarization.");
     return;
   }
   
   if (_isBackgroundTaskCancelled) return; // Check again before API call

   final summaryPrompt = chat.preprocessingPrompt!;
   final previousSummary = chat.contextSummary;
   
   // The summary prompt is used as both the system prompt and the final user message.
   final chatForSummaryCall = chat.copyWith(systemPrompt: summaryPrompt);

   // Construct the user content to be summarized
   final previousSummaryText = (previousSummary != null && previousSummary.isNotEmpty)
       ? "This is the previous summary:\n${XmlProcessor.wrapWithTag('previous_summary', previousSummary)}\n\n"
       : "";
   final messagesToSummarizeText = "These are the new messages to be summarized:\n${droppedMessages.map((m) => "${m.role.name}: ${m.rawText}").join('\n---\n')}";
   final userContentForSummary = "$previousSummaryText$messagesToSummarizeText";

   // Manually construct the context to match the required format.
   List<LlmContent> summaryContext = [
     LlmContent("system", [LlmTextPart(summaryPrompt)]),
     LlmContent("user", [LlmTextPart(userContentForSummary)]),
     LlmContent("user", [LlmTextPart(summaryPrompt)]), // Add prompt as last user message
   ];
   
   final response = await llmService.sendMessageOnce(
     llmContext: summaryContext,
     chat: chatForSummaryCall, // Pass chat with overridden system prompt
     apiConfigIdOverride: chat.preprocessingApiConfigId,
   );

   if (_isBackgroundTaskCancelled) return; // Check after API call, before saving

   if (response.isSuccess && response.parts.isNotEmpty) {
     final newSummary = response.parts.map((p) => p.text ?? "").join("\n");
     await chatRepo.saveChat(chat.copyWith(contextSummary: Value(newSummary)));
     debugPrint("ChatStateNotifier($_chatId): Summarization successful. New summary saved.");
   } else {
      throw Exception("Summarization failed: ${response.error ?? 'No content'}");
   }
 }

 // --- State variables for streaming XML processing ---
 final StringBuffer _rawAccumulatedBuffer = StringBuffer();
  final StringBuffer _displayableTextBuffer = StringBuffer();
  // StringBuffer _currentXmlSegmentForDisplay = StringBuffer(); // Not strictly needed if we just suppress
  final Set<String> _processedRuleTagNamesThisTurn = {};
  // --- End of state variables for streaming XML processing ---

  Future<void> _handleStreamResponse(LlmService llmService, Chat chat, List<LlmContent> llmContext) async {
    final messageRepo = _ref.read(messageRepositoryProvider);

    // 1. Create and save a placeholder message to get a stable ID
    final placeholderMessage = Message.create(
      chatId: _chatId,
      role: MessageRole.model,
      rawText: "...", // Start with a placeholder text
    );
    final placeholderId = await messageRepo.saveMessage(placeholderMessage);
    debugPrint("ChatStateNotifier($_chatId): Created placeholder message with ID: $placeholderId.");

    // Initialize stream-specific state
    _rawAccumulatedBuffer.clear();
    _displayableTextBuffer.clear();
    _processedRuleTagNamesThisTurn.clear();

    // Regex to find XML tags

    final stream = llmService.sendMessageStream(llmContext: llmContext, chat: chat);
       _llmStreamSubscription?.cancel();
       _llmStreamSubscription = stream.listen(
         (chunk) async {
           if (!mounted) return;

           if (chunk.error != null) {
             // On error, we still finalize to save what we have and clean up.
             _llmStreamSubscription?.cancel();
             return;
           }
           
           if (chunk.isFinished) {
             // This chunk signals the end, but onDone is the sole handler for finalization.
             return;
           }

           // --- Live Update Logic ---
           final newText = chunk.accumulatedText;
           _rawAccumulatedBuffer.clear();
           _rawAccumulatedBuffer.write(newText);
           
           // Update the placeholder in the database in real-time
           final messageToUpdate = placeholderMessage.copyWith(id: placeholderId, rawText: newText);
           await messageRepo.saveMessage(messageToUpdate);
           // The UI will react to this change via the chatMessagesProvider stream.

           // We no longer need to manage displayable text or complex state here.
           // Just ensure the overall streaming state is active.
           if (!state.isStreaming) {
             state = state.copyWith(isStreaming: true);
           }
         },
         onError: (error) {
           if (mounted) {
             showTopMessage('消息流错误: $error', backgroundColor: Colors.red);
           }
           // `onDone` will be called even on error, so finalization is handled there.
         },
         onDone: () async {
           // onDone is the single source of truth for saving a completed or canceled stream.
           await _finalizeStreamedMessage(placeholderId);
         },
         cancelOnError: true,
       );
 }

 Future<void> _handleSingleResponse(LlmService llmService, Chat chat, List<LlmContent> llmContext, String? initialCarriedOverXml) async {
   try {
     final response = await llmService.sendMessageOnce(llmContext: llmContext, chat: chat);
     if (!mounted) return;

     if (response.isSuccess && response.parts.isNotEmpty) {
       final messageRepo = _ref.read(messageRepositoryProvider);

       // 1. Create an initial message object from the response.
       final aiMessage = Message.create(
         chatId: _chatId,
         role: MessageRole.model,
         parts: response.parts,
       );

       // 2. Immediately save the initial message to the database.
       // This gives us a stable ID and makes it visible in the UI.
       final savedMessageId = await messageRepo.saveMessage(aiMessage);
       final savedMessage = await messageRepo.getMessageById(savedMessageId);
       
       // 3. The main generation is "done", so stop the loading state for the input bar.
       state = state.copyWith(
         isLoading: false,
         clearError: true,
         clearTopMessage: true,
       );
       // Timer is NOT stopped here anymore; it continues for background tasks.

       // 4. Asynchronously run post-processing tasks on the saved message.
       // We now await this to ensure proper completion handling.
       if (savedMessage != null) {
         await _runAsyncProcessingTasks(savedMessage);
       } else {
         // If there's no message, ensure loading state is cleared.
          state = state.copyWith(
            isLoading: false,
            clearGenerationStartTime: true,
            clearElapsedSeconds: true
          );
          _stopUpdateTimer();
       }

       debugPrint("ChatStateNotifier($_chatId): Single response and async tasks finished (ID: $savedMessageId).");
       calculateAndStoreTokenCount(); // Recalculate tokens based on initial saved message.
     } else {
       showTopMessage(response.error ?? "发送消息失败 (可能响应为空)", backgroundColor: Colors.red);
       state = state.copyWith(isLoading: false, clearGenerationStartTime: true, clearElapsedSeconds: true);
     }
   } catch (e) {
     if (mounted) {
       showTopMessage('发送消息时发生意外错误: $e', backgroundColor: Colors.red);
       state = state.copyWith(isLoading: false, clearGenerationStartTime: true, clearElapsedSeconds: true);
     }
   } finally {
     // No need for a finally block to stop the timer, as it's stopped on success.
   }
 }

 // A helper to contain the logic of _executePostGenerationProcessing but return the final message
 Future<Message> _getFinalProcessedMessage(Chat chat, Message initialMessage) async {
   final llmService = _ref.read(llmServiceProvider);
   final contextXmlService = _ref.read(contextXmlServiceProvider);

   final originalRawText = initialMessage.rawText;
   final displayText = XmlProcessor.stripXmlContent(originalRawText);
   final initialXml = XmlProcessor.extractXmlContent(originalRawText);

   String? newSecondaryXmlContent;

   if (chat.enableSecondaryXml && (chat.secondaryXmlPrompt?.isNotEmpty ?? false)) {
     try {
       // 1. 创建一个临时的 Chat 对象，使用附加XML提示词作为系统提示词
       final chatForSecondaryXmlCall = chat.copyWith(
         systemPrompt: chat.secondaryXmlPrompt,
       );

       // 2. 使用主构建逻辑构建上下文，并将附加XML提示词作为最后的用户消息传递。
       final secondaryApiRequestContext = await contextXmlService.buildApiRequestContext(
         chat: chatForSecondaryXmlCall,
         currentUserMessage: initialMessage, // 上下文将包含此消息
         lastMessageOverride: chat.secondaryXmlPrompt, // 将提示词作为最后的用户消息
       );

       // 3. 使用生成的上下文进行调用。
       final response = await llmService.sendMessageOnce(
         llmContext: secondaryApiRequestContext.contextParts,
         chat: chatForSecondaryXmlCall, // 传递相同的修改后的 chat 对象以获取生成配置
         apiConfigIdOverride: chat.secondaryXmlApiConfigId, // Use dedicated API config
       );

       if (response.isSuccess && response.parts.isNotEmpty) {
         final generatedContent = response.parts.map((p) => p.text ?? "").join("\n");
         debugPrint("ChatStateNotifier($_chatId): ========== Secondary XML Raw Content START ==========");
         debugPrint(generatedContent);
         debugPrint("ChatStateNotifier($_chatId): ========== Secondary XML Raw Content END ==========");
         newSecondaryXmlContent = generatedContent;
       } else {
         debugPrint("ChatStateNotifier($_chatId): Secondary XML generation failed. Error: ${response.error}");
       }
     } catch (e) {
       debugPrint("ChatStateNotifier($_chatId): Error during secondary XML generation: $e");
       // Do not assign secondary content on error
     }
   }

   final newRawText = displayText;
 
   // Return a new message object with all final values, ready to be saved.
   return initialMessage.copyWith(
     rawText: newRawText, // rawText now only contains displayable text
     originalXmlContent: initialXml,
     secondaryXmlContent: newSecondaryXmlContent,
   );
 }

  Future<void> cancelGeneration() async {
    // Check against all loading states
    if ((!state.isLoading && !state.isStreaming && !state.isProcessingInBackground) || _isCancelling) {
      debugPrint("Cancel generation skipped: isLoading=${state.isLoading}, isStreaming=${state.isStreaming}, isProcessingInBackground=${state.isProcessingInBackground}, isCancelling=$_isCancelling");
      return;
    }

    _isCancelling = true;
    debugPrint("Attempting to cancel generation for chat $_chatId...");

    try {
      // 1. Set cancellation flag for background tasks
      _isBackgroundTaskCancelled = true;
      debugPrint("ChatStateNotifier($_chatId): Background task cancellation flag set.");

      // 2. Cancel any active LLM request (covers main stream and background tasks)
      await _ref.read(llmServiceProvider).cancelActiveRequest();

      // 3. Cancel the stream subscription if it exists
      if (_llmStreamSubscription != null) {
        await _llmStreamSubscription?.cancel();
        _llmStreamSubscription = null;
      }

      // 4. Finalize state immediately
      final lastMessage = _ref.read(chatMessagesProvider(_chatId)).value?.lastWhereOrNull((m) => m.role == MessageRole.model);
      if (state.isStreaming && lastMessage != null) {
        // If a stream was active, finalize it to save partial progress
        await _finalizeStreamedMessage(lastMessage.id);
      } else {
        // If it was a non-stream or background task, just reset all loading states
        if (mounted) {
          state = state.copyWith(
            isLoading: false,
            isStreaming: false,
            isProcessingInBackground: false,
            clearStreaming: true,
            clearGenerationStartTime: true,
            clearElapsedSeconds: true,
          );
          _stopUpdateTimer();
          showTopMessage("已停止", backgroundColor: Colors.blueGrey);
        }
      }

    } catch (e) {
      debugPrint("Error during cancelGeneration: $e");
      if (mounted) {
        showTopMessage("取消操作时出错: $e", backgroundColor: Colors.red);
      }
    } finally {
      _isCancelling = false;
      debugPrint("Cancellation process finished for chat $_chatId. _isCancelling reset to false.");
    }
  }

  Future<void> _finalizeStreamedMessage(int messageId) async {
    if (!mounted || _isFinalizing) return;
    _isFinalizing = true;
    debugPrint("Finalizing stream for message ID $messageId...");

    final messageRepo = _ref.read(messageRepositoryProvider);
    Message? messageToFinalize;
    bool wasRunning = state.isLoading || state.isStreaming;

    // 1. Get the message object first
    try {
      messageToFinalize = await messageRepo.getMessageById(messageId);
    } catch (e) {
      debugPrint("Error fetching message for finalization (ID $messageId): $e");
    }

    // 2. Always reset the main loading state *before* running background tasks.
    // This makes the UI responsive and clears the way for background tasks.
    if (mounted) {
      // Messages are now handled in the post-processing block to ensure correct timing.
      state = state.copyWith(
        isLoading: false,
        isStreaming: false,
        clearStreaming: true,
      );
      // _stopUpdateTimer() and timer state clearing are moved to _runAsyncProcessingTasks's finally block.
      calculateAndStoreTokenCount();
    }

    // 3. Now, with the main state cleared, run async post-processing.
    try {
      final chat = _ref.read(currentChatProvider(_chatId)).value;
      if (chat != null && messageToFinalize != null) {
        debugPrint("Running async post-processing for message ID $messageId...");
        await _runAsyncProcessingTasks(messageToFinalize);
        debugPrint("Async post-processing for message ID $messageId finished.");
        if (mounted && !_isBackgroundTaskCancelled) {
          showTopMessage("已完成", backgroundColor: Colors.green);
        }
      } else {
        debugPrint("Skipping async post-processing for message ID $messageId: chat or message not found.");
        if (mounted && wasRunning) {
           showTopMessage("已停止", backgroundColor: Colors.blueGrey);
        }
      }
    } catch (e) {
      debugPrint("Error during async post-processing for ID $messageId: $e");
      if (mounted) {
        showTopMessage('后台处理任务出错: $e', backgroundColor: Colors.red);
      }
    } finally {
      _isFinalizing = false;
      debugPrint("Finalization process finished for message ID $messageId. _isFinalizing reset to false.");
    }
  }

 void _startUpdateTimer() {
   _stopUpdateTimer();
   if (state.generationStartTime == null) return;

   _updateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
     if (!mounted) {
       timer.cancel();
       return;
     }
     final startTime = state.generationStartTime;
     if (startTime != null) {
       final seconds = DateTime.now().difference(startTime).inSeconds;
       state = state.copyWith(elapsedSeconds: seconds);
     } else {
       timer.cancel();
       _updateTimer = null;
       if (state.elapsedSeconds != null) {
          state = state.copyWith(clearElapsedSeconds: true);
       }
     }
   });
   debugPrint("Notifier: 启动了 UI 更新计时器。");
 }

 void _stopUpdateTimer() {
   if (_updateTimer?.isActive ?? false) {
     _updateTimer!.cancel();
     _updateTimer = null;
     debugPrint("Notifier: 停止了 UI 更新计时器。");
   }
 }

  Future<void> _executeAutoTitleGeneration(Chat chat, Message currentModelMessage) async {
    if (_isBackgroundTaskCancelled) return; // Check for cancellation
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted || _isBackgroundTaskCancelled) return;

    final globalSettings = _ref.read(globalSettingsProvider);
    if (!globalSettings.enableAutoTitleGeneration ||
        globalSettings.titleGenerationPrompt.isEmpty ||
        globalSettings.titleGenerationApiConfigId == null) {
      return;
    }

    final allMessages = _ref.read(chatMessagesProvider(_chatId)).value ?? [];
    final modelMessagesCount = allMessages.where((m) => m.role == MessageRole.model).length;

    if (modelMessagesCount != 1) {
      debugPrint("ChatStateNotifier($_chatId): Skipping auto title generation. Model messages count: $modelMessagesCount");
      return;
    }

    debugPrint("ChatStateNotifier($_chatId): Starting auto title generation...");

    try {
      final contextXmlService = _ref.read(contextXmlServiceProvider);
      final llmService = _ref.read(llmServiceProvider);
      final chatRepo = _ref.read(chatRepositoryProvider);

      final chatForTitleCall = chat.copyWith(
        systemPrompt: globalSettings.titleGenerationPrompt,
      );

      final apiRequestContext = await contextXmlService.buildApiRequestContext(
        chat: chatForTitleCall,
        currentUserMessage: currentModelMessage, // The context is built up to the latest model message
        lastMessageOverride: globalSettings.titleGenerationPrompt, // The prompt is added as the very last user message
      );

      if (_isBackgroundTaskCancelled) return; // Check before API call

      final response = await llmService.sendMessageOnce(
        llmContext: apiRequestContext.contextParts,
        chat: chatForTitleCall,
        apiConfigIdOverride: globalSettings.titleGenerationApiConfigId,
      );

      if (_isBackgroundTaskCancelled) return; // Check after API call

      if (response.isSuccess && response.parts.isNotEmpty) {
        final newTitle = response.parts.map((p) => p.text ?? "").join("").trim().replaceAll(RegExp(r'["\n]'), '');
        if (newTitle.isNotEmpty) {
          final currentChat = await chatRepo.getChat(_chatId);
          if (currentChat != null && mounted && !_isBackgroundTaskCancelled) {
            await chatRepo.saveChat(currentChat.copyWith(title: newTitle));
            debugPrint("ChatStateNotifier($_chatId): Auto title generation successful. New title: $newTitle");
          }
        } else {
          debugPrint("ChatStateNotifier($_chatId): Auto title generation resulted in an empty title. Skipping update.");
        }
      } else {
        throw Exception("Title generation failed: ${response.error ?? 'No content'}");
      }
    } catch (e) {
      if (!_isBackgroundTaskCancelled) {
        debugPrint("ChatStateNotifier($_chatId): Error during auto title generation: $e");
        // Silently fail.
      }
    }
  }

  // --- Special Actions ---

  Future<void> resumeGeneration() async {
    if (state.isLoading) {
      showTopMessage('正在生成中，请稍后...', backgroundColor: Colors.orange);
      return;
    }

    final lastMessage = _ref.read(lastModelMessageProvider(_chatId));
    if (lastMessage == null) {
      showTopMessage('没有可恢复的消息', backgroundColor: Colors.orange);
      return;
    }

    final globalSettings = _ref.read(globalSettingsProvider);
    if (!globalSettings.enableResume) {
      showTopMessage('中断恢复功能已禁用', backgroundColor: Colors.orange);
      return;
    }

    await _sendMessageForSpecialAction(
      prompt: globalSettings.resumePrompt,
      apiConfigIdOverride: globalSettings.resumeApiConfigId,
      actionType: _SpecialActionType.resume,
      targetMessage: lastMessage,
      useChatSystemPrompt: true,
    );
  }

  Future<void> generateHelpMeReply({Function(List<String>)? onSuggestionsReady}) async {
    // Rely on the new unified background processing state, but only for manual calls.
    if ((state.isLoading || state.isProcessingInBackground) && onSuggestionsReady != null) {
      // For manual clicks, show a message. For auto-runs, this will be skipped.
      showTopMessage('正在处理中，请稍后...', backgroundColor: Colors.orange);
      return;
    }

    if (state.helpMeReplySuggestions != null && state.helpMeReplySuggestions!.isNotEmpty) {
      debugPrint("ChatStateNotifier($_chatId): Using cached 'Help Me Reply' suggestions.");
      onSuggestionsReady?.call(state.helpMeReplySuggestions!);
      return;
    }

    final lastMessage = _ref.read(lastModelMessageProvider(_chatId));
    if (lastMessage == null) {
      if (onSuggestionsReady != null) showTopMessage('没有可供回复的消息', backgroundColor: Colors.orange);
      return;
    }

    final globalSettings = _ref.read(globalSettingsProvider);
    if (!globalSettings.enableHelpMeReply) {
      if (onSuggestionsReady != null) showTopMessage('“帮我回复”功能已禁用', backgroundColor: Colors.orange);
      return;
    }

    // This method is now a wrapper. The actual work is in _sendMessageForSpecialAction.
    // For manual calls, we need to wrap it in the background task handler.
    // For automatic calls, it's already wrapped by _runAsyncProcessingTasks.
    final task = _sendMessageForSpecialAction(
      prompt: globalSettings.helpMeReplyPrompt,
      apiConfigIdOverride: globalSettings.helpMeReplyApiConfigId,
      actionType: _SpecialActionType.helpMeReply,
      targetMessage: lastMessage,
      onSuggestionsReady: onSuggestionsReady,
      useChatSystemPrompt: false,
    );

    // If called manually (onSuggestionsReady is not null), we need to manage the background state.
    if (onSuggestionsReady != null) {
      await _runManagedSingleTask(task);
    } else {
      // If called automatically, just return the future to be awaited by Future.wait
      await task;
    }
  }

  @override
 void dispose() {
   _llmStreamSubscription?.cancel();
   _stopUpdateTimer();
   _topMessageTimer?.cancel(); // Dispose the top message timer
   super.dispose();
 }

  Future<void> _sendMessageForSpecialAction({
    required String prompt,
    required String? apiConfigIdOverride,
    required _SpecialActionType actionType,
    required Message targetMessage,
    required bool useChatSystemPrompt,
    Function(List<String>)? onSuggestionsReady,
  }) async {
    // This method no longer manages loading state directly.
    // It's managed by the calling context (_runAsyncProcessingTasks or _runManagedSingleTask)
    if (_isBackgroundTaskCancelled) return;

    final chat = _ref.read(currentChatProvider(_chatId)).value;
    if (chat == null) {
      if (mounted) showTopMessage('无法执行操作：聊天数据未加载', backgroundColor: Colors.red);
      return;
    }

    final contextXmlService = _ref.read(contextXmlServiceProvider);
    final llmService = _ref.read(llmServiceProvider);

    final chatForCall = useChatSystemPrompt ? chat : chat.copyWith(systemPrompt: prompt);

    final apiRequestContext = await contextXmlService.buildApiRequestContext(
      chat: chatForCall,
      currentUserMessage: targetMessage,
      lastMessageOverride: prompt,
      // For resume actions, we need to preserve the XML of the target message
      messageIdToPreserveXml: actionType == _SpecialActionType.resume ? targetMessage.id : null,
    );

    if (_isBackgroundTaskCancelled) return;

    final response = await llmService.sendMessageOnce(
      llmContext: apiRequestContext.contextParts,
      chat: chatForCall,
      apiConfigIdOverride: apiConfigIdOverride ?? chat.apiConfigId,
    );

    if (!mounted || _isBackgroundTaskCancelled) return;

    if (response.isSuccess && response.parts.isNotEmpty) {
      final generatedText = response.parts.map((p) => p.text ?? "").join("\n");
      switch (actionType) {
        case _SpecialActionType.resume:
          // 1. Construct the fully resumed message in memory using copyWith.
          final resumedMessage = targetMessage.copyWith(
            rawText: generatedText, // This will replace the text parts.
            secondaryXmlContent: null, // Clear the secondary XML for reprocessing.
          );

          // 2. Instead of just saving, run the full async processing pipeline.
          // This ensures secondary XML is regenerated, summarization is triggered if needed, etc.
          // _runAsyncProcessingTasks will handle saving the updated message to the database.
          await _runAsyncProcessingTasks(resumedMessage);

          if (mounted && !_isBackgroundTaskCancelled) {
            showTopMessage('内容已恢复并处理', backgroundColor: Colors.green);
          }
          break;
        case _SpecialActionType.helpMeReply:
          final suggestions = RegExp(r'^\s*\d+\.\s*(.*)', multiLine: true)
              .allMatches(generatedText)
              .map((m) => m.group(1)!.trim())
              .toList();
          final finalSuggestions = suggestions.isNotEmpty ? suggestions : [generatedText.trim()];
          if (mounted) {
            state = state.copyWith(helpMeReplySuggestions: finalSuggestions);
          }
          onSuggestionsReady?.call(finalSuggestions);
          break;
      }
    } else {
      if (mounted) showTopMessage(response.error ?? "操作失败", backgroundColor: Colors.red);
    }
  }

  // Helper to run a single manual background task with state management
  Future<void> _runManagedSingleTask(Future<void> task) async {
    if (!mounted) return;
    _isBackgroundTaskCancelled = false;
    state = state.copyWith(isProcessingInBackground: true);
    try {
      await task;
    } catch (e) {
      if (!_isBackgroundTaskCancelled && mounted) {
        showTopMessage('操作失败: $e', backgroundColor: Colors.red);
      }
    } finally {
      if (mounted) {
        state = state.copyWith(isProcessingInBackground: false);
      }
    }
  }
}

enum _SpecialActionType { resume, helpMeReply }

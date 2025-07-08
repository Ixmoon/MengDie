import 'dart:async'; // For StreamSubscription, Timer
import 'dart:math'; // Import for min function

import 'package:flutter/foundation.dart'; // for immutable, kDebugMode, debugPrint
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart'; // Added for Color type

import 'package:drift/drift.dart' show Value;
import '../models/models.dart';
import '../repositories/chat_repository.dart';
import '../repositories/message_repository.dart';
import '../services/llm_service.dart'; // Import the generic LLM service and types
import '../services/context_xml_service.dart'; // Import the new service
import 'package:collection/collection.dart'; // Import for lastWhereOrNull
import '../data/database/drift/common_enums.dart' as drift_enums; // Added import
import '../services/xml_processor.dart'; // Added import


// 本文件包含与聊天数据和聊天界面状态相关的 Riverpod 提供者。

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
  final String? streamingMessageContent;
  final DateTime? streamingTimestamp;
  final DateTime? generationStartTime;
  final bool isStreaming;
  final bool isStreamMode;
  final int? elapsedSeconds;
  final bool isBubbleTransparent;
  final bool isBubbleHalfWidth;
  final bool isMessageListHalfHeight;
  final int? totalTokens;

  const ChatScreenState({
    this.isLoading = false,
    this.streamingTimestamp,
    this.generationStartTime,
    this.errorMessage,
    this.topMessageText,
    this.topMessageColor,
    this.streamingMessageContent,
    this.isStreaming = false,
    this.isStreamMode = true,
    this.elapsedSeconds,
    this.isBubbleTransparent = false,
    this.isBubbleHalfWidth = false,
    this.isMessageListHalfHeight = false,
    this.totalTokens,
  });

  ChatScreenState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false, // If true, sets errorMessage to null
    String? topMessageText,
    Color? topMessageColor,
    bool clearTopMessage = false, // If true, sets topMessageText and topMessageColor to null
    String? streamingMessageContent,
    DateTime? streamingTimestamp,
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
    int? totalTokens,
    bool clearTotalTokens = false,
  }) {
    return ChatScreenState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      topMessageText: clearTopMessage ? null : (topMessageText ?? this.topMessageText),
      topMessageColor: clearTopMessage ? null : (topMessageColor ?? this.topMessageColor),
      streamingMessageContent: clearStreaming ? null : (streamingMessageContent ?? this.streamingMessageContent),
      streamingTimestamp: clearStreaming ? null : (streamingTimestamp ?? this.streamingTimestamp),
      generationStartTime: clearGenerationStartTime ? null : (generationStartTime ?? this.generationStartTime),
      isStreaming: clearStreaming ? false : (isStreaming ?? this.isStreaming),
      isStreamMode: isStreamMode ?? this.isStreamMode,
      elapsedSeconds: clearElapsedSeconds ? null : (elapsedSeconds ?? this.elapsedSeconds),
      isBubbleTransparent: isBubbleTransparent ?? this.isBubbleTransparent,
      isBubbleHalfWidth: isBubbleHalfWidth ?? this.isBubbleHalfWidth,
      isMessageListHalfHeight: isMessageListHalfHeight ?? this.isMessageListHalfHeight,
      totalTokens: clearTotalTokens ? null : (totalTokens ?? this.totalTokens),
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
    state = state.copyWith(isMessageListHalfHeight: !state.isMessageListHalfHeight);
    showTopMessage('消息列表高度已切换为: ${state.isMessageListHalfHeight ? "半高" : "全高"}');
    debugPrint("Chat ($_chatId) 消息列表高度模式切换为: ${state.isMessageListHalfHeight ? "半高" : "全高"}");
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

  Future<void> editMessage(int messageId, {String? newText, List<MessagePart>? newParts}) async {
    if (!mounted) return;
    try {
      final messageRepo = _ref.read(messageRepositoryProvider);
      final message = await messageRepo.getMessageById(messageId);
      if (message == null) {
        showTopMessage('无法编辑：未找到消息', backgroundColor: Colors.red);
        return;
      }

      Message updatedMessage;
      if (newParts != null) {
        updatedMessage = message.copyWith(parts: newParts);
      } else if (newText != null) {
        updatedMessage = message.copyWith(rawText: newText);
      } else {
        return; // Nothing to update
      }
      
      await messageRepo.saveMessage(updatedMessage);

      if (mounted) {
        showTopMessage('消息已更新', backgroundColor: Colors.green, duration: const Duration(seconds: 2));
        calculateAndStoreTokenCount(); // Recalculate tokens
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
        ..generationConfig = originalChat.generationConfig
        ..contextConfig = originalChat.contextConfig
        ..xmlRules = List.from(originalChat.xmlRules)
        ..apiType = originalChat.apiType
        ..selectedOpenAIConfigId = originalChat.selectedOpenAIConfigId
        ..enablePreprocessing = originalChat.enablePreprocessing
        ..preprocessingPrompt = originalChat.preprocessingPrompt
        ..contextSummary = null // Forked chat starts fresh
        ..enablePostprocessing = originalChat.enablePostprocessing
        ..postprocessingPrompt = originalChat.postprocessingPrompt
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

  Future<void> sendMessage({
    List<MessagePart>? userParts,
    Message? userMessage, // Used for regeneration
    bool isRegeneration = false
  }) async {
    if (state.isLoading && !isRegeneration) {
      debugPrint("sendMessage ($_chatId) 取消：已在加载中且非重新生成。");
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
        generationStartTime: DateTime.now(),
        elapsedSeconds: 0);
    _startUpdateTimer();
    
    // --- Save new user messages (if not regenerating) ---
    if (!isRegeneration) {
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
      final apiRequestContext = await contextXmlService.buildApiRequestContext(
        chat: chat,
        currentUserMessage: messageForContext, // Pass the representative message for context
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
       _handleStreamResponse(llmService, chat, llmApiContext, carriedOverXmlForThisTurn);
     } else {
       await _handleSingleResponse(llmService, chat, llmApiContext, carriedOverXmlForThisTurn);
     }
   }

 // --- Post-Generation Processing ---
 Future<void> _runAsyncProcessingTasks(Message modelMessage) async {
   if (!mounted) return;
   final chat = _ref.read(currentChatProvider(_chatId)).value;
   if (chat == null) return;

   List<Future> tasks = [];

   if (chat.enablePostprocessing && (chat.postprocessingPrompt?.isNotEmpty ?? false)) {
     tasks.add(_executePostprocessing(chat, modelMessage));
   }
   
   // Pre-processing depends on the result of context building, which happened before sending.
   // We need access to the `droppedMessages` from that step.
   // This is a structural challenge. For now, we'll re-calculate it.
   // A better approach would be to pass `apiRequestContext` through the send methods.
   if (chat.enablePreprocessing && (chat.preprocessingPrompt?.isNotEmpty ?? false)) {
      tasks.add(_executePreprocessing(chat));
   }

   if (tasks.isNotEmpty) {
     try {
       await Future.wait(tasks);
       debugPrint("ChatStateNotifier($_chatId): Async processing tasks completed.");
     } catch (e) {
       debugPrint("ChatStateNotifier($_chatId): Error during async processing tasks: $e");
       if (mounted) {
         showTopMessage("后台处理任务出错: $e", backgroundColor: Colors.red.withAlpha(204));
       }
     }
   }
 }

 Future<void> _executePostprocessing(Chat chat, Message modelMessage) async {
   debugPrint("ChatStateNotifier($_chatId): Executing post-processing...");
   final messageRepo = _ref.read(messageRepositoryProvider);
   final llmService = _ref.read(llmServiceProvider);

   // 1. Save original XML content
   final originalRawText = modelMessage.rawText;
   final originalXml = XmlProcessor.extractXmlContent(originalRawText);
   
   var messageToUpdate = await messageRepo.getMessageById(modelMessage.id);
   if (messageToUpdate == null) return;
   
   messageToUpdate = messageToUpdate.copyWith(originalXmlContent: originalXml);
   await messageRepo.saveMessage(messageToUpdate);

   // 2. Build new request for post-processing
   final contextXmlService = _ref.read(contextXmlServiceProvider);
   final apiRequestContext = await contextXmlService.buildApiRequestContext(
     chat: chat.copyWith(systemPrompt: chat.postprocessingPrompt), // Replace system prompt
     currentUserMessage: messageToUpdate,
   );
   
   // 3. Call LLM service (not streaming)
   final response = await llmService.sendMessageOnce(
     llmContext: apiRequestContext.contextParts,
     chat: chat,
   );

   if (response.isSuccess && response.parts.isNotEmpty) {
     // 4. Merge results
     final postprocessedText = response.parts.map((p) => p.text ?? "").join("\n");
     final originalDisplayText = XmlProcessor.stripXmlContent(originalRawText);
     
     final newRawText = (originalDisplayText.isNotEmpty && postprocessedText.isNotEmpty)
         ? '$originalDisplayText\n$postprocessedText'
         : originalDisplayText + postprocessedText;
     
     messageToUpdate = await messageRepo.getMessageById(modelMessage.id); // Re-fetch latest version
     if (messageToUpdate == null) return;

     messageToUpdate = messageToUpdate.copyWith(rawText: newRawText);
     await messageRepo.saveMessage(messageToUpdate);
     debugPrint("ChatStateNotifier($_chatId): Post-processing successful. Message updated.");
   } else {
     throw Exception("Post-processing failed: ${response.error ?? 'No content'}");
   }
 }

 Future<void> _executePreprocessing(Chat chat) async {
     debugPrint("ChatStateNotifier($_chatId): Executing pre-processing (summarization)...");
     final contextXmlService = _ref.read(contextXmlServiceProvider);
     final llmService = _ref.read(llmServiceProvider);
     final chatRepo = _ref.read(chatRepositoryProvider);

     // Re-build context to find dropped messages. This is inefficient but necessary with current structure.
     final placeholderMessage = Message.create(chatId: _chatId, role: MessageRole.user, rawText: "[Preprocessing Placeholder]");
     final apiRequestContext = await contextXmlService.buildApiRequestContext(chat: chat, currentUserMessage: placeholderMessage);
     final droppedMessages = apiRequestContext.droppedMessages;

     if (droppedMessages.isEmpty) {
       debugPrint("ChatStateNotifier($_chatId): No messages dropped, skipping summarization.");
       return;
     }
     
     // Build summarization prompt
     final summaryPrompt = chat.preprocessingPrompt!;
     final previousSummary = chat.contextSummary;
     
     List<LlmContent> summaryContext = [
       LlmContent("system", [LlmTextPart(summaryPrompt)])
     ];

     if(previousSummary != null && previousSummary.isNotEmpty) {
       summaryContext.add(LlmContent("user", [LlmTextPart("This is the previous summary:\n${XmlProcessor.wrapWithTag('previous_summary', previousSummary)}")]));
     }

     summaryContext.add(LlmContent("user", [
       LlmTextPart("These are the messages to be summarized:\n${droppedMessages.map((m) => "${m.role.name}: ${m.rawText}").join('\n---\n')}")
     ]));
     
     // Call LLM service
     final response = await llmService.sendMessageOnce(
       llmContext: summaryContext,
       chat: chat, // Pass chat for generation config
     );

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
  int _displayLogicOpenTagCount = 0;
  bool _displayLogicLastTagWasClosing = false;
  bool _suppressDisplay = false;
  // StringBuffer _currentXmlSegmentForDisplay = StringBuffer(); // Not strictly needed if we just suppress
  final Set<String> _processedRuleTagNamesThisTurn = {};
  String? _currentTurnCarriedOverXml;
  // --- End of state variables for streaming XML processing ---

  void _handleStreamResponse(LlmService llmService, Chat chat, List<LlmContent> llmContext, String? initialCarriedOverXml) {
    // Initialize stream-specific state
    _rawAccumulatedBuffer.clear();
    _displayableTextBuffer.clear();
    _displayLogicOpenTagCount = 0;
    _displayLogicLastTagWasClosing = false;
    _suppressDisplay = false;
    _processedRuleTagNamesThisTurn.clear();
    _currentTurnCarriedOverXml = initialCarriedOverXml;

    // Regex to find XML tags
    final xmlTagRegex = RegExp(r"<(\/)?([a-zA-Z0-9_:\-]+)[^>]*>", caseSensitive: false);

    final stream = llmService.sendMessageStream(llmContext: llmContext, chat: chat);
       _llmStreamSubscription?.cancel();
       _llmStreamSubscription = stream.listen(
         (chunk) async {
           if (!mounted) return;

           if (chunk.error != null) {
             showTopMessage('消息流错误: ${chunk.error}', backgroundColor: Colors.red);
             state = state.copyWith(
               isLoading: false, isStreaming: false, // errorMessage: chunk.error, // Error is shown via top message
               clearStreaming: true, clearGenerationStartTime: true, clearElapsedSeconds: true,
             );
             _stopUpdateTimer();
             _llmStreamSubscription?.cancel();
             return;
           }
           
           if (chunk.isFinished) {
          // Final processing on stream completion
          // The LlmService's saveMessageFromStream should handle saving with the final buffers.
          // No explicit XmlProcessor.process call here unless specifically needed for a final sweep,
          // as rule closures should have been handled during the stream.
          debugPrint("ChatStateNotifier:handleStreamResponse - Stream finished. Raw: ${_rawAccumulatedBuffer.toString().substring(0, min(_rawAccumulatedBuffer.length, 100))}, Displayed: ${_displayableTextBuffer.toString().substring(0, min(_displayableTextBuffer.length, 100))}");
          state = state.copyWith(
            isLoading: false, isStreaming: false,
            clearStreaming: true, clearGenerationStartTime: true, clearElapsedSeconds: true,
          );
          _stopUpdateTimer();
          calculateAndStoreTokenCount(); // Recalculate on finish
          // Ensure the LlmService knows about the final raw and displayable text, and carriedOverXml
          // This is implicitly handled by how LlmService.saveMessageFromStream gets its data.
          // We might need to explicitly pass these if LlmService doesn't have access to these buffers.
          // For now, assuming LlmService's saveMessageFromStream uses chunk.accumulatedText (raw)
          // and we provide the final _displayableTextBuffer and _currentTurnCarriedOverXml separately if needed.
          // The LlmService's stream listener itself is responsible for calling saveMessageFromStream with the correct final data.
          // The `accumulatedText` in `LlmStreamChunk` should be the raw, full text.
          // `displayedText` and `finalCarriedOverXml` are now managed here.
          // This part might need refinement depending on LlmService's actual save mechanism.
          // Let's assume LlmService.sendMessageStream's onDone or isFinished handling will get the correct accumulated raw text.
          // We need a way to communicate _displayableTextBuffer and _currentTurnCarriedOverXml.
          // This might involve modifying LlmService or having save logic here.
          // For now, the primary goal is the streaming display and XML processing logic.
          // The llmService.saveMessageFromStream will eventually be called by the LlmService itself when the stream ends.
          // It will pass the raw accumulated text. We need to ensure the correct 'displayed' text and 'carriedOverXml'
          // are also persisted for that message. This typically means the Message object itself needs to store these,
          // or the save mechanism in LlmService needs to be aware of them.
          // Given the current structure, LlmService's saveMessageFromStream takes the raw text.
          // The XmlProcessor.process is called by ContextXmlService *before* sending, and then *after* response by LlmService.
          // This needs to be harmonized.
          // The user's last point "总结: 只有规则闭合才调用xml处理" implies XmlProcessor.process is called *during* the stream on rule closure.

          // Let's assume that when chunk.isFinished, LlmService will save the raw message (_rawAccumulatedBuffer).
          // We need to ensure the *message object* eventually stored reflects the correct carriedOverXml for the *next* turn,
          // which is _currentTurnCarriedOverXml.
          // And if the UI shows something different from raw text, that also needs consideration for storage if necessary.
          // The existing LlmService.saveMessageFromStream likely calls XmlProcessor.process on the full raw text at the end.
          // This might be redundant if we've processed rules mid-stream.

          // For now, let's focus on the streaming logic and assume the save mechanism will be adapted.
          // The key is that _currentTurnCarriedOverXml holds the latest state.
          debugPrint("ChatStateNotifier($_chatId): Stream successful.");
          return;
        }

        // Actual new text for this chunk
        String newTextSegment;
        final String currentChunkAccumulatedText = chunk.accumulatedText;
        final int rawBufferLength = _rawAccumulatedBuffer.length;

        if (currentChunkAccumulatedText.length > rawBufferLength && currentChunkAccumulatedText.startsWith(_rawAccumulatedBuffer.toString())) {
          newTextSegment = currentChunkAccumulatedText.substring(rawBufferLength);
        } else if (rawBufferLength == 0) {
          newTextSegment = currentChunkAccumulatedText;
        } else {
          newTextSegment = ""; // Fallback or log an issue if accumulated text isn't a superset
          if (kDebugMode) {
            // Avoid debugPrint in release builds if not Flutter's debugPrint
            print("ChatStateNotifier: Warning - Could not derive newTextSegment reliably. Accumulated: ${currentChunkAccumulatedText.substring(0, min(currentChunkAccumulatedText.length, 50))}, Buffer: ${_rawAccumulatedBuffer.toString().substring(0, min(_rawAccumulatedBuffer.length, 50))}");
          }
        }
        
        if (newTextSegment.isNotEmpty) {
          _rawAccumulatedBuffer.write(newTextSegment);

          int currentPosInNewSegment = 0;
          for (final match in xmlTagRegex.allMatches(newTextSegment)) {
            // Text before the tag in the new segment
            String textBeforeTagInSegment = newTextSegment.substring(currentPosInNewSegment, match.start);
            if (!_suppressDisplay) {
              _displayableTextBuffer.write(textBeforeTagInSegment);
            }
            currentPosInNewSegment = match.end;

            // Process the tag
            bool isClosingTag = match.group(1) != null; // group(1) is "/"
            // String tagName = match.group(2)!; // If needed

            if (isClosingTag) {
              _displayLogicOpenTagCount--;
              _displayLogicLastTagWasClosing = true;
            } else {
              _displayLogicOpenTagCount++;
              _displayLogicLastTagWasClosing = false;
              _suppressDisplay = true; // Start suppressing on any open tag
            }

            if (_displayLogicOpenTagCount == 0 && _displayLogicLastTagWasClosing) {
              if (_suppressDisplay) { // Only flip if we were suppressing
                  _suppressDisplay = false; // Simple closure, allow display of subsequent text
              }
            } else if (_displayLogicOpenTagCount < 0) {
              _displayLogicOpenTagCount = 0; // Reset on malformed
            }
          }

          // Text after the last tag in the current new segment
          String textAfterLastTagInSegment = newTextSegment.substring(currentPosInNewSegment);
          if (!_suppressDisplay) {
            _displayableTextBuffer.write(textAfterLastTagInSegment);
          }
        } else if (_rawAccumulatedBuffer.isEmpty && currentChunkAccumulatedText.isNotEmpty && newTextSegment.isEmpty) {
            // This case might happen if the very first chunk's accumulatedText was assigned to newTextSegment,
            // and then _rawAccumulatedBuffer was updated.
            // For safety, if newTextSegment is empty but raw buffer isn't, and display isn't suppressed,
            // it might mean the display buffer is out of sync.
            // However, the primary logic relies on processing `newTextSegment`.
            // If `newTextSegment` is empty, no new displayable text from tags processing.
            // But if _suppressDisplay is false, and newTextSegment IS empty because the delta was empty,
            // _displayableTextBuffer won't change, which is correct.
        }
        
        // --- Rule Closure Processing (always based on the full _rawAccumulatedBuffer) ---
        final fullRawText = _rawAccumulatedBuffer.toString();
        bool newXmlProcessedThisChunk = false;
        for (final rule in chat.xmlRules) {
          if (rule.tagName == null || (rule.action != drift_enums.XmlAction.save && rule.action != drift_enums.XmlAction.update)) {
            continue;
          }
          final ruleTagName = rule.tagName!;
          final ruleTagNameLower = ruleTagName.toLowerCase();

          if (_processedRuleTagNamesThisTurn.contains(ruleTagNameLower)) {
            continue;
          }

          // Basic check for rule tag closure. This is a simplified check.
          // A more robust solution might involve a mini-parser or more complex regex.
          // This checks for the presence of both an opening and a closing tag for the specific rule.
          // It doesn't guarantee well-formedness or correct nesting with other tags.
          final openingRuleTagPattern = RegExp("<${RegExp.escape(ruleTagName)}([\\s>][^>]*)?>", caseSensitive: false);
          final closingRuleTagPattern = RegExp("</${RegExp.escape(ruleTagName)}\\s*>", caseSensitive: false);
          
          if (openingRuleTagPattern.hasMatch(fullRawText) && closingRuleTagPattern.hasMatch(fullRawText)) {
             // To ensure the closing tag appears after an opening tag (very basic order check)
             final firstOpenMatch = openingRuleTagPattern.firstMatch(fullRawText);
             final firstCloseMatch = closingRuleTagPattern.firstMatch(fullRawText);

             if (firstOpenMatch != null && firstCloseMatch != null && firstCloseMatch.start > firstOpenMatch.start) {
                debugPrint("ChatStateNotifier: Rule <$ruleTagName> detected as closed. Processing XML.");
                try {
                    final processResult = XmlProcessor.process(
                    fullRawText, // Process the whole accumulated buffer
                    chat.xmlRules, // Pass all rules, XmlProcessor will find the relevant one
                    previousCarriedOverContent: _currentTurnCarriedOverXml
                  );
                  // XmlProcessor.process is designed to handle all rules internally
                  // and figure out what changed based on the full rawText.
                  // The key is that it gets the *current* _currentTurnCarriedOverXml.
                  // If it internally processes multiple rules, the result.carriedOverContent will reflect that.

                  if (_currentTurnCarriedOverXml != processResult.carriedOverContent) {
                    _currentTurnCarriedOverXml = processResult.carriedOverContent;
                    newXmlProcessedThisChunk = true; // Indicate that XML state might have changed
                     debugPrint("ChatStateNotifier: _currentTurnCarriedOverXml updated to: ${_currentTurnCarriedOverXml?.substring(0,min(_currentTurnCarriedOverXml?.length ?? 0, 100))}");
                  }
                  _processedRuleTagNamesThisTurn.add(ruleTagNameLower); // Mark as processed for this turn
                } catch (e) {
                   debugPrint("ChatStateNotifier: Error processing XML for rule <$ruleTagName>: $e");
                }
             }
          }
        }

         state = state.copyWith(
           isLoading: true, // Still loading as stream is active
           isStreaming: true,
           streamingMessageContent: _displayableTextBuffer.toString(),
           streamingTimestamp: chunk.timestamp,
           clearError: true, // Clears critical error
           clearTopMessage: false, // Don't clear top message during stream
         );
         
         // If XML was processed, we might want to signal LlmService or ensure the final carriedOverXml is used.
        // This is handled by _currentTurnCarriedOverXml being updated.
        if (newXmlProcessedThisChunk) {
            // Potentially log or handle side-effects of XML processing if necessary
        }

      },
       onError: (error) {
         if (mounted) {
           showTopMessage('消息流错误: $error', backgroundColor: Colors.red);
           state = state.copyWith(
               isLoading: false, isStreaming: false, // errorMessage: "消息流错误: $error", // Error shown via top message
               clearGenerationStartTime: true, clearElapsedSeconds: true
           );
           _stopUpdateTimer();
         }
       },
       onDone: () {
       if (mounted && (state.isStreaming || state.isLoading)) {
         // This onDone is for the stream subscription.
         // The LlmService's onDone/isFinished logic will handle the final message saving.
         // We ensure our internal buffers are up-to-date.
         // The final state update for isLoading=false etc., is typically done when chunk.isFinished is true.
         state = state.copyWith(
             isLoading: false, isStreaming: false,
             clearStreaming: true, clearGenerationStartTime: true, clearElapsedSeconds: true,
             // Potentially clear top message here if it was a stream-specific message
             // clearTopMessage: state.topMessageText == "Streaming..." // Example condition
         );
         _stopUpdateTimer();
         debugPrint("ChatStateNotifier: Stream subscription onDone. Final raw: ${_rawAccumulatedBuffer.toString().substring(0, min(_rawAccumulatedBuffer.length, 100))}, Displayed: ${_displayableTextBuffer.toString().substring(0, min(_displayableTextBuffer.length, 100))}");
         calculateAndStoreTokenCount(); // Recalculate on done
      }
     },
     cancelOnError: true,
   );
 }

 Future<void> _handleSingleResponse(LlmService llmService, Chat chat, List<LlmContent> llmContext, String? initialCarriedOverXml) async {
   try {
     final response = await llmService.sendMessageOnce(llmContext: llmContext, chat: chat);
     if (mounted) {
       if (response.isSuccess && response.parts.isNotEmpty) {
         // The response now contains parts, we need to save it as a message
         final messageRepo = _ref.read(messageRepositoryProvider);
         final aiMessage = Message.create(
           chatId: _chatId,
           role: MessageRole.model,
           parts: response.parts,
         );
         await messageRepo.saveMessage(aiMessage);
         
         state = state.copyWith(
             isLoading: false,
             clearError: true,
             clearTopMessage: true,
             clearGenerationStartTime: true,
             clearElapsedSeconds: true);
         debugPrint("ChatStateNotifier($_chatId): Single response successful and saved.");
         calculateAndStoreTokenCount(); // Recalculate on success

         // Run post-processing tasks
         _runAsyncProcessingTasks(aiMessage);

       } else {
         showTopMessage(response.error ?? "发送消息失败 (可能响应为空)", backgroundColor: Colors.red);
         state = state.copyWith(isLoading: false, clearGenerationStartTime: true, clearElapsedSeconds: true);
       }
     }
   } catch (e) {
     if (mounted) {
       showTopMessage('发送消息时发生意外错误: $e', backgroundColor: Colors.red);
       state = state.copyWith(isLoading: false, clearGenerationStartTime: true, clearElapsedSeconds: true);
     }
   } finally {
     if (mounted && (state.isLoading || state.generationStartTime != null)) {
        state = state.copyWith(isLoading: false, clearGenerationStartTime: true, clearElapsedSeconds: true);
     }
     _stopUpdateTimer();
   }
 }

  Future<void> cancelGeneration() async {
    if (!state.isLoading && !state.isStreaming) return;

    debugPrint("尝试取消聊天 $_chatId 的生成...");

    // 1. 通知服务层取消上游请求
    await _ref.read(llmServiceProvider).cancelActiveRequest();
    
    // 2. 取消本地的流订阅
    // 注意：在调用 cancel() 后，流的 onDone 可能会被触发，
    // onDone 中的状态清理逻辑会处理 isStreaming, isLoading 等。
    // 所以我们在这里不需要立即重置所有状态。
    await _llmStreamSubscription?.cancel();
    _llmStreamSubscription = null;
    debugPrint("本地 LLM 流订阅已取消。");

    // 3. 保存已接收到的部分内容
    String? contentToSave = state.streamingMessageContent;
    bool savedPartial = false;
    if (contentToSave != null && contentToSave.isNotEmpty) {
      debugPrint("检测到部分内容，尝试保存...");
      try {
        final chat = _ref.read(currentChatProvider(_chatId)).value;
        if (chat != null) {
          final partialMessage = Message.create(
            chatId: _chatId,
            role: MessageRole.model,
            rawText: contentToSave, // 保存可见的、已处理过的内容
          );
          final savedMessageId = await _ref.read(messageRepositoryProvider).saveMessage(partialMessage);
          final savedMessage = await _ref.read(messageRepositoryProvider).getMessageById(savedMessageId);
          debugPrint("部分内容已成功保存 (长度: ${contentToSave.length})。");
          savedPartial = true;
          if (savedMessage != null) {
            _runAsyncProcessingTasks(savedMessage);
          }
        } else {
          debugPrint("无法保存部分内容：聊天数据未加载。");
        }
      } catch (e) {
        debugPrint("保存部分内容时出错: $e");
      }
    }

    // 4. 更新UI状态以提供即时反馈
    if (mounted) {
      showTopMessage(savedPartial ? "已停止并保存部分内容" : "已停止生成",
                     backgroundColor: savedPartial ? Colors.orangeAccent : Colors.blueGrey);
      state = state.copyWith(
        isLoading: false,
        isStreaming: false,
        clearStreaming: true,
        clearGenerationStartTime: true,
        clearElapsedSeconds: true,
      );
      debugPrint("UI 状态已重置以反映取消操作。");
      _stopUpdateTimer();
    } else {
       debugPrint("取消时 Notifier 已销毁，无法更新状态。");
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

  @override
 void dispose() {
   _llmStreamSubscription?.cancel();
   _stopUpdateTimer();
   _topMessageTimer?.cancel(); // Dispose the top message timer
   super.dispose();
 }
}

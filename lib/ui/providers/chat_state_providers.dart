import 'dart:async'; // For StreamSubscription, Timer
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart'; // Added for Color type

import '../../data/models/chat.dart';
import '../../data/models/message.dart';
import '../../data/models/enums.dart';
import 'repository_providers.dart';
import '../../data/repositories/message_repository.dart';
import '../../service/llmapi/llm_service.dart'; // Import the generic LLM service and types
import '../../service/llmapi/llm_models.dart'; // Import the new generic LLM models
import '../../service/process/context_xml_service.dart'; // Import the new service
import 'package:collection/collection.dart'; // Import for lastWhereOrNull
import '../../service/process/xml_processor.dart'; // Added import
import 'settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 导入 SharedPreferences
import 'api_key_provider.dart';
import 'auth_providers.dart';
import '../screens/chat_settings_screen.dart' show defaultHelpMeReplyPrompt;
 
 
import '../../data/models/api_config.dart';


// 本文件包含与聊天数据和聊天界面状态相关的 Riverpod 提供者。
//
// 核心组件:
// 1.  `ChatStateNotifier`:
//     - 这是一个核心的 `StateNotifier`，负责管理单个聊天屏幕的所有业务逻辑和UI状态 (`ChatScreenState`)。
//     - 它处理用户的所有交互，包括发送消息、重新生成、续写、删除/编辑消息、分叉对话等。
//     - 它编排了与 `LlmService` 和 `ContextXmlService` 的交互，以构建上下文、发送API请求并处理响应。
//
// 2.  健壮的消息生成与 **原子化保存**:
//     - `sendMessage` 是所有消息生成的统一入口。
//     - **处理优于保存 (Process Before Save)**: 无论是流式 (`_finalizeStreamedMessage`) 还是非流式 (`_handleSingleResponse`) 响应，
//       都遵循“先在内存中完成所有处理，再进行一次性保存”的原则。
//     - 这意味着一个新消息的完整内容（包括流式文本、主XML、次要XML等）会在内存中被完全构建好，
//       形成一个最终的、不可变的 `Message` 对象。
//     - **原子化写入 (Atomic Write)**: 这个最终的 `Message` 对象随后被 **一次性** 写入数据库。这个设计从根本上避免了
//       因多次保存（例如，先保存初步文本，再保存后处理结果）而导致的数据流 (`StreamProvider`) 多次触发，
//       从而彻底解决了重复的UI更新和Token计算问题。
//
// 3.  保存后的后台任务:
//     - 在消息被原子化地保存到数据库 **之后**，`ChatStateNotifier` 才会启动一系列并行的后台任务 (`_runAsyncProcessingTasks`)。
//     - 这些任务只包含那些必须在消息已存在于数据库中才能进行的操作，例如自动生成标题 (`_executeAutoTitleGeneration`)
//       和上下文总结 (`_executePreprocessing`)。
//     - 任务有统一的取消机制 (`_isBackgroundTaskCancelled`)。
//
// 4.  健壮的上下文总结 (`_executePreprocessing`):
//     - **重构后的核心功能**。当需要进行上下文总结时（通常是因为历史记录过长），此方法会启动一个健壮的多阶段过程：
//     - **分块 (Chunking)**: 首先，它会利用 `ContextXmlService` 的截断逻辑，将需要总结的冗长历史消息安全地分割成多个符合上下文限制的“块”。
//     - **并行处理 (Parallel Execution)**: 接着，它会为每个“块”创建一个独立的总结任务。
//     - **带重试的总结 (Summarization with Retry)**: 每个任务都由 `_summarizeChunkWithRetry` 执行，该辅助方法在API调用失败时会自动重试最多3次。
//     - **结果聚合 (Aggregation)**: 最后，使用 `Future.wait` 并发执行所有任务，并将返回的所有总结文本拼接成一个新的、完整的上下文摘要，然后保存。
//     - 这个机制确保了即使在非常长的对话历史中，总结功能也能可靠、高效地完成，不会因超出单次API的上下文限制而失败。
//
// 5.  特殊操作 (`_executeSpecialAction`):
//     - 这是一个统一的辅助方法，用于处理所有需要“特殊”上下文的单次LLM调用，例如“帮我回复”、生成简历、生成标题等。
//     - 它的关键特性是，在构建上下文时，会将聊天本身配置的系统提示词“降级”为普通的用户消息，从而允许操作特定的指令（如“请为以下内容生成标题：...”）作为临时的、更高优先级的系统提示词。

// --- 当前激活的聊天 ID Provider ---
// 这个 Provider 允许我们拥有一个单一的 ChatScreen 实例，
// 该实例根据此状态更新其内容，而不是为每个聊天推送新的路由。
final activeChatIdProvider = StateProvider<int?>((ref) => null);

// --- 当前文件夹 ID Provider ---
final currentFolderIdProvider = StateProvider<int?>((ref) => null);

// --- 用于 chatListProvider 的参数 ---
// 使用 Record 类型来传递多个参数
typedef ChatListProviderParams = ({int? parentFolderId, ChatListMode mode});

// --- 聊天列表 Provider (Stream Family) ---
final chatListProvider =
    StreamProvider.family<List<Chat>, ChatListProviderParams>((ref, params) {
  try {
    final repo = ref.watch(chatRepositoryProvider);
    final authState = ref.watch(authProvider);

    debugPrint(
        "chatListProvider(folderId: ${params.parentFolderId}, mode: ${params.mode}, user: ${authState.currentUser?.username ?? 'Guest'}): 正在监听。");

    // 最终修复：不再区分游客和普通用户，统一调用 watchChatsForUser。
    // watchChatsForUser 方法内部已经包含了处理游客和“孤儿”聊天的逻辑。
    if (authState.currentUser == null) {
      // 如果在认证完成前（例如启动时），返回一个空流。
      return Stream.value([]);
    }

    final sourceStream = repo.watchChatsForUser(authState.currentUser!.id, params.parentFolderId);

    // 根据模式和时间戳过滤数据流
    return sourceStream.map((chats) {
      switch (params.mode) {
        case ChatListMode.normal:
          // 普通模式：只显示 updatedAt 不是模板时间戳的聊天
          return chats
              .where((chat) => chat.updatedAt.millisecondsSinceEpoch >= 1000)
              .toList();
        case ChatListMode.templateSelection:
        case ChatListMode.templateManagement:
          // 模板模式：只显示 updatedAt 是模板时间戳的聊天 (允许1秒误差)
          return chats
              .where((chat) => chat.updatedAt.millisecondsSinceEpoch < 1000)
              .toList();
      }
    });
  } catch (e) {
    debugPrint(
        "chatListProvider(folderId: ${params.parentFolderId}, mode: ${params.mode}) 错误: $e");
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

// --- 新增：第一条模型消息 Provider (用于列表预览) ---
// 优化：从 StreamProvider 改为 FutureProvider，避免为每个列表项建立实时监听。
// 这将显著降低应用启动时的数据库负载。
final firstModelMessageProvider = FutureProvider.family<Message?, int>((ref, chatId) {
  // 直接调用 repository 的一次性查询方法
  return ref.watch(messageRepositoryProvider).getFirstModelMessage(chatId);
});


// --- 聊天屏幕状态 ---
@immutable
class ChatScreenState {
  final bool isLoading; // Master lock for the entire process (send -> all background tasks done)
  final bool isPrimaryResponseLoading; // Lock for the direct user-facing response (stream/single)
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
  final List<List<String>>? helpMeReplySuggestions; // Changed to a list of lists for pagination
  final int helpMeReplyPageIndex; // To track the current page of suggestions
  final bool isProcessingInBackground; // New state for background tasks
  final bool isGeneratingSuggestions; // New state specifically for the "Help Me Reply" feature
  final bool isCancelled; // Flag to indicate if the current generation has been cancelled.
  final Message? streamingMessage; // Holds the message being streamed, for UI display only
  final bool isStreamingMessageVisible; // Controls the visibility of the streaming message in the UI

  const ChatScreenState({
    this.isLoading = false,
    this.isPrimaryResponseLoading = false,
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
    this.helpMeReplyPageIndex = 0,
    this.isProcessingInBackground = false, // Default to false
    this.isGeneratingSuggestions = false,
    this.isCancelled = false,
    this.streamingMessage,
    this.isStreamingMessageVisible = false,
  });

  ChatScreenState copyWith({
    bool? isLoading,
    bool? isPrimaryResponseLoading,
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
    List<List<String>>? helpMeReplySuggestions,
    bool clearHelpMeReplySuggestions = false,
    int? helpMeReplyPageIndex,
    bool? isProcessingInBackground,
    bool? isGeneratingSuggestions,
    bool? isCancelled,
    Message? streamingMessage,
    bool? isStreamingMessageVisible,
    bool clearStreamingMessage = false,
  }) {
    return ChatScreenState(
      isLoading: isLoading ?? this.isLoading,
      isPrimaryResponseLoading: isPrimaryResponseLoading ?? this.isPrimaryResponseLoading,
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
      helpMeReplyPageIndex: clearHelpMeReplySuggestions ? 0 : (helpMeReplyPageIndex ?? this.helpMeReplyPageIndex),
      isProcessingInBackground: isProcessingInBackground ?? this.isProcessingInBackground,
      isGeneratingSuggestions: isGeneratingSuggestions ?? this.isGeneratingSuggestions,
      isCancelled: isCancelled ?? this.isCancelled,
      streamingMessage: clearStreamingMessage ? null : streamingMessage ?? this.streamingMessage,
      isStreamingMessageVisible: clearStreamingMessage ? false : (isStreamingMessageVisible ?? this.isStreamingMessageVisible),
    );
  }
}

// --- 聊天屏幕状态 StateNotifierProvider ---
final chatStateNotifierProvider = StateNotifierProvider.family<ChatStateNotifier, ChatScreenState, int>(
  (ref, chatId) {
    // 异步获取 SharedPreferences 实例
    final prefsFuture = SharedPreferences.getInstance();
    // 创建 Notifier，并通过 FutureBuilder 在准备好后进行初始化
    final notifier = ChatStateNotifier(ref, chatId);
    prefsFuture.then((prefs) {
      if (notifier.mounted) {
        notifier.init(prefs);
      }
    });
    return notifier;
  },
);

// --- Constants ---
const int _kSuggestionsPerPage = 5;

// --- 聊天屏幕状态 StateNotifier ---
class ChatStateNotifier extends StateNotifier<ChatScreenState> {
  final Ref _ref;
  final int _chatId;
  StreamSubscription<LlmStreamChunk>? _llmStreamSubscription;
  Timer? _updateTimer;
  Timer? _topMessageTimer; // Timer for top messages
  bool _isFinalizing = false; // Flag to prevent reentry into _finalizeStreamedMessage

  late SharedPreferences _prefs;

  ChatStateNotifier(this._ref, this._chatId) : super(const ChatScreenState());

  /// 初始化 StateNotifier，从 SharedPreferences 加载持久化设置。
  void init(SharedPreferences prefs) {
    _prefs = prefs;
    state = state.copyWith(
      isStreamMode: _prefs.getBool('chat_${_chatId}_is_stream_mode') ?? true,
      isBubbleTransparent: _prefs.getBool('chat_${_chatId}_is_bubble_transparent') ?? false,
      isBubbleHalfWidth: _prefs.getBool('chat_${_chatId}_is_bubble_half_width') ?? false,
      isAutoHeightEnabled: _prefs.getBool('chat_${_chatId}_is_auto_height_enabled') ?? false,
    );
  }

  // --- API Config Resolution Logic ---
  /// 【公共方法】根据优先级解析出最终有效的 API 配置对象。
  ///
  /// 这个方法是健壮的，即使在 Chat 对象不存在或ID无效的情况下也能安全运行，
  /// 只要全局至少有一个API配置，它就总能返回一个有效的配置，从而防止下游出现空指针异常。
  ///
  /// 优先级顺序:
  /// 1. [specificConfigId] (针对特定操作的配置，如总结、XML生成等)
  /// 2. 当前聊天的主要配置 [chat.apiConfigId]
  /// 3. 全局 API 配置列表的第一个 (作为最终的默认值)
  ///
  /// @param specificConfigId 可选的、用于特定操作的配置ID。
  /// @return 返回一个有效的 ApiConfig 对象，如果全局没有任何配置则抛出异常。
  ApiConfig getEffectiveApiConfig({String? specificConfigId}) {
    final allConfigs = _ref.read(apiKeyNotifierProvider).apiConfigs;
    if (allConfigs.isEmpty) {
      // 这是关键的防御性编程：如果没有配置，任何API调用都无法进行，必须抛出异常。
      throw Exception("无法获取有效API配置：全局API配置列表为空。");
    }

    // 尝试获取当前聊天对象，但允许为空
    final chat = _ref.read(currentChatProvider(_chatId)).value;

    // 检查 specificConfigId 是否有效
    if (specificConfigId != null) {
      final config = allConfigs.firstWhereOrNull((c) => c.id == specificConfigId);
      if (config != null) return config;
    }
    
    // 检查聊天的主要 apiConfigId 是否有效
    if (chat?.apiConfigId != null) {
      final config = allConfigs.firstWhereOrNull((c) => c.id == chat!.apiConfigId);
      if (config != null) return config;
    }
    
    // 如果都无效或不存在，则回退到列表的第一个
    return allConfigs.first;
  }

  /// 【公共方法】根据优先级解析出最终有效的 API 配置 ID。
  ///
  /// 这是 `getEffectiveApiConfig` 的一个便利包装，仅返回ID。
  /// 如果没有有效的配置，则返回 null。
  String? getEffectiveApiConfigId({String? specificConfigId}) {
    try {
      return getEffectiveApiConfig(specificConfigId: specificConfigId).id;
    } catch (e) {
      return null;
    }
  }
 
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
    final newValue = !state.isStreamMode;
    state = state.copyWith(isStreamMode: newValue);
    _prefs.setBool('chat_${_chatId}_is_stream_mode', newValue);
    showTopMessage('输出模式已切换为: ${newValue ? "流式" : "一次性"}');
    debugPrint("Chat ($_chatId) 输出模式切换为: ${newValue ? "流式" : "一次性"}");
  }

  void toggleBubbleTransparency() {
    final newValue = !state.isBubbleTransparent;
    state = state.copyWith(isBubbleTransparent: newValue);
    _prefs.setBool('chat_${_chatId}_is_bubble_transparent', newValue);
    showTopMessage('气泡已切换为: ${newValue ? "半透明" : "不透明"}');
    debugPrint("Chat ($_chatId) 气泡透明度切换为: $newValue");
  }

  void toggleBubbleWidthMode() {
    final newValue = !state.isBubbleHalfWidth;
    state = state.copyWith(isBubbleHalfWidth: newValue);
    _prefs.setBool('chat_${_chatId}_is_bubble_half_width', newValue);
    showTopMessage('气泡宽度已切换为: ${newValue ? "半宽" : "全宽"}');
    debugPrint("Chat ($_chatId) 气泡宽度模式切换为: ${newValue ? "半宽" : "全宽"}");
  }

  void toggleMessageListHeightMode() {
    final newValue = !state.isAutoHeightEnabled;
    state = state.copyWith(
      isAutoHeightEnabled: newValue,
      isMessageListHalfHeight: newValue,
    );
    _prefs.setBool('chat_${_chatId}_is_auto_height_enabled', newValue);
    showTopMessage('智能半高模式已: ${newValue ? "开启" : "关闭"}');
    debugPrint("Chat ($_chatId) 智能半高模式切换为: $newValue");
  }

  void setMessageListHeightMode(bool isHalfHeight) {
    if (state.isMessageListHalfHeight == isHalfHeight) return; // 避免不必要的状态更新
    state = state.copyWith(isMessageListHalfHeight: isHalfHeight);
    debugPrint("Chat ($_chatId) 消息列表高度模式设置为: ${isHalfHeight ? "半高" : "全高"}");
  }

  // --- Token Counting ---
  Future<void> calculateAndStoreTokenCount() async {
    if (!mounted) return;

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
        chatId: _chatId,
        currentUserMessage: messages.last, // Base context on the latest message
      );
      
      // 现在直接从 ChatStateNotifier 获取配置，确保逻辑统一
      final apiConfig = getEffectiveApiConfig();
      final count = await llmService.countTokens(
        llmContext: apiRequestContext.contextParts,
        apiConfig: apiConfig, // 传递完整的配置对象
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
          clearHelpMeReplySuggestions(); // Clear suggestions as they might be based on the deleted message
          // calculateAndStoreTokenCount(); // Recalculate tokens - REMOVED: The listener in MessageList will handle this.

          // --- 优化后的摘要清除逻辑 ---
          final chatRepo = _ref.read(chatRepositoryProvider);
          final chat = await chatRepo.getChat(_chatId);
          if (chat != null && chat.contextSummary != null) {
            final contextXmlService = _ref.read(contextXmlServiceProvider);
            // 检查被删除的消息是否在“被截断”的范围内
            final tempContext = await contextXmlService.buildApiRequestContext(
              chatId: _chatId,
              currentUserMessage: Message(chatId: _chatId, role: MessageRole.user, parts: [MessagePart.text("check scope")])
            );
            final bool isMessageInSummarizedScope = tempContext.droppedMessages.any((m) => m.id == messageId);

            if (isMessageInSummarizedScope) {
              await chatRepo.saveChat(chat.copyWith({'contextSummary': null}));
              debugPrint("ChatStateNotifier($_chatId): 因被删除的消息在摘要范围内，已清除上下文摘要。");
            } else {
              debugPrint("ChatStateNotifier($_chatId): 被删除的消息不在摘要范围内，保留上下文摘要。");
            }
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
          messageToSave = message.copyWith({'parts': newParts});
        } else if (newText != null) {
          final updatedParts = message.parts.where((p) => p.type != MessagePartType.text).toList();
          updatedParts.insert(0, MessagePart.text(newText));
          messageToSave = message.copyWith({'parts': updatedParts});
        } else {
          return; // Nothing to update
        }
      }
      
      await messageRepo.saveMessage(messageToSave);

      if (mounted) {
        showTopMessage('消息已更新', backgroundColor: Colors.green, duration: const Duration(seconds: 2));
        clearHelpMeReplySuggestions(); // Clear suggestions as they might be based on the edited message
        // calculateAndStoreTokenCount(); // Recalculate tokens - REMOVED: The listener in MessageList will handle this.

        // --- 优化后的摘要清除逻辑 ---
        final chatRepo = _ref.read(chatRepositoryProvider);
        final chat = await chatRepo.getChat(_chatId);
        if (chat != null && chat.contextSummary != null) {
          final contextXmlService = _ref.read(contextXmlServiceProvider);
          // 检查被编辑的消息是否在“被截断”的范围内
          final tempContext = await contextXmlService.buildApiRequestContext(
            chatId: _chatId,
            currentUserMessage: Message(chatId: _chatId, role: MessageRole.user, parts: [MessagePart.text("check scope")])
          );
          final bool isMessageInSummarizedScope = tempContext.droppedMessages.any((m) => m.id == messageId);

          if (isMessageInSummarizedScope) {
            await chatRepo.saveChat(chat.copyWith({'contextSummary': null}));
            debugPrint("ChatStateNotifier($_chatId): 因被编辑的消息在摘要范围内，已清除上下文摘要。");
          } else {
            debugPrint("ChatStateNotifier($_chatId): 被编辑的消息不在摘要范围内，保留上下文摘要。");
          }
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

      final now = DateTime.now();
      final newChat = Chat(
        title: newTitle,
        parentFolderId: originalChat.parentFolderId,
        systemPrompt: originalChat.systemPrompt,
        coverImageBase64: originalChat.coverImageBase64,
        backgroundImagePath: originalChat.backgroundImagePath,
        apiConfigId: originalChat.apiConfigId,
        contextConfig: originalChat.contextConfig.copyWith(),
        xmlRules: List.from(originalChat.xmlRules),
        enablePreprocessing: originalChat.enablePreprocessing,
        preprocessingPrompt: originalChat.preprocessingPrompt,
        preprocessingApiConfigId: originalChat.preprocessingApiConfigId,
        contextSummary: null, // Forked chat starts fresh
        enableSecondaryXml: originalChat.enableSecondaryXml,
        secondaryXmlPrompt: originalChat.secondaryXmlPrompt,
        secondaryXmlApiConfigId: originalChat.secondaryXmlApiConfigId,
        continuePrompt: originalChat.continuePrompt,
        createdAt: now,
        updatedAt: now,
      );
      
      final newChatId = await chatRepo.saveChat(newChat);

      // 2. 复制消息
      final List<Message> newMessages = messagesToKeep.map((originalMsg) {
        return Message(
          chatId: newChatId,
          parts: originalMsg.parts, // Keep original parts
          role: originalMsg.role,
          timestamp: originalMsg.timestamp,
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
    clearHelpMeReplySuggestions(); // Clear suggestions before regenerating
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
    String? promptOverride,
    int? messageToUpdateId,
    String? apiConfigIdOverride,
  }) async {
    if (state.isLoading && !isRegeneration && !isContinuation) {
      debugPrint("sendMessage ($_chatId) 取消：已在加载中。");
      return;
    }
    
    // Reset the cancellation state for this new request.
    if (state.isCancelled) {
      state = state.copyWith(isCancelled: false);
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
        messagesToSave.add(Message(
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
        isLoading: true, // Master lock ON
        isPrimaryResponseLoading: true, // Primary response lock ON
        isCancelled: false, // Ensure cancellation is reset when starting
        clearError: true,
        clearTopMessage: true,
        clearStreaming: true,
        clearHelpMeReplySuggestions: true,
        clearStreamingMessage: true, // Clear any previous leftovers
        generationStartTime: DateTime.now(),
        elapsedSeconds: 0);
    _startUpdateTimer();
    
    // --- Save new user messages (if not regenerating or continuing) ---
    if (!isRegeneration && !isContinuation) {
      try {
        final messageRepo = _ref.read(messageRepositoryProvider);
        await messageRepo.saveMessages(messagesToSave); // Batch save
        final chatRepo = _ref.read(chatRepositoryProvider);
        await chatRepo.saveChat(chat.copyWith({'updatedAt': DateTime.now()}));
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
      
      String? lastMessageOverride;

      if (promptOverride != null) {
        lastMessageOverride = promptOverride;
        debugPrint("sendMessage: 使用了 promptOverride。");
      } else if (isContinuation && (chat.continuePrompt?.isNotEmpty ?? false)) {
        lastMessageOverride = chat.continuePrompt;
        // For continuation, we keep the original system prompt.
        // The line clearing it has been removed.
        debugPrint("续写操作：将续写提示词作为最后的用户消息。");
      }

      final apiRequestContext = await contextXmlService.buildApiRequestContext(
        chatId: _chatId,
        currentUserMessage: messageForContext, // Pass the representative message for context
        lastMessageOverride: lastMessageOverride,
        // For standard chat, regeneration, and continuation, always keep the original system prompt.
        keepAsSystemPrompt: true,
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

     // 重构：LlmService 不再处理配置逻辑，由 Notifier 决定
    final apiConfig = getEffectiveApiConfig(specificConfigId: apiConfigIdOverride);
    
    if (state.isStreamMode) {
        await _handleStreamResponse(llmService, apiConfig, llmApiContext, messageToUpdateId: messageToUpdateId);
    } else {
        await _handleSingleResponse(llmService, apiConfig, llmApiContext, carriedOverXmlForThisTurn, messageToUpdateId: messageToUpdateId);
    }
   }

 // --- Post-Generation Processing ---
 Future<void> _runAsyncProcessingTasks(Message modelMessage) async {
   if (!mounted) return;
   final chat = _ref.read(currentChatProvider(_chatId)).value;
   if (chat == null) return;

   if (!mounted || state.isCancelled) return; // Critical cancellation check

   // 1. Set background processing state
   if (mounted) {
     state = state.copyWith(isProcessingInBackground: true);
   }

   List<Future> tasks = [];

   // 2. Gather all tasks that must run *after* the message is saved.
   tasks.add(_executeAutoTitleGeneration(chat, modelMessage));
   // _executePostGenerationProcessing is now done *before* saving, so it's removed from here.
   if (chat.enablePreprocessing && (chat.preprocessingPrompt?.isNotEmpty ?? false)) {
     tasks.add(_executePreprocessing(chat));
   }
   if (chat.enableHelpMeReply && chat.helpMeReplyTriggerMode == HelpMeReplyTriggerMode.auto) {
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
       if (!state.isCancelled) { // Only show error if not cancelled by user
         debugPrint("ChatStateNotifier($_chatId): Error during async processing tasks: $e");
         if (mounted) {
           showTopMessage("后台处理任务出错: $e", backgroundColor: Colors.red.withAlpha(204));
         }
       }
     } finally {
       if (mounted) {
         // Clear all processing states together, including the master isLoading flag.
         state = state.copyWith(
           isLoading: false, // Master lock OFF
           isPrimaryResponseLoading: false, // Ensure this is also off
           isProcessingInBackground: false,
           clearGenerationStartTime: true,
           clearElapsedSeconds: true,
           clearStreamingMessage: true,
         );
         _stopUpdateTimer();
         debugPrint("ChatStateNotifier($_chatId): All processing finished. isLoading is now false.");
       }
     }
   } else {
     // If there are no tasks, ensure all loading states are cleared immediately.
     if (mounted) {
       state = state.copyWith(
         isLoading: false, // Master lock OFF
         isPrimaryResponseLoading: false, // Ensure this is also off
         isProcessingInBackground: false,
         clearGenerationStartTime: true,
         clearElapsedSeconds: true,
         clearStreamingMessage: true,
       );
       _stopUpdateTimer();
     }
   }
 }

 // This function is now obsolete. Its logic has been integrated directly into
 // _finalizeStreamedMessage and _handleSingleResponse before the message is saved.

 /// Executes the new, robust summarization process for dropped messages.
 /// Implements a robust, "intelligent merge" incremental summarization algorithm.
 Future<void> _executePreprocessing(Chat chat) async {
   if (state.isCancelled) return;
   debugPrint("ChatStateNotifier($_chatId): Executing intelligent merge summarization...");

   final contextXmlService = _ref.read(contextXmlServiceProvider);
   final chatRepo = _ref.read(chatRepositoryProvider);
   final messageRepo = _ref.read(messageRepositoryProvider);

   // 1. Get the complete, current message history.
   final allMessages = await messageRepo.getMessagesForChat(_chatId);
   if (allMessages.length < 2) {
     debugPrint("ChatStateNotifier($_chatId): Not enough messages for context diff, skipping.");
     return;
   }

   // 2. Simulate context "AFTER" the latest turn to find all currently dropped messages.
   final contextAfter = await contextXmlService.buildApiRequestContext(
     chatId: _chatId,
     currentUserMessage: Message(chatId: _chatId, role: MessageRole.user, parts: [MessagePart.text("after")]),
   );
   final droppedMessagesAfter = contextAfter.droppedMessages;

   // If nothing is dropped now, there's nothing to do.
   if (droppedMessagesAfter.isEmpty) {
     debugPrint("ChatStateNotifier($_chatId): No messages are dropped. Clearing summary if it exists.");
     if (chat.contextSummary != null) {
       await chatRepo.saveChat(chat.copyWith({'contextSummary': null}));
     }
     return;
   }

   // 3. Simulate context "BEFORE" the latest turn.
   final historyBefore = allMessages.sublist(0, allMessages.length - 2);
   final contextBefore = await contextXmlService.buildApiRequestContext(
     chatId: _chatId,
     currentUserMessage: Message(chatId: _chatId, role: MessageRole.user, parts: [MessagePart.text("before")]),
     historyOverride: historyBefore,
   );
   final droppedMessagesBefore = contextBefore.droppedMessages;

   // 4. Determine the messages to summarize based on whether a summary already exists.
   final List<Message> messagesToSummarize;

   if (chat.contextSummary == null || chat.contextSummary!.isEmpty) {
     // SCENARIO A: No existing summary. We must summarize ALL currently dropped messages
     // to build the summary from scratch.
     messagesToSummarize = droppedMessagesAfter;
     debugPrint("ChatStateNotifier($_chatId): No existing summary. Summarizing all ${messagesToSummarize.length} dropped messages.");
   } else {
     // SCENARIO B: Existing summary found. We only need to summarize the "diff" -
     // the messages that were newly dropped in this turn.
     final droppedIdsBefore = droppedMessagesBefore.map((m) => m.id).toSet();
     messagesToSummarize = droppedMessagesAfter
         .where((msg) => !droppedIdsBefore.contains(msg.id))
         .toList();
     debugPrint("ChatStateNotifier($_chatId): Existing summary found. Summarizing diff of ${messagesToSummarize.length} messages.");
   }

   if (messagesToSummarize.isEmpty) {
     debugPrint("ChatStateNotifier($_chatId): Context diff is empty. No new messages to summarize.");
     return; // Nothing new was dropped, so the existing summary is still valid.
   }

   debugPrint("ChatStateNotifier($_chatId): Found ${messagesToSummarize.length} new messages to summarize.");
   if (state.isCancelled) return;

   // 5. Chunking & Summarization
   // The logic now takes the existing summary and merges it with the new "diff".
   final List<List<Message>> chunks = [];
   List<Message> remainingToChunk = List.from(messagesToSummarize);

   while (remainingToChunk.isNotEmpty) {
     if (state.isCancelled) return;
     final chunkingContext = await contextXmlService.buildApiRequestContext(
         chatId: _chatId,
         currentUserMessage: Message(chatId: _chatId, role: MessageRole.user, parts: [MessagePart.text("chunking")]),
         historyOverride: remainingToChunk,
         chatSystemPromptOverride: chat.preprocessingPrompt);
     
     final List<Message> droppedInThisChunk = chunkingContext.droppedMessages;
     final Set<int> droppedIds = droppedInThisChunk.map((m) => m.id).toSet();
     final List<Message> currentChunk = remainingToChunk.where((m) => !droppedIds.contains(m.id)).toList();

     if (currentChunk.isEmpty) {
       debugPrint("Warning: Chunking produced an empty chunk. Discarding remaining ${remainingToChunk.length} messages.");
       break;
     }
     chunks.add(currentChunk);
     remainingToChunk = droppedInThisChunk;
   }

   if (chunks.isEmpty) {
     debugPrint("ChatStateNotifier($_chatId): Chunking of diff resulted in no chunks to process.");
     return;
   }

   // 6. Parallel Intelligent Merge Execution
   // **CRITICAL FIX**: Reverse the chunks so they are processed from OLDEST to NEWEST.
   // This ensures the existing summary is merged with the oldest part of the new diff.
   final reversedChunks = chunks.reversed.toList();
   final existingSummary = chat.contextSummary;
   final List<Future<String>> summaryFutures = [];

   for (int i = 0; i < reversedChunks.length; i++) {
     final chunk = reversedChunks[i];
     // The very first chunk (which is now the OLDEST part of the history)
     // gets the existing summary to perform the intelligent merge.
     final summaryForThisChunk = (i == 0) ? existingSummary : null;
     summaryFutures.add(_summarizeChunkWithRetry(chat, chunk, summaryForThisChunk));
   }

   final summaryResults = await Future.wait(summaryFutures);
   if (state.isCancelled) return;

   // 7. Aggregation & Full Replacement
   // The result from the first future is the new, fully-merged summary.
   // Subsequent results are summaries of any further chunks, which we join.
   final finalSummary = summaryResults.where((s) => s.isNotEmpty).join('\n\n---\n\n');

   if (finalSummary.isNotEmpty) {
     // We are performing a full replacement of the old summary with the new one.
     await chatRepo.saveChat(chat.copyWith({'contextSummary': finalSummary}));
     debugPrint("ChatStateNotifier($_chatId): Intelligent merge summarization successful. New summary saved.");
   } else {
     debugPrint("ChatStateNotifier($_chatId): Summarization resulted in an empty summary. Nothing to save.");
     throw Exception("Summarization failed: All chunks resulted in empty content.");
   }
 }

 /// A robust helper to summarize a single chunk of messages with a retry mechanism.
 Future<String> _summarizeChunkWithRetry(Chat chat, List<Message> chunk, String? previousSummary) async {
   const maxRetries = 3;
   final llmService = _ref.read(llmServiceProvider);
   final summaryPrompt = chat.preprocessingPrompt!;

   for (int attempt = 1; attempt <= maxRetries; attempt++) {
     if (state.isCancelled) return ""; // Check for cancellation before each attempt

     try {
       // Manually construct the context for this specific chunk.
       List<LlmContent> summaryContext = [
         LlmContent("system", [LlmTextPart(summaryPrompt)])
       ];

       // If a previous summary is provided (only for the first chunk), add it.
       if (previousSummary != null && previousSummary.isNotEmpty) {
         final previousSummaryText = XmlProcessor.wrapWithTag('previous_summary', previousSummary);
         summaryContext.add(LlmContent("user", [LlmTextPart(previousSummaryText)]));
       }

       // Add each message from the chunk.
       for (final message in chunk) {
         summaryContext.add(LlmContent.fromMessage(message));
       }

       // Add the guiding prompt at the end.
       summaryContext.add(LlmContent("user", [LlmTextPart(summaryPrompt)]));

       // 重构：直接获取配置对象
       final apiConfig = getEffectiveApiConfig(specificConfigId: chat.preprocessingApiConfigId);
       final response = await llmService.sendMessageOnce(
         llmContext: summaryContext,
         apiConfig: apiConfig,
       );

        if (response.isSuccess && response.parts.isNotEmpty) {
         final summaryText = response.parts.map((p) => p.text ?? "").join("\n").trim();
         debugPrint("ChatStateNotifier($_chatId): Chunk summarization successful on attempt $attempt.");
         return summaryText; // Success
       } else {
         throw Exception("API Error: ${response.error ?? 'Empty response'}");
       }
     } catch (e) {
       debugPrint("ChatStateNotifier($_chatId): Chunk summarization attempt $attempt/$maxRetries failed: $e");
       if (attempt == maxRetries || state.isCancelled) {
         // If it's the last attempt or cancelled, rethrow to fail the Future.
         // The Future.wait will catch this, but we'll return an empty string
         // so that a single failed chunk doesn't stop the entire process.
         return "";
       }
       // Wait before retrying
       await Future.delayed(Duration(seconds: attempt * 2));
     }
   }
   return ""; // Should be unreachable, but ensures a return value
 }

 // --- State variables for streaming XML processing ---
 final StringBuffer _rawAccumulatedBuffer = StringBuffer();
  final StringBuffer _displayableTextBuffer = StringBuffer();
  // StringBuffer _currentXmlSegmentForDisplay = StringBuffer(); // Not strictly needed if we just suppress
  final Set<String> _processedRuleTagNamesThisTurn = {};
  // --- End of state variables for streaming XML processing ---

  Future<void> _handleStreamResponse(LlmService llmService, ApiConfig apiConfig, List<LlmContent> llmContext, {int? messageToUpdateId}) async {
     final messageRepo = _ref.read(messageRepositoryProvider);
    int targetMessageId; // Will be a temporary negative ID or a real one for resume
    Message baseMessage;
    String initialRawText = '';

    if (messageToUpdateId != null) {
      // This is a resume/continue action for an existing message.
      targetMessageId = messageToUpdateId;
      final msg = await messageRepo.getMessageById(targetMessageId);
      if (msg == null) {
        showTopMessage('无法恢复消息：未找到原始消息', backgroundColor: Colors.red);
        state = state.copyWith(isLoading: false, clearGenerationStartTime: true, clearElapsedSeconds: true);
        _stopUpdateTimer();
        return;
      }
      baseMessage = msg;
      // 恢复时，将原始文本和XML内容结合起来，以确保新内容正确追加。
      final StringBuffer combinedBuffer = StringBuffer(baseMessage.rawText);
      if (baseMessage.originalXmlContent != null && baseMessage.originalXmlContent!.isNotEmpty) {
        combinedBuffer.write(baseMessage.originalXmlContent);
      }
      initialRawText = combinedBuffer.toString();
    } else {
      // This is a new message. Do not save to DB. Create a temporary in-memory message.
      // Use a unique negative ID for the key to avoid conflicts with real DB IDs.
      targetMessageId = -DateTime.now().millisecondsSinceEpoch;
      baseMessage = Message(
        id: targetMessageId, // Assign temporary negative ID
        chatId: _chatId,
        role: MessageRole.model,
        parts: [MessagePart.text("...")], // Start with a placeholder text
      );
      debugPrint("ChatStateNotifier($_chatId): Created temporary streaming message with ID: $targetMessageId.");
    }
 
     // Initialize stream-specific state
     _rawAccumulatedBuffer.clear();
     _displayableTextBuffer.clear();
     _processedRuleTagNamesThisTurn.clear();

    // The streaming message is now stored in the state, not the DB.
    // Create the initial placeholder message in the state.
    state = state.copyWith(
      streamingMessage: baseMessage,
      isStreamingMessageVisible: true,
      isStreaming: true,
    );
 
     final stream = llmService.sendMessageStream(llmContext: llmContext, apiConfig: apiConfig);
     _llmStreamSubscription?.cancel();
     _llmStreamSubscription = stream.listen(
       (chunk) async {
         if (!mounted) return;
 
         if (chunk.error != null) {
           showTopMessage('消息流错误: ${chunk.error}', backgroundColor: Colors.red);
           // On error, we still finalize to save what we have and clean up.
           _llmStreamSubscription?.cancel();
           await _finalizeStreamedMessage(targetMessageId, hasError: true);
           return;
         }
 
         if (chunk.isFinished) {
           // This chunk signals the end, but onDone is the sole handler for finalization.
           return;
         }
 
        // --- Live Update Logic (State only) ---
        final accumulatedNewText = chunk.accumulatedText;
        final combinedRawText = initialRawText + accumulatedNewText;
        
        // Update the message object in the state, not the database.
        final messageToUpdate = (state.streamingMessage ?? baseMessage).copyWith({
          'id': targetMessageId,
          'parts': [MessagePart.text(combinedRawText)]
        });

        if (mounted) {
          state = state.copyWith(streamingMessage: messageToUpdate);
        }
       },
       onError: (error) {
         if (mounted) {
           showTopMessage('消息流错误: $error', backgroundColor: Colors.red);
         }
          if (!_isFinalizing) {
            _finalizeStreamedMessage(targetMessageId, hasError: true);
          }
       },
       onDone: () async {
         // onDone is the single source of truth for saving a completed or canceled stream.
         if (!_isFinalizing) {
           await _finalizeStreamedMessage(targetMessageId);
         }
       },
       cancelOnError: true,
     );
  }
 
  Future<void> _handleSingleResponse(LlmService llmService, ApiConfig apiConfig, List<LlmContent> llmContext, String? initialCarriedOverXml, {int? messageToUpdateId}) async {
    try {
      final response = await llmService.sendMessageOnce(llmContext: llmContext, apiConfig: apiConfig);
      if (!mounted) return;
 
      if (state.isCancelled) return; // Check for cancellation after response
      if (response.isSuccess && response.parts.isNotEmpty) {
       state = state.copyWith(clearStreamingMessage: true); // Ensure no streaming leftovers
        final messageRepo = _ref.read(messageRepositoryProvider);
        final String newContent = response.parts.map((p) => p.text ?? "").join("\n");
        
        Message messageToProcess;

        if (messageToUpdateId != null) {
          final baseMessage = await messageRepo.getMessageById(messageToUpdateId);
          if (baseMessage == null) {
            showTopMessage('无法恢复消息：未找到原始消息', backgroundColor: Colors.red);
            state = state.copyWith(isLoading: false, clearGenerationStartTime: true, clearElapsedSeconds: true);
            _stopUpdateTimer();
            return;
          }
          // 恢复时，将原始文本和XML内容结合起来，以确保新内容正确追加。
          final StringBuffer combinedBuffer = StringBuffer(baseMessage.rawText);
          if (baseMessage.originalXmlContent != null && baseMessage.originalXmlContent!.isNotEmpty) {
            combinedBuffer.write(baseMessage.originalXmlContent);
          }
          final initialRawText = combinedBuffer.toString();
          final combinedRawText = initialRawText + newContent;
          // 我们将完整的合并文本暂时放入parts中，后续处理会分离它们
          messageToProcess = baseMessage.copyWith({'parts': [MessagePart.text(combinedRawText)]});
        } else {
          messageToProcess = Message(
            chatId: _chatId,
            role: MessageRole.model,
            parts: response.parts,
          );
        }
 
        // 2. Process the message in-memory *before* saving.
        final chat = _ref.read(currentChatProvider(_chatId)).value;
        if (chat == null) {
          showTopMessage('无法处理消息：聊天数据丢失', backgroundColor: Colors.red);
          return;
        }
        final processedMessage = await _getFinalProcessedMessage(chat, messageToProcess);
        if (state.isCancelled) return; // Check after processing

        // 3. Save the fully processed message to the database ONCE.
        final savedMessageId = await messageRepo.saveMessage(processedMessage);
        final savedMessage = await messageRepo.getMessageById(savedMessageId);
        
        // 4. The primary response is "done". Turn off its specific lock.
        //    Keep the master `isLoading` lock on for background tasks.
        state = state.copyWith(
          isPrimaryResponseLoading: false,
          clearError: true,
          clearTopMessage: true,
        );

        // 5. Asynchronously run post-save tasks on the saved message.
        if (savedMessage != null) {
          if (state.isCancelled) return; // Final check before starting background tasks
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
       // calculateAndStoreTokenCount(); // Recalculate tokens based on initial saved message. - REMOVED: The listener in MessageList will handle this.
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
   final originalRawText = initialMessage.rawText;
   final displayText = XmlProcessor.stripXmlContent(originalRawText);
   final initialXml = XmlProcessor.extractXmlContent(originalRawText);

   String? newSecondaryXmlContent;

   if (chat.enableSecondaryXml && (chat.secondaryXmlPrompt?.isNotEmpty ?? false)) {
     try {
       if (state.isCancelled) return initialMessage; // Early exit
       // 重构：直接获取配置对象
       final apiConfig = getEffectiveApiConfig(specificConfigId: chat.secondaryXmlApiConfigId);
       final generatedText = await _executeSpecialAction(
         prompt: chat.secondaryXmlPrompt!,
         apiConfig: apiConfig,
         actionType: _SpecialActionType.secondaryXml,
         targetMessage: initialMessage,
       );
       debugPrint("ChatStateNotifier($_chatId): ========== Secondary XML Raw Content START ==========");
       debugPrint(generatedText);
       debugPrint("ChatStateNotifier($_chatId): ========== Secondary XML Raw Content END ==========");
       newSecondaryXmlContent = generatedText;
     } catch (e) {
       // If it fails, we log it but don't stop the whole finalization process.
       // The error is already logged inside _executeSpecialAction.
       // We rethrow to let the caller (_runAsyncProcessingTasks) know something failed.
       debugPrint("ChatStateNotifier($_chatId): Secondary XML generation failed and will not be included.");
       rethrow;
     }
   }

   final newParts = [MessagePart.text(displayText)];

   // Return a new message object with all final values, ready to be saved.
   return initialMessage.copyWith({
     'parts': newParts,
     'originalXmlContent': initialXml,
     'secondaryXmlContent': newSecondaryXmlContent,
   });
 }

  Future<void> cancelGeneration() async {
    // If nothing is running, or it's already cancelled, do nothing.
    if ((!state.isLoading && !state.isStreaming && !state.isProcessingInBackground && !state.isGeneratingSuggestions) || state.isCancelled) {
      debugPrint("Cancel generation skipped: isLoading=${state.isLoading}, isStreaming=${state.isStreaming}, isProcessingInBackground=${state.isProcessingInBackground}, isGeneratingSuggestions=${state.isGeneratingSuggestions}, isCancelled=${state.isCancelled}");
      return;
    }

    debugPrint("Attempting to cancel generation for chat $_chatId...");

    try {
      // 1. Set the cancellation flag in the state. This is the new source of truth.
      if (mounted) {
        state = state.copyWith(isCancelled: true);
      }

      // 2. Cancel any active LLM request (covers main stream and background tasks)
      await _ref.read(llmServiceProvider).cancelActiveRequest();

      // 3. Cancel the stream subscription if it exists.
      // This will trigger its onDone/onError, which will see the isCancelled flag and stop.
      if (_llmStreamSubscription != null) {
        await _llmStreamSubscription?.cancel();
        _llmStreamSubscription = null;
      }

      // 4. Finalize state immediately for instant UI feedback.
      // The async tasks will check the `isCancelled` state flag and stop themselves.
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          isStreaming: false,
          isProcessingInBackground: false,
          isGeneratingSuggestions: false, // Also clear this flag
          clearStreaming: true,
          clearGenerationStartTime: true,
          clearElapsedSeconds: true,
          clearStreamingMessage: true, // Also clear the cached message
        );
        _stopUpdateTimer();
        showTopMessage("已停止", backgroundColor: Colors.blueGrey);
      }
    } catch (e) {
      debugPrint("Error during cancelGeneration: $e");
      if (mounted) {
        showTopMessage("取消操作时出错: $e", backgroundColor: Colors.red);
      }
    } finally {
      debugPrint("Cancellation process finished for chat $_chatId.");
    }
  }

  Future<void> _finalizeStreamedMessage(int messageId, {bool hasError = false}) async {
    if (!mounted || _isFinalizing) return;
    
    // CRITICAL: If cancellation was requested, stop all finalization and post-processing.
    if (state.isCancelled) {
      _isFinalizing = false; // Release lock
      debugPrint("Finalization skipped for message ID $messageId because task was cancelled.");
      return;
    }

    _isFinalizing = true;
    debugPrint("Finalizing stream for message ID $messageId... Has Error: $hasError");

    final messageRepo = _ref.read(messageRepositoryProvider);
    final messageToFinalize = state.streamingMessage;
    bool wasRunning = state.isLoading || state.isStreaming;
 
    if (hasError && (messageToFinalize == null || messageToFinalize.rawText.trim().isEmpty || messageToFinalize.rawText == "...")) {
      debugPrint("Stream ended in error with no content. Clearing temporary message.");
      if (mounted) {
        state = state.copyWith(
          isLoading: false, isStreaming: false, clearStreaming: true,
          clearGenerationStartTime: true, clearElapsedSeconds: true,
          clearStreamingMessage: true,
        );
        _stopUpdateTimer();
      }
      _isFinalizing = false;
      return;
    }

    if (messageToFinalize == null) {
      debugPrint("Finalization skipped: No message found in state.");
      _isFinalizing = false;
      return;
    }

    // 1. Create a new message object for saving, stripping the temporary ID.
    // This happens only on successful completion.
    Message? finalMessageToSave;
    if (!hasError) {
      if (messageToFinalize.id > 0) {
        // This is an update to an existing message.
        finalMessageToSave = messageToFinalize;
      } else {
        // This is a new message. Create a new object without the temporary negative ID.
        finalMessageToSave = Message(
          chatId: messageToFinalize.chatId,
          role: messageToFinalize.role,
          parts: messageToFinalize.parts,
          timestamp: messageToFinalize.timestamp,
        );
      }
    }

    // 2. The primary response (stream) is "done". Turn off its specific lock.
    //    Keep the master `isLoading` lock on for background tasks.
    if (mounted) {
      state = state.copyWith(
        isPrimaryResponseLoading: false,
        isStreaming: false,
        clearStreaming: true,
        // CRITICAL: Do NOT clear isLoading or the streaming message here.
      );
    }

    // 3. Now, with the main state cleared, run async pre-save and post-save processing.
    try {
      final chat = _ref.read(currentChatProvider(_chatId)).value;
      if (chat != null && finalMessageToSave != null) {
        // 3a. Process the message in-memory BEFORE saving.
        final processedMessage = await _getFinalProcessedMessage(chat, finalMessageToSave);
        if (state.isCancelled) {
          _isFinalizing = false;
          return;
        }

        // 3b. Save the fully processed message to the database ONCE.
        final savedId = await messageRepo.saveMessage(processedMessage);
        final savedMessage = await messageRepo.getMessageById(savedId);
        
        // 3c. Run post-save async tasks.
        if (savedMessage != null) {
          // CRITICAL: Update the state's streamingMessage with the one from the DB.
          // This "promotes" the temporary message to a persistent one with a real ID,
          // ensuring a seamless transition in the UI.
          if (mounted) {
            state = state.copyWith(streamingMessage: savedMessage);
          }

          debugPrint("Running async post-save processing for newly saved message ID $savedId...");
          if (!state.isCancelled) {
            await _runAsyncProcessingTasks(savedMessage);
            debugPrint("Async post-save processing for message ID $savedId finished.");
            if (mounted && !state.isCancelled) {
              showTopMessage("已完成", backgroundColor: Colors.green);
            }
          } else {
            debugPrint("Async post-save processing for message ID $savedId skipped due to cancellation.");
          }
        }
      } else if (wasRunning) {
        debugPrint("Skipping async processing: chat or message not available.");
        if (mounted) {
          showTopMessage("已停止", backgroundColor: Colors.blueGrey);
        }
      }
    } catch (e) {
      debugPrint("Error during finalization's post-processing: $e");
      if (mounted) {
        showTopMessage('后台处理任务出错: $e', backgroundColor: Colors.red);
      }
    } finally {
      _isFinalizing = false;
      debugPrint("Finalization process finished. _isFinalizing reset to false.");
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
  if (state.isCancelled) return;
  await Future.delayed(const Duration(milliseconds: 200));
  if (!mounted || state.isCancelled) return;

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
     if (state.isCancelled) return;
     final apiConfig = getEffectiveApiConfig(specificConfigId: globalSettings.titleGenerationApiConfigId);
     final generatedText = await _executeSpecialAction(
       prompt: globalSettings.titleGenerationPrompt,
       apiConfig: apiConfig,
       actionType: _SpecialActionType.autoTitle,
       targetMessage: currentModelMessage,
     );
     final newTitle = generatedText.trim().replaceAll(RegExp(r'["\n]'), '');
     if (newTitle.isNotEmpty) {
       final chatRepo = _ref.read(chatRepositoryProvider);
       final currentChat = await chatRepo.getChat(_chatId);
       if (currentChat != null && mounted && !state.isCancelled) {
         await chatRepo.saveChat(currentChat.copyWith({'title': newTitle}));
         debugPrint("ChatStateNotifier($_chatId): Auto title generation successful. New title: $newTitle");
       }
     } else {
       debugPrint("ChatStateNotifier($_chatId): Auto title generation resulted in an empty title. Skipping update.");
     }
   } catch (e) {
     if (!state.isCancelled) {
       debugPrint("ChatStateNotifier($_chatId): Error during auto title generation after retries: $e");
       // We rethrow the error so Future.wait in _runAsyncProcessingTasks can catch it
       // and show a generic background error message.
       rethrow;
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

    await sendMessage(
      isContinuation: true,
      promptOverride: globalSettings.resumePrompt,
      messageToUpdateId: lastMessage.id,
      // resumeGeneration 现在也遵循统一的配置获取逻辑
      apiConfigIdOverride: getEffectiveApiConfigId(
        specificConfigId: globalSettings.resumeApiConfigId,
      ),
    );
  }

  Future<void> generateHelpMeReply({Function(List<String>)? onSuggestionsReady, bool forceRefresh = false}) async {

    if (!mounted) return;
    state = state.copyWith(isCancelled: false, isGeneratingSuggestions: true);

    try {
      final bool hasExistingSuggestions = state.helpMeReplySuggestions != null && state.helpMeReplySuggestions!.isNotEmpty;

      // 3. Handle cache case
      if (!forceRefresh && hasExistingSuggestions) {
        debugPrint("ChatStateNotifier($_chatId): Using cached 'Help Me Reply' suggestions.");
        if (onSuggestionsReady != null) {
          final currentPage = state.helpMeReplySuggestions![state.helpMeReplyPageIndex];
          onSuggestionsReady(currentPage);
        }
        return; // Early exit, finally block will clean up state
      }

      // 4. Perform checks
      final lastMessage = _ref.read(lastModelMessageProvider(_chatId));
      if (lastMessage == null) {
        if (onSuggestionsReady != null) showTopMessage('没有可供回复的消息', backgroundColor: Colors.orange);
        return;
      }

     final chat = _ref.read(currentChatProvider(_chatId)).value;
     if (chat == null) {
       if (onSuggestionsReady != null) showTopMessage('无法获取聊天设置', backgroundColor: Colors.red);
       return;
     }
     if (!chat.enableHelpMeReply) {
       if (onSuggestionsReady != null) showTopMessage('“帮我回复”功能在此聊天中已禁用', backgroundColor: Colors.orange);
       return;
     }

     // 5. Execute the action
     try {
       final apiConfig = getEffectiveApiConfig(specificConfigId: chat.helpMeReplyApiConfigId);
       final generatedText = await _executeSpecialAction(
         prompt: chat.helpMeReplyPrompt ?? defaultHelpMeReplyPrompt,
         apiConfig: apiConfig,
         actionType: _SpecialActionType.helpMeReply,
          targetMessage: lastMessage,
        );

        final newSuggestions = RegExp(r'^\s*\d+\.\s*(.*)', multiLine: true)
            .allMatches(generatedText)
            .map((m) => m.group(1)!.trim())
            .toList();
        final finalSuggestions = newSuggestions.isNotEmpty ? newSuggestions : [generatedText.trim()];
        
        if (mounted) {
          final List<List<String>> newPages = [];
          for (var i = 0; i < finalSuggestions.length; i += _kSuggestionsPerPage) {
            final end = (i + _kSuggestionsPerPage < finalSuggestions.length) ? i + _kSuggestionsPerPage : finalSuggestions.length;
            newPages.add(finalSuggestions.sublist(i, end));
          }

          final clearPreviousSuggestions = !hasExistingSuggestions;
          final currentPages = clearPreviousSuggestions ? <List<String>>[] : (state.helpMeReplySuggestions ?? []);
          final updatedPages = List<List<String>>.from(currentPages)..addAll(newPages);
          
          state = state.copyWith(
            helpMeReplySuggestions: updatedPages,
            helpMeReplyPageIndex: updatedPages.length - 1,
          );

          onSuggestionsReady?.call(newPages.isNotEmpty ? newPages.first : []);
        }
      } catch (e) {
        if (mounted && !state.isCancelled) {
          showTopMessage(e.toString(), backgroundColor: Colors.red);
        }
      }
    } finally {
      // 6. Always ensure the loading flag is cleared
      if (mounted) {
        state = state.copyWith(isGeneratingSuggestions: false);
      }
    }
  }

  void clearHelpMeReplySuggestions() {
    if (!mounted) return;
    if (state.helpMeReplySuggestions != null) {
      state = state.copyWith(clearHelpMeReplySuggestions: true);
    }
  }

  void changeHelpMeReplyPage(int delta) {
    if (!mounted || state.helpMeReplySuggestions == null) return;
    final newIndex = state.helpMeReplyPageIndex + delta;
    if (newIndex >= 0 && newIndex < state.helpMeReplySuggestions!.length) {
      state = state.copyWith(helpMeReplyPageIndex: newIndex);
    }
  }

  @override
 void dispose() {
   _llmStreamSubscription?.cancel();
   _stopUpdateTimer();
   _topMessageTimer?.cancel(); // Dispose the top message timer
   super.dispose();
 }

 /// A unified method to execute special, single-shot LLM actions with a retry mechanism.
 /// It ensures consistent context building (always demoting the chat's system prompt)
 /// and centralizes API call logic, returning a Future with the result.
 Future<String> _executeSpecialAction({
  required String prompt,
  required ApiConfig apiConfig, // 重构：直接接收配置对象
  required _SpecialActionType actionType,
  required Message targetMessage,
}) async {
  const maxRetries = 3;
  final chat = _ref.read(currentChatProvider(_chatId)).value;
  if (chat == null) {
    throw Exception('无法执行操作：聊天数据未加载');
  }

   final contextXmlService = _ref.read(contextXmlServiceProvider);
   final llmService = _ref.read(llmServiceProvider);

   // Build context, always demoting the original system prompt
   final apiRequestContext = await contextXmlService.buildApiRequestContext(
     chatId: _chatId,
     currentUserMessage: targetMessage,
     chatSystemPromptOverride: prompt,
     lastMessageOverride: prompt,
     keepAsSystemPrompt: false, // This is the key to ensuring the chat's prompt becomes a user message
   );

   for (int attempt = 1; attempt <= maxRetries; attempt++) {
     if (state.isCancelled) {
       throw Exception("Operation cancelled by user.");
     }

     try {
       // 重构：直接使用传入的配置对象
       final response = await llmService.sendMessageOnce(
         llmContext: apiRequestContext.contextParts,
         apiConfig: apiConfig,
       );

        if (!mounted || state.isCancelled) {
         throw Exception("Operation cancelled by user.");
       }

       if (response.isSuccess && response.parts.isNotEmpty) {
         final generatedText = response.parts.map((p) => p.text ?? "").join("\n");
         debugPrint("ChatStateNotifier($_chatId): Special action '$actionType' successful on attempt $attempt.");
         return generatedText; // Success
       } else {
         throw Exception("API Error: ${response.error ?? 'Empty response'}");
       }
     } catch (e) {
       debugPrint("ChatStateNotifier($_chatId): Special action '$actionType' attempt $attempt/$maxRetries failed: $e");
       if (attempt == maxRetries || state.isCancelled) {
         // If it's the last attempt or cancelled, rethrow to fail the Future.
         rethrow;
       }
       // Wait before retrying
       await Future.delayed(Duration(seconds: attempt * 2));
     }
   }
   // This part should be unreachable if maxRetries > 0
   throw Exception("Special action '$actionType' failed after $maxRetries attempts.");
 }

}

enum _SpecialActionType { helpMeReply, secondaryXml, autoTitle }

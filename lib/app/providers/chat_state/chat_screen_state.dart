import 'package:flutter/material.dart';
import '../../../domain/enums.dart';
import '../../../domain/models/message.dart';

@immutable
class ChatScreenState {
  final bool
  isLoading; // Master lock for the entire process (send -> all background tasks done)
  final bool
  isPrimaryResponseLoading; // Lock for the direct user-facing response (stream/single)
  final String? errorMessage; // For critical errors, might still be useful
  final String? topMessageText; // For general informational messages
  final Color? topMessageColor; // Color for the top message banner
  final DateTime? generationStartTime;
  final bool isStreaming; // Still useful to know if a stream is active overall
  final bool isStreamMode;
  final bool isPseudoStreamMode; // New state for pseudo streaming
  final double pseudoStreamSpeed; // New state for pseudo streaming speed
  final bool isBubbleTransparent;
  final bool isBubbleHalfWidth;
  final bool isMessageListHalfHeight;
  final bool isAutoHeightEnabled; // New state for the feature toggle
  final bool highlightQuotes; // New state for highlighting quotes
  final int? totalTokens;
  final List<List<String>>?
  helpMeReplySuggestions; // Changed to a list of lists for pagination
  final int helpMeReplyPageIndex; // To track the current page of suggestions
  final bool isProcessingInBackground; // New state for background tasks
  final bool
  isSummarizing; // New state to indicate a summarization task is running.
  final bool
  isGeneratingSuggestions; // New state specifically for the "Help Me Reply" feature
  final bool
  isCancelled; // Flag to indicate if the current generation has been cancelled.
  final bool isImageGenerationMode;
  final String?
  carriedOverXml; // Holds the synthesized XML for the latest user message
  // New fields for context debugging
  final int? keptMessageCount;
  final int? totalMessageCount;
  final int? contextTurnLimit;
  final int? keptTokenCount;
  final int? contextTokenLimit;
  final ContextManagementMode? contextManagementMode;
  final bool isGoogleSearchEnabled; // New state for Google Search toggle
  final bool isUrlContextEnabled;
  final bool isCodeExecutionEnabled;

  // New state fields for UI-controlled message management
  final List<Message> historicalMessages;
  final Message? uiControlledMessage;

  const ChatScreenState({
    this.isLoading = false,
    this.isPrimaryResponseLoading = false,
    this.generationStartTime,
    this.errorMessage,
    this.topMessageText,
    this.topMessageColor,
    this.isStreaming = false,
    this.isStreamMode = true,
    this.isPseudoStreamMode = false,
    this.pseudoStreamSpeed = 1.0,
    this.isBubbleTransparent = false,
    this.isBubbleHalfWidth = false,
    this.isMessageListHalfHeight = false,
    this.isAutoHeightEnabled = false, // Default to false
    this.highlightQuotes = false, // Default to false
    this.totalTokens,
    this.helpMeReplySuggestions,
    this.helpMeReplyPageIndex = 0,
    this.isProcessingInBackground = false, // Default to false
    this.isSummarizing = false,
    this.isGeneratingSuggestions = false,
    this.isCancelled = false,
    this.isImageGenerationMode = false,
    this.carriedOverXml,
    this.keptMessageCount,
    this.totalMessageCount,
    this.contextTurnLimit,
    this.keptTokenCount,
    this.contextTokenLimit,
    this.contextManagementMode,
    this.isGoogleSearchEnabled = false, // Default to false
    this.isUrlContextEnabled = false,
    this.isCodeExecutionEnabled = false,
    this.historicalMessages = const [],
    this.uiControlledMessage,
  });

  ChatScreenState copyWith({
    bool? isLoading,
    bool? isPrimaryResponseLoading,
    String? errorMessage,
    bool clearError = false, // If true, sets errorMessage to null
    String? topMessageText,
    Color? topMessageColor,
    bool clearTopMessage =
        false, // If true, sets topMessageText and topMessageColor to null
    DateTime? generationStartTime,
    bool clearGenerationStartTime = false,
    bool? isStreaming,
    bool clearStreaming = false,
    bool? isStreamMode,
    bool? isPseudoStreamMode,
    double? pseudoStreamSpeed,
    bool? isBubbleTransparent,
    bool? isBubbleHalfWidth,
    bool? isMessageListHalfHeight,
    bool? isAutoHeightEnabled,
    bool? highlightQuotes,
    int? totalTokens,
    bool clearTotalTokens = false,
    List<List<String>>? helpMeReplySuggestions,
    bool clearHelpMeReplySuggestions = false,
    int? helpMeReplyPageIndex,
    bool? isProcessingInBackground,
    bool? isSummarizing,
    bool? isGeneratingSuggestions,
    bool? isCancelled,
    bool? isImageGenerationMode,
    String? carriedOverXml,
    bool clearCarriedOverXml = false,
    int? keptMessageCount,
    int? totalMessageCount,
    int? contextTurnLimit,
    int? keptTokenCount,
    int? contextTokenLimit,
    ContextManagementMode? contextManagementMode,
    bool clearContextDebugInfo = false,
    bool? isGoogleSearchEnabled,
    bool? isUrlContextEnabled,
    bool? isCodeExecutionEnabled,
    List<Message>? historicalMessages,
    Message? uiControlledMessage,
    bool clearUiControlledMessage = false,
  }) {
    return ChatScreenState(
      isLoading: isLoading ?? this.isLoading,
      isPrimaryResponseLoading:
          isPrimaryResponseLoading ?? this.isPrimaryResponseLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      topMessageText: clearTopMessage
          ? null
          : (topMessageText ?? this.topMessageText),
      topMessageColor: clearTopMessage
          ? null
          : (topMessageColor ?? this.topMessageColor),
      generationStartTime: clearGenerationStartTime
          ? null
          : (generationStartTime ?? this.generationStartTime),
      isStreaming: clearStreaming ? false : (isStreaming ?? this.isStreaming),
      isStreamMode: isStreamMode ?? this.isStreamMode,
      isPseudoStreamMode: isPseudoStreamMode ?? this.isPseudoStreamMode,
      pseudoStreamSpeed: pseudoStreamSpeed ?? this.pseudoStreamSpeed,
      isBubbleTransparent: isBubbleTransparent ?? this.isBubbleTransparent,
      isBubbleHalfWidth: isBubbleHalfWidth ?? this.isBubbleHalfWidth,
      isMessageListHalfHeight:
          isMessageListHalfHeight ?? this.isMessageListHalfHeight,
      isAutoHeightEnabled: isAutoHeightEnabled ?? this.isAutoHeightEnabled,
      highlightQuotes: highlightQuotes ?? this.highlightQuotes,
      totalTokens: clearTotalTokens ? null : (totalTokens ?? this.totalTokens),
      helpMeReplySuggestions: clearHelpMeReplySuggestions
          ? null
          : (helpMeReplySuggestions ?? this.helpMeReplySuggestions),
      helpMeReplyPageIndex: clearHelpMeReplySuggestions
          ? 0
          : (helpMeReplyPageIndex ?? this.helpMeReplyPageIndex),
      isProcessingInBackground:
          isProcessingInBackground ?? this.isProcessingInBackground,
      isSummarizing: isSummarizing ?? this.isSummarizing,
      isGeneratingSuggestions:
          isGeneratingSuggestions ?? this.isGeneratingSuggestions,
      isCancelled: isCancelled ?? this.isCancelled,
      isImageGenerationMode:
          isImageGenerationMode ?? this.isImageGenerationMode,
      carriedOverXml: clearCarriedOverXml
          ? null
          : carriedOverXml ?? this.carriedOverXml,
      keptMessageCount: clearContextDebugInfo
          ? null
          : keptMessageCount ?? this.keptMessageCount,
      totalMessageCount: clearContextDebugInfo
          ? null
          : totalMessageCount ?? this.totalMessageCount,
      contextTurnLimit: clearContextDebugInfo
          ? null
          : contextTurnLimit ?? this.contextTurnLimit,
      keptTokenCount: clearContextDebugInfo
          ? null
          : keptTokenCount ?? this.keptTokenCount,
      contextTokenLimit: clearContextDebugInfo
          ? null
          : contextTokenLimit ?? this.contextTokenLimit,
      contextManagementMode: clearContextDebugInfo
          ? null
          : contextManagementMode ?? this.contextManagementMode,
      isGoogleSearchEnabled:
          isGoogleSearchEnabled ?? this.isGoogleSearchEnabled,
      isUrlContextEnabled: isUrlContextEnabled ?? this.isUrlContextEnabled,
      isCodeExecutionEnabled:
          isCodeExecutionEnabled ?? this.isCodeExecutionEnabled,
      historicalMessages: historicalMessages ?? this.historicalMessages,
      uiControlledMessage: clearUiControlledMessage
          ? null
          : uiControlledMessage ?? this.uiControlledMessage,
    );
  }
}

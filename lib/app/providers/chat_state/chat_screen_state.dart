import 'package:flutter/material.dart';
import '../../../domain/models/message.dart';

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
  final bool isImageGenerationMode;

  const ChatScreenState({
    this.isLoading = false,
    this.isPrimaryResponseLoading = false,
    this.generationStartTime,
    this.errorMessage,
    this.topMessageText,
    this.topMessageColor,
    this.isStreaming = false,
    this.isStreamMode = true,
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
    this.isImageGenerationMode = false,
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
    bool? isImageGenerationMode,
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
      isStreamingMessageVisible: isStreamingMessageVisible ?? (clearStreamingMessage ? false : this.isStreamingMessageVisible),
      isImageGenerationMode: isImageGenerationMode ?? this.isImageGenerationMode,
    );
  }
}
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../chat_data_providers.dart';
import '../chat_screen_state.dart';

mixin UiStateManager on StateNotifier<ChatScreenState> {
  // Properties
  Timer? topMessageTimer;
  Timer? updateTimer;
  late SharedPreferences _prefs;
  int get chatId; // Abstract getter, to be implemented by the main class
  Ref get ref; // Abstract getter for Riverpod's Ref

  // Methods

  /// Initializes the state notifier, loading persisted settings from SharedPreferences.
  void init(SharedPreferences prefs) {
    _prefs = prefs;
    state = state.copyWith(
      isStreamMode: _prefs.getBool('chat_${chatId}_is_stream_mode') ?? true,
      isPseudoStreamMode:
          _prefs.getBool('chat_${chatId}_is_pseudo_stream_mode') ?? false,
      pseudoStreamSpeed:
          _prefs.getDouble('chat_${chatId}_pseudo_stream_speed') ?? 1.0,
      isBubbleTransparent:
          _prefs.getBool('chat_${chatId}_is_bubble_transparent') ?? false,
      isBubbleHalfWidth:
          _prefs.getBool('chat_${chatId}_is_bubble_half_width') ?? false,
      isAutoHeightEnabled:
          _prefs.getBool('chat_${chatId}_is_auto_height_enabled') ?? false,
      highlightQuotes:
          _prefs.getBool('chat_${chatId}_highlight_quotes') ?? false,
      isGoogleSearchEnabled:
          _prefs.getBool('chat_${chatId}_is_google_search_enabled') ?? false,
      isUrlContextEnabled:
          _prefs.getBool('chat_${chatId}_is_url_context_enabled') ?? false,
      isCodeExecutionEnabled:
          _prefs.getBool('chat_${chatId}_is_code_execution_enabled') ?? false,
      isParallelRequestEnabled:
          _prefs.getBool('chat_${chatId}_is_parallel_request_enabled') ?? false,
      parallelRequestCount:
          _prefs.getInt('chat_${chatId}_parallel_request_count') ?? 3,
    );
  }

  void showTopMessage(
    String text, {
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 3),
  }) {
    // This check is important, but since `mounted` is not available in a mixin directly without
    // a State object, we rely on the consumer of this mixin (a StateNotifier) to handle its lifecycle.
    // Riverpod's StateNotifier handles this implicitly.
    topMessageTimer?.cancel();
    state = state.copyWith(
      topMessageText: text,
      topMessageColor:
          backgroundColor ?? Colors.blueGrey, // Default color if null
      clearTopMessage: false,
    );
    topMessageTimer = Timer(duration, () {
      clearTopMessage();
    });
  }

  void clearTopMessage() {
    topMessageTimer?.cancel();
    topMessageTimer = null;
    // Only clear if there's actually a message to prevent unnecessary rebuilds
    if (state.topMessageText != null) {
      state = state.copyWith(clearTopMessage: true);
    }
  }

  void toggleOutputMode() {
    final newValue = !state.isStreamMode;
    state = state.copyWith(isStreamMode: newValue);
    _prefs.setBool('chat_${chatId}_is_stream_mode', newValue);
    showTopMessage('输出模式已切换为: ${newValue ? "流式" : "一次性"}');
  }

  void togglePseudoStreamMode() {
    final newValue = !state.isPseudoStreamMode;
    state = state.copyWith(isPseudoStreamMode: newValue);
    _prefs.setBool('chat_${chatId}_is_pseudo_stream_mode', newValue);
    showTopMessage('伪流式模式已${newValue ? "开启" : "关闭"}');
  }

  void setPseudoStreamSpeed(double speed) {
    state = state.copyWith(pseudoStreamSpeed: speed);
    _prefs.setDouble('chat_${chatId}_pseudo_stream_speed', speed);
  }

  void toggleBubbleTransparency() {
    final newValue = !state.isBubbleTransparent;
    state = state.copyWith(isBubbleTransparent: newValue);
    _prefs.setBool('chat_${chatId}_is_bubble_transparent', newValue);
    showTopMessage('气泡已切换为: ${newValue ? "半透明" : "不透明"}');
  }

  void toggleBubbleWidthMode() {
    final newValue = !state.isBubbleHalfWidth;
    state = state.copyWith(isBubbleHalfWidth: newValue);
    _prefs.setBool('chat_${chatId}_is_bubble_half_width', newValue);
    showTopMessage('气泡宽度已切换为: ${newValue ? "半宽" : "全宽"}');
  }

  void toggleMessageListHeightMode() {
    final newValue = !state.isAutoHeightEnabled;
    state = state.copyWith(
      isAutoHeightEnabled: newValue,
      isMessageListHalfHeight: newValue,
    );
    _prefs.setBool('chat_${chatId}_is_auto_height_enabled', newValue);
    showTopMessage('智能半高模式已${newValue ? "开启" : "关闭"}');
  }

  void toggleHighlightQuotes() {
    final newValue = !state.highlightQuotes;
    state = state.copyWith(
      highlightQuotes: newValue,
      // HACK: Force a rebuild of the message list by creating a new instance
      // of the currently controlled message. This ensures the new highlight
      // setting is applied immediately.
      uiControlledMessage: state.uiControlledMessage?.copyWith(),
    );
    _prefs.setBool('chat_${chatId}_highlight_quotes', newValue);
    showTopMessage('引号内容高亮已${newValue ? "开启" : "关闭"}');
  }

  void toggleGoogleSearch() {
    final newValue = !state.isGoogleSearchEnabled;
    state = state.copyWith(isGoogleSearchEnabled: newValue);
    _prefs.setBool('chat_${chatId}_is_google_search_enabled', newValue);
    showTopMessage('Google 搜索已${newValue ? "启用" : "关闭"}');
  }

  void toggleUrlContext() {
    final newValue = !state.isUrlContextEnabled;
    state = state.copyWith(isUrlContextEnabled: newValue);
    _prefs.setBool('chat_${chatId}_is_url_context_enabled', newValue);
    showTopMessage('URL 上下文已${newValue ? "启用" : "关闭"}');
  }

  void toggleCodeExecution() {
    final newValue = !state.isCodeExecutionEnabled;
    state = state.copyWith(isCodeExecutionEnabled: newValue);
    _prefs.setBool('chat_${chatId}_is_code_execution_enabled', newValue);
    showTopMessage('代码执行已${newValue ? "启用" : "关闭"}');
  }

  void toggleParallelRequestMode() {
    final newValue = !state.isParallelRequestEnabled;
    state = state.copyWith(isParallelRequestEnabled: newValue);
    _prefs.setBool('chat_${chatId}_is_parallel_request_enabled', newValue);
    showTopMessage('并行请求模式已${newValue ? "开启" : "关闭"}');
  }

  void setParallelRequestCount(int count) {
    state = state.copyWith(parallelRequestCount: count);
    _prefs.setInt('chat_${chatId}_parallel_request_count', count);
  }

  void setMessageListHeightMode(bool isHalfHeight) {
    if (state.isMessageListHalfHeight == isHalfHeight) {
      return; // Avoid unnecessary state updates
    }
    state = state.copyWith(isMessageListHalfHeight: isHalfHeight);
  }

  void toggleImageGenerationMode() {
    final newValue = !state.isImageGenerationMode;
    state = state.copyWith(isImageGenerationMode: newValue);
    // This is a transient UI state, so we don't persist it.
  }

  void startUpdateTimer() {
    stopUpdateTimer(); // Ensure any old timer is stopped
    if (state.generationStartTime == null) return;
    ref.read(generationElapsedSecondsProvider.notifier).state = 0;

    updateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final startTime = state.generationStartTime;
      if (startTime != null) {
        final seconds = DateTime.now().difference(startTime).inSeconds;
        // OPTIMIZATION: Update the dedicated provider, not the main state
        ref.read(generationElapsedSecondsProvider.notifier).state = seconds;
      } else {
        // If startTime is null, the process has ended, so stop the timer.
        timer.cancel();
        updateTimer = null;
        // Also clear the dedicated provider's state
        if (mounted) {
          ref.read(generationElapsedSecondsProvider.notifier).state = 0;
        }
      }
    });
  }

  void stopUpdateTimer() {
    if (updateTimer?.isActive ?? false) {
      updateTimer!.cancel();
      updateTimer = null;
    }
    // Always ensure the dedicated provider is cleared when stopping.
    if (mounted) {
      ref.read(generationElapsedSecondsProvider.notifier).state = 0;
    }
  }
}

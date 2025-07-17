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
        isBubbleTransparent: _prefs.getBool('chat_${chatId}_is_bubble_transparent') ?? false,
        isBubbleHalfWidth: _prefs.getBool('chat_${chatId}_is_bubble_half_width') ?? false,
        isAutoHeightEnabled: _prefs.getBool('chat_${chatId}_is_auto_height_enabled') ?? false,
      );
    }

    void showTopMessage(String text, {Color? backgroundColor, Duration duration = const Duration(seconds: 3)}) {
      // This check is important, but since `mounted` is not available in a mixin directly without
      // a State object, we rely on the consumer of this mixin (a StateNotifier) to handle its lifecycle.
      // Riverpod's StateNotifier handles this implicitly.
      topMessageTimer?.cancel();
      state = state.copyWith(
        topMessageText: text,
        topMessageColor: backgroundColor ?? Colors.blueGrey, // Default color if null
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
      debugPrint("Chat ($chatId) 输出模式切换为: ${newValue ? "流式" : "一次性"}");
    }

    void toggleBubbleTransparency() {
      final newValue = !state.isBubbleTransparent;
      state = state.copyWith(isBubbleTransparent: newValue);
      _prefs.setBool('chat_${chatId}_is_bubble_transparent', newValue);
      showTopMessage('气泡已切换为: ${newValue ? "半透明" : "不透明"}');
      debugPrint("Chat ($chatId) 气泡透明度切换为: $newValue");
    }

    void toggleBubbleWidthMode() {
      final newValue = !state.isBubbleHalfWidth;
      state = state.copyWith(isBubbleHalfWidth: newValue);
      _prefs.setBool('chat_${chatId}_is_bubble_half_width', newValue);
      showTopMessage('气泡宽度已切换为: ${newValue ? "半宽" : "全宽"}');
      debugPrint("Chat ($chatId) 气泡宽度模式切换为: ${newValue ? "半宽" : "全宽"}");
    }

    void toggleMessageListHeightMode() {
      final newValue = !state.isAutoHeightEnabled;
      state = state.copyWith(
        isAutoHeightEnabled: newValue,
        isMessageListHalfHeight: newValue,
      );
      _prefs.setBool('chat_${chatId}_is_auto_height_enabled', newValue);
      showTopMessage('智能半高模式已: ${newValue ? "开启" : "关闭"}');
      debugPrint("Chat ($chatId) 智能半高模式切换为: $newValue");
    }

    void setMessageListHeightMode(bool isHalfHeight) {
      if (state.isMessageListHalfHeight == isHalfHeight) return; // Avoid unnecessary state updates
      state = state.copyWith(isMessageListHalfHeight: isHalfHeight);
      debugPrint("Chat ($chatId) 消息列表高度模式设置为: ${isHalfHeight ? "半高" : "全高"}");
    }

    void toggleImageGenerationMode() {
      final newValue = !state.isImageGenerationMode;
      state = state.copyWith(isImageGenerationMode: newValue);
      // This is a transient UI state, so we don't persist it.
      debugPrint("Chat ($chatId) 图片生成模式切换为: $newValue");
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
      debugPrint("Notifier: 启动了 UI 更新计时器 (独立状态)。");
    }

    void stopUpdateTimer() {
      if (updateTimer?.isActive ?? false) {
        updateTimer!.cancel();
        updateTimer = null;
        debugPrint("Notifier: 停止了 UI 更新计时器 (独立状态)。");
      }
      // Always ensure the dedicated provider is cleared when stopping.
      if (mounted) {
        ref.read(generationElapsedSecondsProvider.notifier).state = 0;
      }
    }
}
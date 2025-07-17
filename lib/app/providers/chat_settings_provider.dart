import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/chat.dart';
import '../repositories/chat_repository.dart';
import 'repository_providers.dart';


@immutable
class ChatSettingsState {
  final AsyncValue<Chat> initialChat;
  final Chat? updatedChat; // Holds the state being edited

  const ChatSettingsState({
    required this.initialChat,
    this.updatedChat,
  });

  // When editing, we use updatedChat. When displaying initial data, we use initialChat.
  Chat? get chatForDisplay => updatedChat ?? (initialChat.valueOrNull);

  ChatSettingsState copyWith({
    AsyncValue<Chat>? initialChat,
    Chat? updatedChat,
  }) {
    return ChatSettingsState(
      initialChat: initialChat ?? this.initialChat,
      updatedChat: updatedChat ?? this.updatedChat,
    );
  }
}

class ChatSettingsNotifier extends StateNotifier<ChatSettingsState> {
  final ChatRepository _chatRepository;
  final int _chatId;
  
  ChatSettingsNotifier(this._chatRepository, this._chatId)
      : super(const ChatSettingsState(initialChat: AsyncValue.loading())) {
    _loadInitialChat();
  }

  Future<void> _loadInitialChat() async {
    try {
      final chat = await _chatRepository.getChat(_chatId);
      if (chat == null) {
        throw Exception("Chat with ID $_chatId not found.");
      }
      state = state.copyWith(
        initialChat: AsyncValue.data(chat),
        updatedChat: chat.copyWith(), // Create a mutable copy for editing
      );
    } catch (e, st) {
      state = state.copyWith(initialChat: AsyncValue.error(e, st));
    }
  }

  void updateSettings(Chat Function(Chat currentChat) updateFn) {
    if (state.updatedChat != null) {
      state = state.copyWith(updatedChat: updateFn(state.updatedChat!));
    }
  }

  Future<void> saveSettings() async {
    if (state.updatedChat == null) {
      throw Exception("Cannot save, no settings have been loaded or modified.");
    }
    await _chatRepository.saveChat(state.updatedChat!);
    // Reload the initial state to reflect the saved data as the new baseline
    await _loadInitialChat();
  }
}

final chatSettingsProvider = StateNotifierProvider.autoDispose.family<ChatSettingsNotifier, ChatSettingsState, int>((ref, chatId) {
  final chatRepository = ref.watch(chatRepositoryProvider);
  return ChatSettingsNotifier(chatRepository, chatId);
});
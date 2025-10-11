import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../chat_state/chat_data_providers.dart';

/// A data class to hold the combined and consistent state for the chat screen.
/// It bundles the current chat, its siblings for the PageView, and the current index.
class ChatScreenData {
  final Chat currentChat;
  final List<Chat> siblingChats;
  final int currentIndex;

  ChatScreenData({
    required this.currentChat,
    required this.siblingChats,
    required this.currentIndex,
  });
}

/// This provider encapsulates the complex logic of fetching and combining data
/// required by the ChatScreen. It watches the active chat and its sibling list,
/// handling all intermediate loading, error, and data inconsistency states.
///
/// By centralizing this logic, the UI widget (`ChatScreen`) becomes much simpler,
/// declarative, and robust against race conditions or transient data states.
final chatScreenDataProvider = Provider.autoDispose.family<AsyncValue<ChatScreenData>, int>((
  ref,
  chatId,
) {
  // Watch the data stream for the currently active chat.
  final chatAsync = ref.watch(currentChatProvider(chatId));

  // The .when method is used to reactively handle the different states of the stream.
  return chatAsync.when(
    data: (chat) {
      // If the chat data is null (e.g., the chat was deleted),
      // we treat it as an error state to be displayed in the UI.
      if (chat == null) {
        return AsyncValue.error(
          'Chat not found or has been deleted.',
          StackTrace.current,
        );
      }

      // Once we have the chat data, we determine the correct mode (normal chat or template)
      // and then watch the data stream for its sibling chats.
      final mode = chat.isTemplate
          ? ChatListMode.templateManagement
          : ChatListMode.normal;
      final siblingChatsAsync = ref.watch(
        chatListProvider((parentFolderId: chat.parentFolderId, mode: mode)),
      );

      // Reactively handle the states of the sibling chats stream.
      return siblingChatsAsync.when(
        data: (siblings) {
          // Filter out folders to get a clean list of chats for the PageView.
          final chats = siblings.where((c) => !c.isFolder).toList();
          final currentIndex = chats.indexWhere((c) => c.id == chatId);

          // This is a critical consistency check. If the current chat does not
          // exist in its own sibling list, it points to a transient data
          // inconsistency (e.g., due to sync delays). We must handle this
          // gracefully by treating it as a recoverable error in the UI.
          if (currentIndex == -1) {
            return AsyncValue.error(
              'Data inconsistency: Chat is out of sync with its folder.',
              StackTrace.current,
            );
          }

          // If all data is present and consistent, return the combined data object.
          return AsyncValue.data(
            ChatScreenData(
              currentChat: chat,
              siblingChats: chats,
              currentIndex: currentIndex,
            ),
          );
        },
        // If sibling chats are loading, the entire screen state is considered loading.
        loading: () => const AsyncValue.loading(),
        // Propagate any errors from the sibling chats stream.
        error: (error, stack) => AsyncValue.error(error, stack),
      );
    },
    // If the current chat is loading, the entire screen state is loading.
    loading: () => const AsyncValue.loading(),
    // Propagate any errors from the current chat stream.
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_state/chat_screen_state.dart';
import 'chat_state/chat_state_notifier.dart';

// Re-export data providers so other parts of the app can have a single import point.
export 'chat_state/chat_data_providers.dart';
export 'chat_state/chat_screen_state.dart';

/// =================================================================
/// Final Chat State Notifier Provider
/// =================================================================
/// This is the central provider that gives access to the ChatStateNotifier.
/// It asynchronously initializes the notifier with SharedPreferences.
final chatStateNotifierProvider =
    StateNotifierProvider.family<ChatStateNotifier, ChatScreenState, int>(
  (ref, chatId) {
    // Asynchronously get the SharedPreferences instance.
    final prefsFuture = SharedPreferences.getInstance();
    
    // Create the notifier instance.
    final notifier = ChatStateNotifier(ref, chatId);

    // When the preferences are ready, initialize the notifier.
    prefsFuture.then((prefs) {
      // Check if the notifier is still mounted before calling init.
      if (notifier.mounted) {
        notifier.init(prefs);
      }
    });
    
    return notifier;
  },
);

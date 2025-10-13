import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core_providers.dart';
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
    StateNotifierProvider.family<ChatStateNotifier, ChatScreenState, int>((
  ref,
  chatId,
) {
  // Depend on the SharedPreferences provider.
  // This will cause this provider to re-evaluate when the Future completes.
  final prefsAsyncValue = ref.watch(sharedPreferencesProvider);

  // Create the notifier instance.
  final notifier = ChatStateNotifier(ref, chatId);

  // When SharedPreferences is ready, initialize the notifier.
  // This ensures that the `_prefs` field in the UiStateManager mixin is set.
  prefsAsyncValue.whenData((prefs) {
    notifier.init(prefs);
  });

  return notifier;
});

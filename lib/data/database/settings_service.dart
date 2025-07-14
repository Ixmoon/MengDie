// lib/data/database/settings_service.dart

/// Manages global, non-persistent settings for the current app session.
///
/// This service provides global flags and session-specific data.
/// It follows a singleton pattern to ensure a single source of truth throughout the app.
/// Note: For persistent settings, use providers that leverage SharedPreferences.
class SettingsService {
  // Private constructor for the singleton pattern.
  SettingsService._();

  /// The single, shared instance of [SettingsService].
  static final SettingsService instance = SettingsService._();

  /// The ID of the currently logged-in user.
  /// This is crucial for ensuring that sync operations are performed for the correct user.
  /// Defaults to 0, which should represent a "guest" or "logged-out" state.
  int currentUserId = 0;
}
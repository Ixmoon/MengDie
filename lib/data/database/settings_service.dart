// lib/data/database/settings_service.dart

/// Manages global settings for database operations, specifically for remote synchronization.
///
/// This service provides global flags to enable or disable remote writes and reads.
/// It follows a singleton pattern to ensure a single source of truth for these settings throughout the app.
class SettingsService {
  // Private constructor for the singleton pattern.
  SettingsService._();

  /// The single, shared instance of [SettingsService].
  static final SettingsService instance = SettingsService._();

  /// Global flag to control whether write operations are synced to the remote database.
  ///
  /// Defaults to `false`. When `true`, write operations (insert, update, delete)
  /// will attempt to sync to the remote server.
  bool remoteWriteEnabled = false;

  /// Global flag to control whether read operations can fetch data from the remote database.
  ///
  /// Defaults to `false`. When `true`, specific read operations can be instructed
  /// to fetch the latest data from the remote server.
  bool remoteReadEnabled = false;
}
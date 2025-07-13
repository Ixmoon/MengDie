import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:logging/logging.dart';
import 'package:postgres/postgres.dart';
import 'package:retry/retry.dart';

import '../app_database.dart';
import '../connections/remote.dart';
import '../settings_service.dart';

/// ## SyncService
///
/// This service orchestrates the synchronization between the local Drift database and the remote Neon (PostgreSQL) database.
/// It supports non-blocking background writes with automatic rollbacks and on-demand remote reads.
///
/// ### Key Functionalities:
/// - **Non-Blocking Writes**: Local operations return immediately while data is synced in the background.
/// - **Automatic Rollback**: If a background sync fails, a provided `rollbackAction` is executed to revert local changes.
/// - **On-Demand Remote Reads**: Allows fetching fresh data from the remote database when needed.
/// - **Global Toggles**: All operations are controlled by global flags in `SettingsService`.
class SyncService {
  final Future<Connection> Function() _remoteConnectionFactory;
  late final AppDatabase _db;
  final Logger _log = Logger('SyncService');

  SyncService._(this._remoteConnectionFactory);

  static SyncService? _instance;

  /// Initializes the SyncService singleton.
  ///
  /// Must be called once during app initialization.
  /// - [db]: The local `AppDatabase` instance, used for rollback operations.
  /// - [remoteConnectionFactory]: A function to create a remote PostgreSQL connection.
  static void initialize(AppDatabase db,
      Future<Connection> Function() remoteConnectionFactory) {
    if (_instance != null) {
      // Use a static logger here as _log is an instance member.
      Logger('SyncService').warning("SyncService is already initialized.");
      return;
    }
    _instance = SyncService._(remoteConnectionFactory).._db = db;
  }

  /// Returns the singleton instance of SyncService.
  static SyncService get instance {
    if (_instance == null) {
      throw Exception(
          "SyncService has not been initialized. Call SyncService.initialize() first.");
    }
    return _instance!;
  }

  /// Executes a remote write operation in the background without blocking the caller.
  ///
  /// - [remoteTransaction]: The function performing the database write on the remote server.
  /// - [rollbackAction]: A function that reverts the local database changes if the remote write fails.
  void backgroundWrite({
    required Future<void> Function(Session) remoteTransaction,
    required Future<void> Function() rollbackAction,
    bool force = false,
  }) {
    // Trigger if the global switch is on OR if this specific action is forced.
    if (!SettingsService.instance.remoteWriteEnabled && !force) {
      return;
    }

    // Fire-and-forget the remote operation.
    _executeRemoteWrite(remoteTransaction, rollbackAction);
  }

  Future<void> _executeRemoteWrite(
      Future<void> Function(Session) remoteTransaction,
      Future<void> Function() rollbackAction) async {
    try {
      const retryOptions = RetryOptions(
        maxAttempts: 3,
        delayFactor: Duration(milliseconds: 200),
      );

      await retryOptions.retry(
        () async {
          Connection? remoteConnection;
          try {
            remoteConnection = await _remoteConnectionFactory();
            await remoteConnection.runTx((ctx) async {
              await remoteTransaction(ctx);
            });
          } finally {
            await remoteConnection?.close();
          }
        },
        retryIf: (e) => e is TimeoutException || e is SocketException,
        onRetry: (e) =>
            _log.warning("Remote transaction failed, retrying...", e),
      );
    } catch (e, s) {
      _log.severe('Remote transaction failed after retries. Rolling back local changes.', e, s);
      try {
        await rollbackAction();
        _log.info("Local rollback successful.");
      } catch (rollbackError, rollbackStack) {
        _log.severe('CRITICAL: Local rollback failed!', rollbackError, rollbackStack);
      }
    }
  }

  /// Performs a read operation on the remote database.
  ///
  /// - [remoteReadAction]: The function that executes the query on the remote server and returns a result.
  /// Returns the result of the remote operation, or `null` if remote reads are disabled or fail.
  Future<T?> remoteRead<T>({
    required Future<T> Function(Session) remoteReadAction,
    bool force = false,
  }) async {
    // Trigger if the global switch is on OR if this specific action is forced.
    if (!SettingsService.instance.remoteReadEnabled && !force) {
      return null;
    }

    try {
      Connection? remoteConnection;
      try {
        remoteConnection = await _remoteConnectionFactory();
        return await remoteConnection.run((ctx) async {
          return await remoteReadAction(ctx);
        });
      } finally {
        await remoteConnection?.close();
      }
    } catch (e, s) {
      _log.severe('Remote read failed.', e, s);
      return null;
    }
  }
}
import 'package:postgres/postgres.dart';

import '../../database/app_database.dart';
import '../sync_meta.dart';

/// Abstract base class for handling the synchronization of a specific entity.
///
/// Each implementation of this class is responsible for the full sync lifecycle
/// of one type of data (e.g., Users, Chats, ApiConfigs).
abstract class BaseSyncHandler<T> {
  final AppDatabase db;
  // Made nullable to allow handler instantiation without an active connection
  // for operations that don't require it (e.g., getLocalMetas).
  final Connection? remoteConnection;

  BaseSyncHandler(this.db, this.remoteConnection);

  /// A unique key to identify the entity type (e.g., 'users', 'chats').
  String get entityType;

  /// Fetches synchronization metadata from the local database.
  Future<List<SyncMeta>> getLocalMetas();

  /// Fetches synchronization metadata from the remote database.
  Future<List<SyncMeta>> getRemoteMetas({List<dynamic>? localIds});

  /// Resolves ID conflicts between local and remote data.
  ///
  /// This method identifies records with the same ID but different creation
  /// timestamps and modifies the local record to resolve the conflict.
  /// Returns a map of {oldId: newId} for all changed local records.
  Future<Map<dynamic, dynamic>> resolveConflicts(List<SyncMeta> localMetas, List<SyncMeta> remoteMetas);

  /// Pushes a list of local entities to the remote database.
  Future<void> push(List<dynamic> ids);

  /// Pulls a list of remote entities to the local database.
  Future<void> pull(List<dynamic> ids);
  
  /// Deletes entities from the remote database based on a list of keys.
  Future<void> deleteRemotely(List<String> keys);
}
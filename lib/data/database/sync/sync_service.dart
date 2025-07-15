import 'dart:async';
import 'dart:collection';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';

import '../app_database.dart';
import '../../models/enums.dart';
import '../../../ui/providers/settings_providers.dart';
import '../settings_service.dart';
import 'sync_meta.dart';
import 'handlers/base_sync_handler.dart';
import 'handlers/user_sync_handler.dart';
import 'handlers/api_config_sync_handler.dart';
import 'handlers/chat_sync_handler.dart';

/// A helper class to hold the results of a sync comparison.
class _SyncActions<T> {
  final List<T> toPull;
  final List<T> toCreateLocally;

  _SyncActions({
    this.toPull = const [],
    this.toCreateLocally = const [],
  });
}

/// A helper class to hold the results of a two-way merge sync.
class _MergeActions<T> {
  final List<T> toPull;
  final List<T> toPush;

  _MergeActions({
    this.toPull = const [],
    this.toPush = const [],
  });
}

/// ===================================================================
/// Service for Synchronizing Local and Remote Databases (Refactored)
/// ===================================================================
///
/// ## Core Responsibilities
/// This service orchestrates the two-way data synchronization between the local
/// Drift database and a remote PostgreSQL database. It delegates the actual
/// data handling for each entity type to specialized `BaseSyncHandler` implementations.
///
/// ## Key Synchronization Strategies
///
/// 1.  **Handler-Based Architecture**: Logic for each entity (Users, ApiConfigs, Chats)
///     is encapsulated in its own handler class (e.g., `UserSyncHandler`). This
///     improves separation of concerns and makes the system more modular.
///
/// 2.  **ID Conflict Resolution**: The conflict resolution logic (for `int` IDs)
///     is now managed within the respective handlers (`ChatSyncHandler`, `ApiConfigSyncHandler`).
///     The core strategy remains the same: modify the local ID and update all
///     foreign key references atomically.
///
/// 3.  **Metadata-First Approach**: The sync process still fetches lightweight
///     metadata first to calculate the delta of changes, minimizing network traffic.
///
/// 4.  **Batch Processing**: All database operations are performed in batches for
///     maximum performance, managed by the individual handlers.
///
class SyncService {
  final Future<Connection> Function() _remoteConnectionFactory;
  final ProviderContainer _providerContainer;
  late final AppDatabase _db;
  Map<String, Map<String, DateTime>>? _snapshotCache;

  SyncService._(this._remoteConnectionFactory, this._providerContainer);

  static SyncService? _instance;

  static void initialize(AppDatabase db, Future<Connection> Function() remoteConnectionFactory, ProviderContainer providerContainer) {
    if (_instance != null) return;
    _instance = SyncService._(remoteConnectionFactory, providerContainer).._db = db;
  }

  static SyncService get instance {
    if (_instance == null) {
      throw Exception("SyncService has not been initialized. Call SyncService.initialize() first.");
    }
    return _instance!;
  }

  // Determines which items need to be pulled or created locally.
  _SyncActions<dynamic> _computeSyncActions({
    required List<SyncMeta> localMetas,
    required List<SyncMeta> remoteMetas,
  }) {
    final localMap = {for (var meta in localMetas) meta.key: meta};
    final remoteMap = {for (var meta in remoteMetas) meta.key: meta};

    final toPull = <dynamic>[];
    final toCreateLocally = <dynamic>[];

    for (final remoteMeta in remoteMetas) {
      final localMeta = localMap[remoteMeta.key];
      if (localMeta == null) {
        toCreateLocally.add(remoteMeta.id);
      } else if (remoteMeta.updatedAt.toUtc().isAfter(localMeta.updatedAt.toUtc())) {
        toPull.add(remoteMeta.id);
      }
    }

    return _SyncActions(
      toPull: toPull,
      toCreateLocally: toCreateLocally,
    );
  }

  /// A unified, efficient, and safe method to resolve ID conflicts between
  /// local and remote metadata. It first identifies only the items that are
  /// actually in conflict (same key, different creation time) and then
  /// resolves them in the correct dependency order.
  Future<((List<SyncMeta>, List<SyncMeta>, List<SyncMeta>), (List<SyncMeta>, List<SyncMeta>, List<SyncMeta>))>
  _resolveChanges(
    Connection remoteConnection,
    (List<SyncMeta>, List<SyncMeta>, List<SyncMeta>) localData,
    (List<SyncMeta>, List<SyncMeta>, List<SyncMeta>) remoteData,
  ) async {
    var (localApiConfigMetas, localChatMetas, localUserMetas) = localData;
    final (remoteApiConfigMetas, remoteChatMetas, remoteUserMetas) = remoteData;

    // Helper to find conflicting metas
    List<SyncMeta> findConflictingMetas(List<SyncMeta> local, List<SyncMeta> remote) {
      final remoteMap = {for (var meta in remote) meta.key: meta};
      final conflicts = <SyncMeta>[];
      for (final localMeta in local) {
        final remoteMeta = remoteMap[localMeta.key];
        if (remoteMeta != null && remoteMeta.createdAt.toUtc() != localMeta.createdAt.toUtc()) {
          conflicts.add(localMeta);
        }
      }
      return conflicts;
    }

    // Handlers are needed for the resolution logic
    final userId = SettingsService.instance.currentUserId;
    final apiConfigHandler = ApiConfigSyncHandler(_db, remoteConnection, userId);
    final chatHandler = ChatSyncHandler(_db, remoteConnection);
    final userHandler = UserSyncHandler(_db, remoteConnection);

    // Resolve conflicts in dependency order, but only on the conflicting subset of data.
    debugPrint("Checking for data conflicts on differing items...");

    final conflictingUserMetas = findConflictingMetas(localUserMetas, remoteUserMetas);
    if (conflictingUserMetas.isNotEmpty) {
      debugPrint("Found ${conflictingUserMetas.length} conflicting user metas: ${conflictingUserMetas.map((m) => m.id).toList()}");
      final userChanges = await userHandler.resolveConflicts(conflictingUserMetas, remoteUserMetas);
      debugPrint("User conflicts resolved with changes: $userChanges");
    }

    final conflictingApiConfigMetas = findConflictingMetas(localApiConfigMetas, remoteApiConfigMetas);
    if (conflictingApiConfigMetas.isNotEmpty) {
      debugPrint("Found ${conflictingApiConfigMetas.length} conflicting api_config metas: ${conflictingApiConfigMetas.map((m) => m.id).toList()}");
      final apiConfigChanges = await apiConfigHandler.resolveConflicts(conflictingApiConfigMetas, remoteApiConfigMetas);
      if (apiConfigChanges.isNotEmpty) {
        _updateMetasInMemory(localApiConfigMetas, apiConfigChanges);
        debugPrint("ApiConfig conflicts resolved with changes: $apiConfigChanges");
      }
    }
    
    final conflictingChatMetas = findConflictingMetas(localChatMetas, remoteChatMetas);
    if (conflictingChatMetas.isNotEmpty) {
      debugPrint("Found ${conflictingChatMetas.length} conflicting chat metas: ${conflictingChatMetas.map((m) => m.id).toList()}");
      final chatChanges = await chatHandler.resolveConflicts(conflictingChatMetas, remoteChatMetas);
      if (chatChanges.isNotEmpty) {
        _updateMetasInMemory(localChatMetas, chatChanges);
        debugPrint("Chat conflicts resolved with changes: $chatChanges");
      }
    }
    
    // Return the modified local data and original remote data
    return ((localApiConfigMetas, localChatMetas, localUserMetas), remoteData);
  }

  Future<void> syncWithRemote() async {
    final syncSettings = _providerContainer.read(syncSettingsProvider);
    if (!syncSettings.isEnabled || syncSettings.connectionString.isEmpty) {
      debugPrint("Remote sync is disabled. Skipping.");
      return;
    }
    debugPrint("Starting database synchronization...");
    
    _initializeSnapshotCacheIfNeeded();

    Connection? remoteConnection;
    try {
      remoteConnection = await _remoteConnectionFactory();
      final userId = SettingsService.instance.currentUserId;
      debugPrint('Syncing data for userId: $userId');

      final apiConfigHandler = ApiConfigSyncHandler(_db, remoteConnection, userId);
      final chatHandler = ChatSyncHandler(_db, remoteConnection);
      final userHandler = UserSyncHandler(_db, remoteConnection);

      debugPrint("Fetching local and remote metadata...");
      final (localData, remoteData) = await (
        (
          apiConfigHandler.getLocalMetas(),
          chatHandler.getLocalMetas(),
          userHandler.getLocalMetas(),
        ).wait,
        (
          apiConfigHandler.getRemoteMetas(),
          chatHandler.getRemoteMetas(),
          userHandler.getRemoteMetas(),
        ).wait
      ).wait;
      
      var (localApiConfigMetas, localChatMetas, localUserMetas) = localData;
      var (remoteApiConfigMetas, remoteChatMetas, remoteUserMetas) = remoteData;

      // --- Step 3: Optimization - Pre-check for changes before resolving conflicts ---
      final preCheckApiConfigActions = _computeSyncActions(localMetas: localApiConfigMetas, remoteMetas: remoteApiConfigMetas);
      final preCheckChatActions = _computeSyncActions(localMetas: localChatMetas, remoteMetas: remoteChatMetas);
      final preCheckUserActions = _computeSyncActions(localMetas: localUserMetas, remoteMetas: remoteUserMetas);

      if (preCheckApiConfigActions.toPull.isEmpty && preCheckApiConfigActions.toCreateLocally.isEmpty &&
          preCheckChatActions.toPull.isEmpty && preCheckChatActions.toCreateLocally.isEmpty &&
          preCheckUserActions.toPull.isEmpty && preCheckUserActions.toCreateLocally.isEmpty) {
        debugPrint("No remote changes detected. Sync skipped.");
        await _updateSnapshotCache(); // Still update snapshot to align timestamps if needed
        return;
      }

      // --- Step 4: Resolve ID Conflicts on differing items ---
      final ((resolvedLocalApiMetas, resolvedLocalChatMetas, resolvedLocalUserMetas),
             (resolvedRemoteApiConfigMetas, resolvedRemoteChatMetas, resolvedRemoteUserMetas)) = await _resolveChanges(remoteConnection, localData, remoteData);

      // --- Step 5: Compute Actions with resolved data ---
      debugPrint("Computing synchronization actions...");
      final apiConfigActions = _computeSyncActions(localMetas: resolvedLocalApiMetas, remoteMetas: resolvedRemoteApiConfigMetas);
      final chatActions = _computeSyncActions(localMetas: resolvedLocalChatMetas, remoteMetas: resolvedRemoteChatMetas);
      final userActions = _computeSyncActions(localMetas: resolvedLocalUserMetas, remoteMetas: resolvedRemoteUserMetas);

      // --- Step 5: Execute Pulls ---
      final apiConfigIdsToPull = {...apiConfigActions.toPull, ...apiConfigActions.toCreateLocally}.toList();
      final chatIdsToPull = {...chatActions.toPull, ...chatActions.toCreateLocally}.toList();
      final userIdsToPull = {...userActions.toPull, ...userActions.toCreateLocally}.toList();
      
      debugPrint("--- Sync Actions Summary (Pull) ---");
      debugPrint("Users to pull: ${userIdsToPull.length} IDs: $userIdsToPull");
      debugPrint("ApiConfigs to pull: ${apiConfigIdsToPull.length} IDs: $apiConfigIdsToPull");
      debugPrint("Chats to pull: ${chatIdsToPull.length} IDs: $chatIdsToPull");
      debugPrint("------------------------------------");

      await _db.transaction(() async {
        await userHandler.pull(userIdsToPull);
        await apiConfigHandler.pull(apiConfigIdsToPull);
        await chatHandler.pull(chatIdsToPull);
      });

      // --- Step 6: Update snapshot after successful pull ---
      await _updateSnapshotCache();
      debugPrint("Synchronization finished and snapshot updated.");

    } catch (e, s) {
      debugPrint('Synchronization failed: ${e.toString()}\n${s.toString()}');
    } finally {
      await remoteConnection?.close();
    }
  }

  Future<bool> forcePushChanges() async {
    final syncSettings = _providerContainer.read(syncSettingsProvider);
    if (!syncSettings.isEnabled || syncSettings.connectionString.isEmpty) {
      debugPrint("Remote sync is disabled. Skipping push.");
      return false;
    }
    
    _initializeSnapshotCacheIfNeeded();

    final isFirstSync = _snapshotCache!.values.every((map) => map.isEmpty);

    if (isFirstSync) {
      debugPrint("Snapshot is empty, performing initial merge sync...");
      return _performInitialMergeSync();
    } else {
      debugPrint("Snapshot found, performing differential push...");
      return _performDifferentialPush();
    }
  }

  void _initializeSnapshotCacheIfNeeded() {
    if (_snapshotCache != null) return;

    debugPrint("Initializing in-memory snapshot cache...");
    final tempApiConfigHandler = ApiConfigSyncHandler(_db, null, SettingsService.instance.currentUserId);
    final tempChatHandler = ChatSyncHandler(_db, null);
    final tempUserHandler = UserSyncHandler(_db, null);

    _snapshotCache = {
      tempApiConfigHandler.entityType: {},
      tempChatHandler.entityType: {},
      tempUserHandler.entityType: {},
    };
    debugPrint("In-memory snapshot cache initialized.");
  }

  Future<void> _updateSnapshotCache() async {
    debugPrint("Updating in-memory snapshot cache...");
    final tempApiConfigHandler = ApiConfigSyncHandler(_db, null, SettingsService.instance.currentUserId);
    final tempChatHandler = ChatSyncHandler(_db, null);
    final tempUserHandler = UserSyncHandler(_db, null);

    final (localApiConfigMetas, localChatMetas, localUserMetas) = await (
      tempApiConfigHandler.getLocalMetas(),
      tempChatHandler.getLocalMetas(),
      tempUserHandler.getLocalMetas(),
    ).wait;

    _snapshotCache = {
      tempApiConfigHandler.entityType: {for (var meta in localApiConfigMetas) meta.key.toString(): meta.updatedAt.toUtc()},
      tempChatHandler.entityType: {for (var meta in localChatMetas) meta.key.toString(): meta.updatedAt.toUtc()},
      tempUserHandler.entityType: {for (var meta in localUserMetas) meta.key.toString(): meta.updatedAt.toUtc()},
    };
    debugPrint("In-memory snapshot cache updated.");
  }

  _MergeActions<dynamic> _computeMergeActions({
    required List<SyncMeta> localMetas,
    required List<SyncMeta> remoteMetas,
  }) {
    final localMap = {for (var meta in localMetas) meta.key: meta};
    final remoteMap = {for (var meta in remoteMetas) meta.key: meta};
    final allKeys = {...localMap.keys, ...remoteMap.keys};

    final toPull = <dynamic>[];
    final toPush = <dynamic>[];

    for (final key in allKeys) {
      final localMeta = localMap[key];
      final remoteMeta = remoteMap[key];

      if (localMeta == null && remoteMeta != null) {
        toPull.add(remoteMeta.id);
      } else if (localMeta != null && remoteMeta == null) {
        toPush.add(localMeta.id);
      } else if (localMeta != null && remoteMeta != null) {
        if (remoteMeta.updatedAt.toUtc().isAfter(localMeta.updatedAt.toUtc())) {
          toPull.add(remoteMeta.id);
        } else if (localMeta.updatedAt.toUtc().isAfter(remoteMeta.updatedAt.toUtc())) {
          toPush.add(localMeta.id);
        }
      }
    }
    return _MergeActions(toPull: toPull, toPush: toPush);
  }

  Future<bool> _performInitialMergeSync() async {
    Connection? remoteConnection;
    try {
      remoteConnection = await _remoteConnectionFactory();
      final userId = SettingsService.instance.currentUserId;
      debugPrint('Performing initial merge-sync for userId: $userId');

      final apiConfigHandler = ApiConfigSyncHandler(_db, remoteConnection, userId);
      final chatHandler = ChatSyncHandler(_db, remoteConnection);
      final userHandler = UserSyncHandler(_db, remoteConnection);

      debugPrint("Fetching local and remote metadata for merge...");
      final (localData, remoteData) = await (
        (
          apiConfigHandler.getLocalMetas(),
          chatHandler.getLocalMetas(),
          userHandler.getLocalMetas(),
        ).wait,
        (
          apiConfigHandler.getRemoteMetas(),
          chatHandler.getRemoteMetas(),
          userHandler.getRemoteMetas(),
        ).wait,
      ).wait;
      
      var (localApiConfigMetas, localChatMetas, localUserMetas) = localData;
      var (remoteApiConfigMetas, remoteChatMetas, remoteUserMetas) = remoteData;

      // Optimization: Pre-check for changes before resolving conflicts
      final preCheckApiConfigActions = _computeMergeActions(localMetas: localApiConfigMetas, remoteMetas: remoteApiConfigMetas);
      final preCheckChatActions = _computeMergeActions(localMetas: localChatMetas, remoteMetas: remoteChatMetas);
      final preCheckUserActions = _computeMergeActions(localMetas: localUserMetas, remoteMetas: remoteUserMetas);

      if (preCheckApiConfigActions.toPull.isEmpty && preCheckApiConfigActions.toPush.isEmpty &&
          preCheckChatActions.toPull.isEmpty && preCheckChatActions.toPush.isEmpty &&
          preCheckUserActions.toPull.isEmpty && preCheckUserActions.toPush.isEmpty) {
        debugPrint("No differences found between local and remote. Initial merge sync skipped.");
        await _updateSnapshotCache(); // Update snapshot to mark the sync as "done"
        return true;
      }
      
      final ((resolvedLocalApiMetas, resolvedLocalChatMetas, resolvedLocalUserMetas),
             (resolvedRemoteApiConfigMetas, resolvedRemoteChatMetas, resolvedRemoteUserMetas)) = await _resolveChanges(remoteConnection, localData, remoteData);

      debugPrint("Computing merge actions...");
      final apiConfigActions = _computeMergeActions(localMetas: resolvedLocalApiMetas, remoteMetas: resolvedRemoteApiConfigMetas);
      final chatActions = _computeMergeActions(localMetas: resolvedLocalChatMetas, remoteMetas: resolvedRemoteChatMetas);
      final userActions = _computeMergeActions(localMetas: resolvedLocalUserMetas, remoteMetas: resolvedRemoteUserMetas);

      debugPrint("--- Sync Actions Summary (Merge) ---");
      debugPrint("Users to pull: ${userActions.toPull.length} IDs: ${userActions.toPull}");
      debugPrint("Users to push: ${userActions.toPush.length} IDs: ${userActions.toPush}");
      debugPrint("ApiConfigs to pull: ${apiConfigActions.toPull.length} IDs: ${apiConfigActions.toPull}");
      debugPrint("ApiConfigs to push: ${apiConfigActions.toPush.length} IDs: ${apiConfigActions.toPush}");
      debugPrint("Chats to pull: ${chatActions.toPull.length} IDs: ${chatActions.toPull}");
      debugPrint("Chats to push: ${chatActions.toPush.length} IDs: ${chatActions.toPush}");
      debugPrint("------------------------------------");

      await remoteConnection.execute('BEGIN');
      try {
        // --- Execute Actions in Serial Order to Respect Foreign Key Constraints ---
        // Pull operations
        await userHandler.pull(userActions.toPull);
        await apiConfigHandler.pull(apiConfigActions.toPull);
        await chatHandler.pull(chatActions.toPull);

        // Push operations
        await userHandler.push(userActions.toPush);
        await apiConfigHandler.push(apiConfigActions.toPush);
        await chatHandler.push(chatActions.toPush);
        
        await remoteConnection.execute('COMMIT');
        
        await _updateSnapshotCache();
        debugPrint("Initial merge-sync completed and snapshot created.");
        return true;
      } catch (e) {
        await remoteConnection.execute('ROLLBACK');
        debugPrint('Initial merge-sync failed during transaction: ${e.toString()}');
        return false;
      }
    } catch (e, s) {
      debugPrint('Initial merge-sync failed: ${e.toString()}\n${s.toString()}');
      return false;
    } finally {
      await remoteConnection?.close();
    }
  }

  Future<bool> _performDifferentialPush() async {
    debugPrint("Starting differential push of local changes...");
    final tempApiConfigHandler = ApiConfigSyncHandler(_db, null, SettingsService.instance.currentUserId);
    final tempChatHandler = ChatSyncHandler(_db, null);
    final tempUserHandler = UserSyncHandler(_db, null);
    
    try {
      // Step 1: Fetch local metadata
      final (localApiConfigMetas, localChatMetas, localUserMetas) = await (
          tempApiConfigHandler.getLocalMetas(),
          tempChatHandler.getLocalMetas(),
          tempUserHandler.getLocalMetas(),
      ).wait;

      final apiConfigSnapshot = _snapshotCache![tempApiConfigHandler.entityType]!;
      final chatSnapshot = _snapshotCache![tempChatHandler.entityType]!;
      final userSnapshot = _snapshotCache![tempUserHandler.entityType]!;

      // Step 2: Compute differences
      final apiConfigsToPush = localApiConfigMetas.where((m) => apiConfigSnapshot[m.key.toString()] == null || m.updatedAt.toUtc().isAfter(apiConfigSnapshot[m.key.toString()]!)).toList();
      final chatsToPush = localChatMetas.where((m) => chatSnapshot[m.key.toString()] == null || m.updatedAt.toUtc().isAfter(chatSnapshot[m.key.toString()]!)).toList();
      final usersToPush = localUserMetas.where((m) => userSnapshot[m.key.toString()] == null || m.updatedAt.toUtc().isAfter(userSnapshot[m.key.toString()]!)).toList();

      final localUserKeys = localUserMetas.map((m) => m.key.toString()).toSet();
      final localApiConfigKeys = localApiConfigMetas.map((m) => m.key.toString()).toSet();
      final localChatKeys = localChatMetas.map((m) => m.key.toString()).toSet();

      final userKeysToDelete = userSnapshot.keys.where((k) => !localUserKeys.contains(k)).toList();
      final apiConfigKeysToDelete = apiConfigSnapshot.keys.where((k) => !localApiConfigKeys.contains(k)).toList();
      final chatKeysToDelete = chatSnapshot.keys.where((k) => !localChatKeys.contains(k)).toList();

      if (usersToPush.isEmpty && apiConfigsToPush.isEmpty && chatsToPush.isEmpty &&
          userKeysToDelete.isEmpty && apiConfigKeysToDelete.isEmpty && chatKeysToDelete.isEmpty) {
        debugPrint("No local changes detected. Push skipped.");
        return true;
      }

      Connection? remoteConnection;
      try {
        remoteConnection = await _remoteConnectionFactory();
        final userId = SettingsService.instance.currentUserId;
        final apiConfigHandler = ApiConfigSyncHandler(_db, remoteConnection, userId);
        final chatHandler = ChatSyncHandler(_db, remoteConnection);
        final userHandler = UserSyncHandler(_db, remoteConnection);

        // Step 3: Resolve conflicts for NEW items before pushing
        debugPrint("Checking for conflicts before push...");
        
        // Helper to filter for new metas
        List<SyncMeta> getNewMetas(List<SyncMeta> metas, Map<String, DateTime> snapshot) {
          return metas.where((m) => snapshot[m.key.toString()] == null).toList();
        }

        final newApiConfigMetas = getNewMetas(apiConfigsToPush, apiConfigSnapshot);
        final newChatMetas = getNewMetas(chatsToPush, chatSnapshot);
        final newUserMetas = getNewMetas(usersToPush, userSnapshot);

        final (remoteApiConfigMetas, remoteChatMetas, remoteUserMetas) = await (
          apiConfigHandler.getRemoteMetas(localIds: newApiConfigMetas.map((m) => m.id).toList()),
          chatHandler.getRemoteMetas(localIds: newChatMetas.map((m) => m.id).toList()),
          userHandler.getRemoteMetas(localIds: newUserMetas.map((m) => m.id).toList()),
        ).wait;

        final userChanges = await userHandler.resolveConflicts(newUserMetas, remoteUserMetas);
        if (userChanges.isNotEmpty) debugPrint("Push conflict resolved for Users: $userChanges");
        final apiConfigIdChanges = await apiConfigHandler.resolveConflicts(newApiConfigMetas, remoteApiConfigMetas);
        if (apiConfigIdChanges.isNotEmpty) debugPrint("Push conflict resolved for ApiConfigs: $apiConfigIdChanges");
        final chatIdChanges = await chatHandler.resolveConflicts(newChatMetas, remoteChatMetas);
        if (chatIdChanges.isNotEmpty) debugPrint("Push conflict resolved for Chats: $chatIdChanges");

        // Apply ID changes to the complete "toPush" lists
        if (apiConfigIdChanges.isNotEmpty) _updateMetasInMemory(apiConfigsToPush, apiConfigIdChanges);
        if (chatIdChanges.isNotEmpty) _updateMetasInMemory(chatsToPush, chatIdChanges);
        // Note: user id changes are int->int, but sync meta uses uuid, so no update needed for user metas list

        final apiConfigsToPushIds = apiConfigsToPush.map((m) => m.id).toList();
        final chatsToPushIds = chatsToPush.map((m) => m.id).toList();
        final usersToPushIds = usersToPush.map((m) => m.id).toList();

        debugPrint("--- Sync Actions Summary (Push) ---");
        debugPrint("Users to push: ${usersToPushIds.length} IDs: $usersToPushIds");
        debugPrint("Users to delete: ${userKeysToDelete.length} Keys: $userKeysToDelete");
        debugPrint("ApiConfigs to push: ${apiConfigsToPushIds.length} IDs: $apiConfigsToPushIds");
        debugPrint("ApiConfigs to delete: ${apiConfigKeysToDelete.length} Keys: $apiConfigKeysToDelete");
        debugPrint("Chats to push: ${chatsToPushIds.length} IDs: $chatsToPushIds");
        debugPrint("Chats to delete: ${chatKeysToDelete.length} Keys: $chatKeysToDelete");
        debugPrint("------------------------------------");

        // Step 4: Execute deletions and pushes in a transaction
        await remoteConnection.execute('BEGIN');
        try {
          // Deletions first
          await userHandler.deleteRemotely(userKeysToDelete);
          await chatHandler.deleteRemotely(chatKeysToDelete);
          await apiConfigHandler.deleteRemotely(apiConfigKeysToDelete);

          // Then pushes in dependency order
          await userHandler.push(usersToPushIds);
          await apiConfigHandler.push(apiConfigsToPushIds);
          await chatHandler.push(chatsToPushIds);
          
          await remoteConnection.execute('COMMIT');

          // Step 5: Update snapshot on success
          await _updateSnapshotCache();
          debugPrint("Differential push completed and snapshot updated.");
          return true;
        } catch (e) {
          await remoteConnection.execute('ROLLBACK');
          debugPrint('Differential push failed during transaction: ${e.toString()}');
          return false;
        }
      } finally {
        await remoteConnection?.close();
      }
    } catch (e, s) {
      debugPrint('Differential push failed: ${e.toString()}\n${s.toString()}');
      return false;
    }
  }

  void _updateMetasInMemory(List<SyncMeta> metas, Map<dynamic, dynamic> changes) {
    for (int i = 0; i < metas.length; i++) {
      final meta = metas[i];
      if (changes.containsKey(meta.id)) {
        final newId = changes[meta.id];
        metas[i] = SyncMeta(
          id: newId,
          createdAt: meta.createdAt,
          updatedAt: meta.updatedAt, // Should be updated by the conflict resolution logic if needed
        );
      }
    }
  }
}
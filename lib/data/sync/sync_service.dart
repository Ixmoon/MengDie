import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';

import '../database/app_database.dart';
import '../../domain/enums.dart';
import '../../app/providers/settings_providers.dart';
import '../database/settings_service.dart';
import 'sync_meta.dart';
import 'handlers/base_sync_handler.dart';
import 'handlers/user_sync_handler.dart';
import 'handlers/api_config_sync_handler.dart';
import 'handlers/chat_sync_handler.dart';
import 'handlers/message_sync_handler.dart';

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
  Future<((List<SyncMeta>, List<SyncMeta>, List<SyncMeta>, List<SyncMeta>), (List<SyncMeta>, List<SyncMeta>, List<SyncMeta>, List<SyncMeta>))>
  _resolveChanges(
    Connection remoteConnection,
    (List<SyncMeta>, List<SyncMeta>, List<SyncMeta>, List<SyncMeta>) localData,
    (List<SyncMeta>, List<SyncMeta>, List<SyncMeta>, List<SyncMeta>) remoteData,
  ) async {
    var (localApiConfigMetas, localChatMetas, localMessageMetas, localUserMetas) = localData;
    final (remoteApiConfigMetas, remoteChatMetas, remoteMessageMetas, remoteUserMetas) = remoteData;

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
    final messageHandler = MessageSyncHandler(_db, remoteConnection);
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

    final conflictingMessageMetas = findConflictingMetas(localMessageMetas, remoteMessageMetas);
    if (conflictingMessageMetas.isNotEmpty) {
      debugPrint("Found ${conflictingMessageMetas.length} conflicting message metas: ${conflictingMessageMetas.map((m) => m.id).toList()}");
      final messageChanges = await messageHandler.resolveConflicts(conflictingMessageMetas, remoteMessageMetas);
      if (messageChanges.isNotEmpty) {
        _updateMetasInMemory(localMessageMetas, messageChanges);
        debugPrint("Message conflicts resolved with changes: $messageChanges");
      }
    }
    
    // Return the modified local data and original remote data
    return ((localApiConfigMetas, localChatMetas, localMessageMetas, localUserMetas), remoteData);
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
      // First, clean up any orphan messages on the remote to prevent sync errors.
      await _cleanupRemoteOrphanMessages(remoteConnection);
      
      final userId = SettingsService.instance.currentUserId;
      debugPrint('Syncing data for userId: $userId');

      final apiConfigHandler = ApiConfigSyncHandler(_db, remoteConnection, userId);
      final chatHandler = ChatSyncHandler(_db, remoteConnection);
      final messageHandler = MessageSyncHandler(_db, remoteConnection);
      final userHandler = UserSyncHandler(_db, remoteConnection);

      debugPrint("Fetching local and remote metadata...");
      final (localData, remoteData) = await (
        (
          apiConfigHandler.getLocalMetas(),
          chatHandler.getLocalMetas(),
          messageHandler.getLocalMetas(),
          userHandler.getLocalMetas(),
        ).wait,
        (
          apiConfigHandler.getRemoteMetas(),
          chatHandler.getRemoteMetas(),
          messageHandler.getRemoteMetas(),
          userHandler.getRemoteMetas(),
        ).wait
      ).wait;
      
      var (localApiConfigMetas, localChatMetas, localMessageMetas, localUserMetas) = localData;
      var (remoteApiConfigMetas, remoteChatMetas, remoteMessageMetas, remoteUserMetas) = remoteData;

      // --- Step 3: Optimization - Pre-check for changes before resolving conflicts ---
      final preCheckApiConfigActions = _computeSyncActions(localMetas: localApiConfigMetas, remoteMetas: remoteApiConfigMetas);
      final preCheckChatActions = _computeSyncActions(localMetas: localChatMetas, remoteMetas: remoteChatMetas);
      final preCheckMessageActions = _computeSyncActions(localMetas: localMessageMetas, remoteMetas: remoteMessageMetas);
      final preCheckUserActions = _computeSyncActions(localMetas: localUserMetas, remoteMetas: remoteUserMetas);

      if (preCheckApiConfigActions.toPull.isEmpty && preCheckApiConfigActions.toCreateLocally.isEmpty &&
          preCheckChatActions.toPull.isEmpty && preCheckChatActions.toCreateLocally.isEmpty &&
          preCheckMessageActions.toPull.isEmpty && preCheckMessageActions.toCreateLocally.isEmpty &&
          preCheckUserActions.toPull.isEmpty && preCheckUserActions.toCreateLocally.isEmpty) {
        debugPrint("No remote changes detected. Sync skipped.");
        await _updateSnapshotCache(localDataSource: localData, remoteDataSource: remoteData); // Still update snapshot to align timestamps if needed
        return;
      }

      // --- Step 4: Resolve ID Conflicts on differing items ---
      final ((resolvedLocalApiMetas, resolvedLocalChatMetas, resolvedLocalMessageMetas, resolvedLocalUserMetas),
             (resolvedRemoteApiConfigMetas, resolvedRemoteChatMetas, resolvedRemoteMessageMetas, resolvedRemoteUserMetas)) = await _resolveChanges(remoteConnection, localData, remoteData);

      // --- Step 5: Compute Actions with resolved data ---
      debugPrint("Computing synchronization actions...");
      final apiConfigActions = _computeSyncActions(localMetas: resolvedLocalApiMetas, remoteMetas: resolvedRemoteApiConfigMetas);
      final chatActions = _computeSyncActions(localMetas: resolvedLocalChatMetas, remoteMetas: resolvedRemoteChatMetas);
      final messageActions = _computeSyncActions(localMetas: resolvedLocalMessageMetas, remoteMetas: resolvedRemoteMessageMetas);
      final userActions = _computeSyncActions(localMetas: resolvedLocalUserMetas, remoteMetas: resolvedRemoteUserMetas);

      // --- Step 5: Execute Pulls ---
      final apiConfigIdsToPull = {...apiConfigActions.toPull, ...apiConfigActions.toCreateLocally}.toList();
      final chatIdsToPull = {...chatActions.toPull, ...chatActions.toCreateLocally}.toList();
      final messageIdsToPull = {...messageActions.toPull, ...messageActions.toCreateLocally}.toList();
      final userIdsToPull = {...userActions.toPull, ...userActions.toCreateLocally}.toList();
      
      debugPrint("--- Sync Actions Summary (Pull) ---");
      debugPrint("Users to pull: ${userIdsToPull.length} IDs: $userIdsToPull");
      debugPrint("ApiConfigs to pull: ${apiConfigIdsToPull.length} IDs: $apiConfigIdsToPull");
      debugPrint("Chats to pull: ${chatIdsToPull.length} IDs: $chatIdsToPull");
      debugPrint("Messages to pull: ${messageIdsToPull.length} IDs: $messageIdsToPull");
      debugPrint("------------------------------------");

      await _db.transaction(() async {
        await Future.wait([
          userHandler.pull(userIdsToPull),
          apiConfigHandler.pull(apiConfigIdsToPull),
          chatHandler.pull(chatIdsToPull),
          messageHandler.pull(messageIdsToPull),
        ]);
      });

      // --- Step 6: Update snapshot after successful pull ---
      await _updateSnapshotCache(
        localDataSource: (resolvedLocalApiMetas, resolvedLocalChatMetas, resolvedLocalMessageMetas, resolvedLocalUserMetas),
        remoteDataSource: (resolvedRemoteApiConfigMetas, resolvedRemoteChatMetas, resolvedRemoteMessageMetas, resolvedRemoteUserMetas));
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
    final tempMessageHandler = MessageSyncHandler(_db, null);
    final tempUserHandler = UserSyncHandler(_db, null);

    _snapshotCache = {
      tempApiConfigHandler.entityType: {},
      tempChatHandler.entityType: {},
      tempMessageHandler.entityType: {},
      tempUserHandler.entityType: {},
    };
    debugPrint("In-memory snapshot cache initialized.");
  }

  Future<void> _updateSnapshotCache({
    (List<SyncMeta>, List<SyncMeta>, List<SyncMeta>, List<SyncMeta>)? localDataSource,
    (List<SyncMeta>, List<SyncMeta>, List<SyncMeta>, List<SyncMeta>)? remoteDataSource,
  }) async {
    debugPrint("Updating in-memory snapshot cache...");
    final tempApiConfigHandler = ApiConfigSyncHandler(_db, null, SettingsService.instance.currentUserId);
    final tempChatHandler = ChatSyncHandler(_db, null);
    final tempMessageHandler = MessageSyncHandler(_db, null);
    final tempUserHandler = UserSyncHandler(_db, null);

    final Map<String, DateTime> apiConfigSnapshotData;
    final Map<String, DateTime> chatSnapshotData;
    final Map<String, DateTime> messageSnapshotData;
    final Map<String, DateTime> userSnapshotData;

    if (remoteDataSource != null) {
      // After a pull, the snapshot's keys should match the remote state.
      // For timestamps, use local if newer, otherwise use remote.
      final (remoteApiConfigMetas, remoteChatMetas, remoteMessageMetas, remoteUserMetas) = remoteDataSource;
      
      // OPTIMIZATION: Use provided local data if available, otherwise fetch it.
      final (localApiConfigMetas, localChatMetas, localMessageMetas, localUserMetas) = localDataSource ??
          await (
            tempApiConfigHandler.getLocalMetas(),
            tempChatHandler.getLocalMetas(),
            tempMessageHandler.getLocalMetas(),
            tempUserHandler.getLocalMetas(),
          ).wait;
      
      final localApiConfigMap = {for (var meta in localApiConfigMetas) meta.key: meta};
      final localChatMap = {for (var meta in localChatMetas) meta.key: meta};
      final localMessageMap = {for (var meta in localMessageMetas) meta.key: meta};
      final localUserMap = {for (var meta in localUserMetas) meta.key: meta};
      
      DateTime resolveTimestamp(SyncMeta remoteMeta, Map<dynamic, SyncMeta> localMap) {
        final localMeta = localMap[remoteMeta.key];
        // If local is newer than remote, use local timestamp.
        if (localMeta != null && localMeta.updatedAt.toUtc().isAfter(remoteMeta.updatedAt.toUtc())) {
          return localMeta.updatedAt.toUtc();
        }
        // Otherwise, use the remote timestamp.
        return remoteMeta.updatedAt.toUtc();
      }

      apiConfigSnapshotData = {for (var meta in remoteApiConfigMetas) meta.key.toString(): resolveTimestamp(meta, localApiConfigMap)};
      chatSnapshotData = {for (var meta in remoteChatMetas) meta.key.toString(): resolveTimestamp(meta, localChatMap)};
      messageSnapshotData = {for (var meta in remoteMessageMetas) meta.key.toString(): resolveTimestamp(meta, localMessageMap)};
      userSnapshotData = {for (var meta in remoteUserMetas) meta.key.toString(): resolveTimestamp(meta, localUserMap)};

    } else {
      // After a push, or when no remote data is provided, snapshot the current local state.
      final (apiConfigMetas, chatMetas, messageMetas, userMetas) = await (
        tempApiConfigHandler.getLocalMetas(),
        tempChatHandler.getLocalMetas(),
        tempMessageHandler.getLocalMetas(),
        tempUserHandler.getLocalMetas(),
      ).wait;
      apiConfigSnapshotData = {for (var meta in apiConfigMetas) meta.key.toString(): meta.updatedAt.toUtc()};
      chatSnapshotData = {for (var meta in chatMetas) meta.key.toString(): meta.updatedAt.toUtc()};
      messageSnapshotData = {for (var meta in messageMetas) meta.key.toString(): meta.updatedAt.toUtc()};
      userSnapshotData = {for (var meta in userMetas) meta.key.toString(): meta.updatedAt.toUtc()};
    }

    _snapshotCache = {
      tempApiConfigHandler.entityType: apiConfigSnapshotData,
      tempChatHandler.entityType: chatSnapshotData,
      tempMessageHandler.entityType: messageSnapshotData,
      tempUserHandler.entityType: userSnapshotData,
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
      final messageHandler = MessageSyncHandler(_db, remoteConnection);
      final userHandler = UserSyncHandler(_db, remoteConnection);

      debugPrint("Fetching local and remote metadata for merge...");
      final (localData, remoteData) = await (
        (
          apiConfigHandler.getLocalMetas(),
          chatHandler.getLocalMetas(),
          messageHandler.getLocalMetas(),
          userHandler.getLocalMetas(),
        ).wait,
        (
          apiConfigHandler.getRemoteMetas(),
          chatHandler.getRemoteMetas(),
          messageHandler.getRemoteMetas(),
          userHandler.getRemoteMetas(),
        ).wait,
      ).wait;
      
      var (localApiConfigMetas, localChatMetas, localMessageMetas, localUserMetas) = localData;
      var (remoteApiConfigMetas, remoteChatMetas, remoteMessageMetas, remoteUserMetas) = remoteData;

      // Optimization: Pre-check for changes before resolving conflicts
      final preCheckApiConfigActions = _computeMergeActions(localMetas: localApiConfigMetas, remoteMetas: remoteApiConfigMetas);
      final preCheckChatActions = _computeMergeActions(localMetas: localChatMetas, remoteMetas: remoteChatMetas);
      final preCheckMessageActions = _computeMergeActions(localMetas: localMessageMetas, remoteMetas: remoteMessageMetas);
      final preCheckUserActions = _computeMergeActions(localMetas: localUserMetas, remoteMetas: remoteUserMetas);

      if (preCheckApiConfigActions.toPull.isEmpty && preCheckApiConfigActions.toPush.isEmpty &&
          preCheckChatActions.toPull.isEmpty && preCheckChatActions.toPush.isEmpty &&
          preCheckMessageActions.toPull.isEmpty && preCheckMessageActions.toPush.isEmpty &&
          preCheckUserActions.toPull.isEmpty && preCheckUserActions.toPush.isEmpty) {
        debugPrint("No differences found between local and remote. Initial merge sync skipped.");
        await _updateSnapshotCache(); // Update snapshot to mark the sync as "done"
        return true;
      }
      
      final ((resolvedLocalApiMetas, resolvedLocalChatMetas, resolvedLocalMessageMetas, resolvedLocalUserMetas),
             (resolvedRemoteApiConfigMetas, resolvedRemoteChatMetas, resolvedRemoteMessageMetas, resolvedRemoteUserMetas)) = await _resolveChanges(remoteConnection, localData, remoteData);

      debugPrint("Computing merge actions...");
      final apiConfigActions = _computeMergeActions(localMetas: resolvedLocalApiMetas, remoteMetas: resolvedRemoteApiConfigMetas);
      final chatActions = _computeMergeActions(localMetas: resolvedLocalChatMetas, remoteMetas: resolvedRemoteChatMetas);
      final messageActions = _computeMergeActions(localMetas: resolvedLocalMessageMetas, remoteMetas: resolvedRemoteMessageMetas);
      final userActions = _computeMergeActions(localMetas: resolvedLocalUserMetas, remoteMetas: resolvedRemoteUserMetas);

      debugPrint("--- Sync Actions Summary (Merge) ---");
      debugPrint("Users to pull: ${userActions.toPull.length} IDs: ${userActions.toPull}");
      debugPrint("Users to push: ${userActions.toPush.length} IDs: ${userActions.toPush}");
      debugPrint("ApiConfigs to pull: ${apiConfigActions.toPull.length} IDs: ${apiConfigActions.toPull}");
      debugPrint("ApiConfigs to push: ${apiConfigActions.toPush.length} IDs: ${apiConfigActions.toPush}");
      debugPrint("Chats to pull: ${chatActions.toPull.length} IDs: ${chatActions.toPull}");
      debugPrint("Chats to push: ${chatActions.toPush.length} IDs: ${chatActions.toPush}");
      debugPrint("Messages to pull: ${messageActions.toPull.length} IDs: ${messageActions.toPull}");
      debugPrint("Messages to push: ${messageActions.toPush.length} IDs: ${messageActions.toPush}");
      debugPrint("------------------------------------");

      await remoteConnection.execute('BEGIN');
      try {
        // --- Execute Actions in Parallel within the same transaction ---
        // Pull operations
        await Future.wait([
          userHandler.pull(userActions.toPull),
          apiConfigHandler.pull(apiConfigActions.toPull),
          chatHandler.pull(chatActions.toPull),
          messageHandler.pull(messageActions.toPull),
        ]);

        // Push operations
        await Future.wait([
          userHandler.push(userActions.toPush),
          apiConfigHandler.push(apiConfigActions.toPush),
          chatHandler.push(chatActions.toPush),
          messageHandler.push(messageActions.toPush),
        ]);
        
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
    final tempMessageHandler = MessageSyncHandler(_db, null);
    final tempUserHandler = UserSyncHandler(_db, null);
    
    try {
      // Step 1: Fetch local metadata
      final (localApiConfigMetas, localChatMetas, localMessageMetas, localUserMetas) = await (
          tempApiConfigHandler.getLocalMetas(),
          tempChatHandler.getLocalMetas(),
          tempMessageHandler.getLocalMetas(),
          tempUserHandler.getLocalMetas(),
      ).wait;

      final apiConfigSnapshot = _snapshotCache![tempApiConfigHandler.entityType]!;
      final chatSnapshot = _snapshotCache![tempChatHandler.entityType]!;
      final messageSnapshot = _snapshotCache![tempMessageHandler.entityType]!;
      final userSnapshot = _snapshotCache![tempUserHandler.entityType]!;

      // Step 2: Compute differences
      debugPrint("[Differential Push] --- Message Diff Analysis ---");
      debugPrint("[Differential Push] Snapshot contains ${messageSnapshot.length} message keys.");
      debugPrint("[Differential Push] Local DB contains ${localMessageMetas.length} messages.");
      final messagesToPush = localMessageMetas.where((m) => messageSnapshot[m.key.toString()] == null || m.updatedAt.toUtc().isAfter(messageSnapshot[m.key.toString()]!)).toList();
      debugPrint("[Differential Push] Calculated ${messagesToPush.length} messages to push.");
      debugPrint("[Differential Push] -----------------------------");

      final apiConfigsToPush = localApiConfigMetas.where((m) => apiConfigSnapshot[m.key.toString()] == null || m.updatedAt.toUtc().isAfter(apiConfigSnapshot[m.key.toString()]!)).toList();
      final chatsToPush = localChatMetas.where((m) => chatSnapshot[m.key.toString()] == null || m.updatedAt.toUtc().isAfter(chatSnapshot[m.key.toString()]!)).toList();
      final usersToPush = localUserMetas.where((m) => userSnapshot[m.key.toString()] == null || m.updatedAt.toUtc().isAfter(userSnapshot[m.key.toString()]!)).toList();

      final localUserKeys = localUserMetas.map((m) => m.key.toString()).toSet();
      final localApiConfigKeys = localApiConfigMetas.map((m) => m.key.toString()).toSet();
      final localChatKeys = localChatMetas.map((m) => m.key.toString()).toSet();
      final localMessageKeys = localMessageMetas.map((m) => m.key.toString()).toSet();

      final userKeysToDelete = userSnapshot.keys.where((k) => !localUserKeys.contains(k)).toList();
      final apiConfigKeysToDelete = apiConfigSnapshot.keys.where((k) => !localApiConfigKeys.contains(k)).toList();
      final chatKeysToDelete = chatSnapshot.keys.where((k) => !localChatKeys.contains(k)).toList();
      final messageKeysToDelete = messageSnapshot.keys.where((k) => !localMessageKeys.contains(k)).toList();

      if (usersToPush.isEmpty && apiConfigsToPush.isEmpty && chatsToPush.isEmpty && messagesToPush.isEmpty &&
          userKeysToDelete.isEmpty && apiConfigKeysToDelete.isEmpty && chatKeysToDelete.isEmpty && messageKeysToDelete.isEmpty) {
        debugPrint("No local changes detected. Push skipped.");
        return true;
      }

      Connection? remoteConnection;
      try {
        remoteConnection = await _remoteConnectionFactory();
        final userId = SettingsService.instance.currentUserId;
        final apiConfigHandler = ApiConfigSyncHandler(_db, remoteConnection, userId);
        final chatHandler = ChatSyncHandler(_db, remoteConnection);
        final messageHandler = MessageSyncHandler(_db, remoteConnection);
        final userHandler = UserSyncHandler(_db, remoteConnection);

        // Step 3: Resolve conflicts for NEW items before pushing
        debugPrint("Checking for conflicts before push...");
        
        // Helper to filter for new metas
        List<SyncMeta> getNewMetas(List<SyncMeta> metas, Map<String, DateTime> snapshot) {
          return metas.where((m) => snapshot[m.key.toString()] == null).toList();
        }

        final newApiConfigMetas = getNewMetas(apiConfigsToPush, apiConfigSnapshot);
        final newChatMetas = getNewMetas(chatsToPush, chatSnapshot);
        final newMessageMetas = getNewMetas(messagesToPush, messageSnapshot);
        final newUserMetas = getNewMetas(usersToPush, userSnapshot);

        final (remoteApiConfigMetas, remoteChatMetas, remoteMessageMetas, remoteUserMetas) = await (
          apiConfigHandler.getRemoteMetas(localIds: newApiConfigMetas.map((m) => m.id).toList()),
          chatHandler.getRemoteMetas(localIds: newChatMetas.map((m) => m.id).toList()),
          messageHandler.getRemoteMetas(localIds: newMessageMetas.map((m) => m.id).toList()),
          userHandler.getRemoteMetas(localIds: newUserMetas.map((m) => m.id).toList()),
        ).wait;

        final userChanges = await userHandler.resolveConflicts(newUserMetas, remoteUserMetas);
        if (userChanges.isNotEmpty) debugPrint("Push conflict resolved for Users: $userChanges");
        final apiConfigIdChanges = await apiConfigHandler.resolveConflicts(newApiConfigMetas, remoteApiConfigMetas);
        if (apiConfigIdChanges.isNotEmpty) debugPrint("Push conflict resolved for ApiConfigs: $apiConfigIdChanges");
        final chatIdChanges = await chatHandler.resolveConflicts(newChatMetas, remoteChatMetas);
        if (chatIdChanges.isNotEmpty) debugPrint("Push conflict resolved for Chats: $chatIdChanges");
        final messageIdChanges = await messageHandler.resolveConflicts(newMessageMetas, remoteMessageMetas);
        if (messageIdChanges.isNotEmpty) debugPrint("Push conflict resolved for Messages: $messageIdChanges");

        // Apply ID changes to the complete "toPush" lists
        if (apiConfigIdChanges.isNotEmpty) _updateMetasInMemory(apiConfigsToPush, apiConfigIdChanges);
        if (chatIdChanges.isNotEmpty) _updateMetasInMemory(chatsToPush, chatIdChanges);
        if (messageIdChanges.isNotEmpty) _updateMetasInMemory(messagesToPush, messageIdChanges);
        // Note: user id changes are int->int, but sync meta uses uuid, so no update needed for user metas list

        final apiConfigsToPushIds = apiConfigsToPush.map((m) => m.id).toList();
        final chatsToPushIds = chatsToPush.map((m) => m.id).toList();
        final messagesToPushIds = messagesToPush.map((m) => m.id).toList();
        final usersToPushIds = usersToPush.map((m) => m.id).toList();

        debugPrint("--- Sync Actions Summary (Push) ---");
        debugPrint("Users to push: ${usersToPushIds.length} IDs: $usersToPushIds");
        debugPrint("Users to delete: ${userKeysToDelete.length} Keys: $userKeysToDelete");
        debugPrint("ApiConfigs to push: ${apiConfigsToPushIds.length} IDs: $apiConfigsToPushIds");
        debugPrint("ApiConfigs to delete: ${apiConfigKeysToDelete.length} Keys: $apiConfigKeysToDelete");
        debugPrint("Chats to push: ${chatsToPushIds.length} IDs: $chatsToPushIds");
        debugPrint("Chats to delete: ${chatKeysToDelete.length} Keys: $chatKeysToDelete");
        debugPrint("Messages to push: ${messagesToPushIds.length} IDs: $messagesToPushIds");
        debugPrint("Messages to delete: ${messageKeysToDelete.length} Keys: $messageKeysToDelete");
        debugPrint("------------------------------------");

        // Step 4: Execute deletions and pushes in a transaction
        await remoteConnection.execute('BEGIN');
        try {
          // Deletions first, in parallel.
          await Future.wait([
            messageHandler.deleteRemotely(messageKeysToDelete),
            chatHandler.deleteRemotely(chatKeysToDelete),
            apiConfigHandler.deleteRemotely(apiConfigKeysToDelete),
            userHandler.deleteRemotely(userKeysToDelete),
          ]);


          // Then pushes, in parallel.
          await Future.wait([
            userHandler.push(usersToPushIds),
            apiConfigHandler.push(apiConfigsToPushIds),
            chatHandler.push(chatsToPushIds),
            messageHandler.push(messagesToPushIds),
          ]);
          
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

  /// Deletes messages from the remote database that have a null chat_id or
  /// a chat_id that does not correspond to an existing chat.
  Future<void> _cleanupRemoteOrphanMessages(Connection remoteConnection) async {
    try {
      debugPrint("Cleaning up remote orphan messages...");
      
      // Delete messages where chat_id is explicitly NULL.
      // This is a safeguard for data that might have been created before the NOT NULL constraint was strictly enforced.
      final nullIdResult = await remoteConnection.execute(Sql('DELETE FROM messages WHERE chat_id IS NULL'));
      final nullIdCount = nullIdResult.affectedRows;
      if (nullIdCount > 0) {
        debugPrint("Deleted $nullIdCount messages with NULL chat_id.");
      }

      // With `ON DELETE CASCADE` in place, we no longer need to manually delete messages
      // where the chat_id is invalid, as deleting an orphan chat would cascade.
      // However, running this is a good practice to clean up any existing inconsistencies
      // that were created before the foreign key constraint was added.
      final invalidIdResult = await remoteConnection.execute(Sql('''
        DELETE FROM messages
        WHERE chat_id IS NOT NULL AND chat_id NOT IN (SELECT id FROM chats)
      '''));
      final invalidIdCount = invalidIdResult.affectedRows;

      if (invalidIdCount > 0) {
        debugPrint("Deleted $invalidIdCount messages with invalid chat_id.");
      }
      
      if (nullIdCount == 0 && invalidIdCount == 0) {
        debugPrint("No orphan messages found to clean up.");
      }
    } catch (e, s) {
      // Log the error but don't let it stop the entire sync process.
      // The main sync logic might still work if the orphan messages don't affect it.
      debugPrint('Error during remote orphan message cleanup: ${e.toString()}\n${s.toString()}');
    }
  }
}
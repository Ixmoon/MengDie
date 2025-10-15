import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:postgres/postgres.dart';

import '../database/app_database.dart';
import '../../app/providers/settings_providers.dart';
import '../database/settings_service.dart';
import 'sync_meta.dart';
import 'handlers/user_sync_handler.dart';
import 'handlers/api_config_sync_handler.dart';
import 'handlers/chat_sync_handler.dart';
import 'handlers/message_sync_handler.dart';
import '../../app/providers/core_providers.dart';
import '../../app/providers/repository_providers.dart';

/// A helper class to hold the results of a sync comparison.
class _SyncActions<T> {
  final List<T> toPull;
  final List<T> toCreateLocally;

  _SyncActions({this.toPull = const [], this.toCreateLocally = const []});
}

/// A helper class to hold the results of a two-way merge sync.
class _MergeActions<T> {
  final List<T> toPull;
  final List<T> toPush;

  _MergeActions({this.toPull = const [], this.toPush = const []});
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

  static void initialize(
    AppDatabase db,
    Future<Connection> Function() remoteConnectionFactory,
    ProviderContainer providerContainer,
  ) {
    if (_instance != null) return;
    _instance = SyncService._(remoteConnectionFactory, providerContainer)
      .._db = db;
  }

  static SyncService get instance {
    if (_instance == null) {
      throw Exception(
        "SyncService has not been initialized. Call SyncService.initialize() first.",
      );
    }
    return _instance!;
  }

  // Determines which items need to be pulled or created locally.
  _SyncActions<dynamic> _computeSyncActions({
    required List<SyncMeta> localMetas,
    required List<SyncMeta> remoteMetas,
  }) {
    final localMap = {for (var meta in localMetas) meta.key: meta};

    final toPull = <dynamic>[];
    final toCreateLocally = <dynamic>[];

    for (final remoteMeta in remoteMetas) {
      final localMeta = localMap[remoteMeta.key];
      if (localMeta == null) {
        toCreateLocally.add(remoteMeta.id);
      } else if (remoteMeta.updatedAt.toUtc().isAfter(
        localMeta.updatedAt.toUtc(),
      )) {
        toPull.add(remoteMeta.id);
      }
    }

    return _SyncActions(toPull: toPull, toCreateLocally: toCreateLocally);
  }
  
  // Helper to find conflicting metas (ID is the same, but createdAt is different)
  List<SyncMeta> _findConflictingMetas(
    List<SyncMeta> local,
    List<SyncMeta> remote,
  ) {
    // We use a composite key (id, createdAt) for this specific check
    dynamic getKey(SyncMeta meta) => (meta.id, meta.createdAt.toUtc());
    final remoteKeyMap = {for (var meta in remote) getKey(meta): meta};
    
    final conflicts = <SyncMeta>[];
    for (final localMeta in local) {
      final remoteMetaWithSameId = remote.where((rm) => rm.id == localMeta.id).firstOrNull;
      if (remoteMetaWithSameId != null && remoteMetaWithSameId.createdAt.toUtc() != localMeta.createdAt.toUtc()) {
        conflicts.add(localMeta);
      }
    }
    return conflicts;
  }

  Future<void> syncWithRemote() async {
    final syncSettings = _providerContainer.read(syncSettingsProvider);
    if (!syncSettings.isEnabled || syncSettings.connectionString.isEmpty) {
      return;
    }
    
    // 同步前清理
    await _providerContainer.read(chatRepositoryProvider).performSanityChecks();

    _providerContainer.read(isSyncingProvider.notifier).state = true;
    try {
      _initializeSnapshotCacheIfNeeded();

      Connection? remoteConnection;
      try {
        remoteConnection = await _remoteConnectionFactory();
        await _cleanupRemoteOrphanMessages(remoteConnection);

        final userId = SettingsService.instance.currentUserId;

        final apiConfigHandler = ApiConfigSyncHandler(
          _db,
          remoteConnection,
          userId,
        );
        final chatHandler = ChatSyncHandler(_db, remoteConnection, userId);
        final messageHandler = MessageSyncHandler(_db, remoteConnection, userId);
        final userHandler = UserSyncHandler(_db, remoteConnection);

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

        var (
          localApiConfigMetas,
          localChatMetas,
          localMessageMetas,
          localUserMetas,
        ) = localData;
        var (
          remoteApiConfigMetas,
          remoteChatMetas,
          remoteMessageMetas,
          remoteUserMetas,
        ) = remoteData;

        final preCheckApiConfigActions = _computeSyncActions(
          localMetas: localApiConfigMetas,
          remoteMetas: remoteApiConfigMetas,
        );
        final preCheckChatActions = _computeSyncActions(
          localMetas: localChatMetas,
          remoteMetas: remoteChatMetas,
        );
        final preCheckMessageActions = _computeSyncActions(
          localMetas: localMessageMetas,
          remoteMetas: remoteMessageMetas,
        );
        final preCheckUserActions = _computeSyncActions(
          localMetas: localUserMetas,
          remoteMetas: remoteUserMetas,
        );

        if (preCheckApiConfigActions.toPull.isEmpty &&
            preCheckApiConfigActions.toCreateLocally.isEmpty &&
            preCheckChatActions.toPull.isEmpty &&
            preCheckChatActions.toCreateLocally.isEmpty &&
            preCheckMessageActions.toPull.isEmpty &&
            preCheckMessageActions.toCreateLocally.isEmpty &&
            preCheckUserActions.toPull.isEmpty &&
            preCheckUserActions.toCreateLocally.isEmpty) {
          await _updateSnapshotCache(
            localDataSource: localData,
            remoteDataSource: remoteData,
          );
          return;
        }

        final apiConfigChanges = await apiConfigHandler.resolveConflicts(
            localApiConfigMetas, remoteApiConfigMetas);
        await userHandler.resolveConflicts(localUserMetas, remoteUserMetas);
        
        final conflictingChatMetas = _findConflictingMetas(localChatMetas, remoteChatMetas);
        final conflictingMessageMetas = _findConflictingMetas(localMessageMetas, remoteMessageMetas);
        
        final chatChanges =
            await chatHandler.resolveConflicts(conflictingChatMetas, remoteChatMetas);
        final messageChanges = await messageHandler.resolveConflicts(
            conflictingMessageMetas, remoteMessageMetas);
        
        _updateRemoteMetasInMemory(remoteApiConfigMetas, apiConfigChanges);
        _updateRemoteMetasInMemory(remoteChatMetas, chatChanges);
        _updateRemoteMetasInMemory(remoteMessageMetas, messageChanges);

        final apiConfigActions = _computeSyncActions(
          localMetas: localApiConfigMetas,
          remoteMetas: remoteApiConfigMetas,
        );
        final chatActions = _computeSyncActions(
          localMetas: localChatMetas,
          remoteMetas: remoteChatMetas,
        );
        final messageActions = _computeSyncActions(
          localMetas: localMessageMetas,
          remoteMetas: remoteMessageMetas,
        );
        final userActions = _computeSyncActions(
          localMetas: localUserMetas,
          remoteMetas: remoteUserMetas,
        );

        final apiConfigIdsToPull = {
          ...apiConfigActions.toPull,
          ...apiConfigActions.toCreateLocally,
        }.toList();
        final chatIdsToPull = {
          ...chatActions.toPull,
          ...chatActions.toCreateLocally,
        }.toList();
        final messageIdsToPull = {
          ...messageActions.toPull,
          ...messageActions.toCreateLocally,
        }.toList();
        final userIdsToPull = {
          ...userActions.toPull,
          ...userActions.toCreateLocally,
        }.toList();

        await _db.transaction(() async {
          await Future.wait([
            userHandler.pull(userIdsToPull),
            apiConfigHandler.pull(apiConfigIdsToPull),
            chatHandler.pull(chatIdsToPull),
            messageHandler.pull(messageIdsToPull),
          ]);
        });

        await _updateSnapshotCache(
          localDataSource: (
            localApiConfigMetas,
            localChatMetas,
            localMessageMetas,
            localUserMetas,
          ),
          remoteDataSource: (
            remoteApiConfigMetas,
            remoteChatMetas,
            remoteMessageMetas,
            remoteUserMetas,
          ),
        );
      } finally {
        await remoteConnection?.close();
      }
    } finally {
      _providerContainer.read(isSyncingProvider.notifier).state = false;
      // 在同步结束后触发一次清理检查
      await _providerContainer.read(chatRepositoryProvider).performSanityChecks();
    }
  }

  Future<bool> forcePushChanges() async {
    final syncSettings = _providerContainer.read(syncSettingsProvider);
    if (!syncSettings.isEnabled || syncSettings.connectionString.isEmpty) {
      return false;
    }

    // 同步前清理
    await _providerContainer.read(chatRepositoryProvider).performSanityChecks();

    _providerContainer.read(isSyncingProvider.notifier).state = true;
    try {
      _initializeSnapshotCacheIfNeeded();

      final isFirstSync = _snapshotCache!.values.every((map) => map.isEmpty);

      bool success;
      if (isFirstSync) {
        success = await _performInitialMergeSync();
      } else {
        success = await _performDifferentialPush();
      }
      return success;
    } finally {
      _providerContainer.read(isSyncingProvider.notifier).state = false;
      // 在同步结束后触发一次清理检查
      await _providerContainer.read(chatRepositoryProvider).performSanityChecks();
    }
  }

  void _initializeSnapshotCacheIfNeeded() {
    if (_snapshotCache != null) return;

    final tempApiConfigHandler = ApiConfigSyncHandler(
      _db,
      null,
      SettingsService.instance.currentUserId,
    );
    final tempChatHandler = ChatSyncHandler(
      _db,
      null,
      SettingsService.instance.currentUserId,
    );
    final tempMessageHandler = MessageSyncHandler(
      _db,
      null,
      SettingsService.instance.currentUserId,
    );
    final tempUserHandler = UserSyncHandler(_db, null);

    _snapshotCache = {
      tempApiConfigHandler.entityType: {},
      tempChatHandler.entityType: {},
      tempMessageHandler.entityType: {},
      tempUserHandler.entityType: {},
    };
  }

  Future<void> _updateSnapshotCache({
    (List<SyncMeta>, List<SyncMeta>, List<SyncMeta>, List<SyncMeta>)?
    localDataSource,
    (List<SyncMeta>, List<SyncMeta>, List<SyncMeta>, List<SyncMeta>)?
    remoteDataSource,
  }) async {
    final tempApiConfigHandler = ApiConfigSyncHandler(
      _db,
      null,
      SettingsService.instance.currentUserId,
    );
    final tempChatHandler = ChatSyncHandler(
      _db,
      null,
      SettingsService.instance.currentUserId,
    );
    final tempMessageHandler = MessageSyncHandler(
      _db,
      null,
      SettingsService.instance.currentUserId,
    );
    final tempUserHandler = UserSyncHandler(_db, null);

    final Map<String, DateTime> apiConfigSnapshotData;
    final Map<String, DateTime> chatSnapshotData;
    final Map<String, DateTime> messageSnapshotData;
    final Map<String, DateTime> userSnapshotData;

    if (remoteDataSource != null) {
      final (
        remoteApiConfigMetas,
        remoteChatMetas,
        remoteMessageMetas,
        remoteUserMetas,
      ) = remoteDataSource;

      final (
        localApiConfigMetas,
        localChatMetas,
        localMessageMetas,
        localUserMetas,
      ) = localDataSource ??
          await (
            tempApiConfigHandler.getLocalMetas(),
            tempChatHandler.getLocalMetas(),
            tempMessageHandler.getLocalMetas(),
            tempUserHandler.getLocalMetas(),
          ).wait;

      final localApiConfigMap = {
        for (var meta in localApiConfigMetas) meta.key: meta,
      };
      final localChatMap = {for (var meta in localChatMetas) meta.key: meta};
      final localMessageMap = {
        for (var meta in localMessageMetas) meta.key: meta,
      };
      final localUserMap = {for (var meta in localUserMetas) meta.key: meta};

      DateTime resolveTimestamp(
        SyncMeta remoteMeta,
        Map<dynamic, SyncMeta> localMap,
      ) {
        final localMeta = localMap[remoteMeta.key];
        if (localMeta != null &&
            localMeta.updatedAt.toUtc().isAfter(remoteMeta.updatedAt.toUtc())) {
          return localMeta.updatedAt.toUtc();
        }
        return remoteMeta.updatedAt.toUtc();
      }

      apiConfigSnapshotData = {
        for (var meta in remoteApiConfigMetas)
          meta.key.toString(): resolveTimestamp(meta, localApiConfigMap),
      };
      chatSnapshotData = {
        for (var meta in remoteChatMetas)
          meta.key.toString(): resolveTimestamp(meta, localChatMap),
      };
      messageSnapshotData = {
        for (var meta in remoteMessageMetas)
          meta.key.toString(): resolveTimestamp(meta, localMessageMap),
      };
      userSnapshotData = {
        for (var meta in remoteUserMetas)
          meta.key.toString(): resolveTimestamp(meta, localUserMap),
      };
    } else {
      final (apiConfigMetas, chatMetas, messageMetas, userMetas) = await (
        tempApiConfigHandler.getLocalMetas(),
        tempChatHandler.getLocalMetas(),
        tempMessageHandler.getLocalMetas(),
        tempUserHandler.getLocalMetas(),
      ).wait;
      apiConfigSnapshotData = {
        for (var meta in apiConfigMetas)
          meta.key.toString(): meta.updatedAt.toUtc(),
      };
      chatSnapshotData = {
        for (var meta in chatMetas) meta.key.toString(): meta.updatedAt.toUtc(),
      };
      messageSnapshotData = {
        for (var meta in messageMetas)
          meta.key.toString(): meta.updatedAt.toUtc(),
      };
      userSnapshotData = {
        for (var meta in userMetas) meta.key.toString(): meta.updatedAt.toUtc(),
      };
    }

    _snapshotCache = {
      tempApiConfigHandler.entityType: apiConfigSnapshotData,
      tempChatHandler.entityType: chatSnapshotData,
      tempMessageHandler.entityType: messageSnapshotData,
      tempUserHandler.entityType: userSnapshotData,
    };
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
        } else if (localMeta.updatedAt.toUtc().isAfter(
          remoteMeta.updatedAt.toUtc(),
        )) {
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

      final apiConfigHandler = ApiConfigSyncHandler(
        _db,
        remoteConnection,
        userId,
      );
      final chatHandler = ChatSyncHandler(_db, remoteConnection, userId);
      final messageHandler = MessageSyncHandler(_db, remoteConnection, userId);
      final userHandler = UserSyncHandler(_db, remoteConnection);

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

      var (
        localApiConfigMetas,
        localChatMetas,
        localMessageMetas,
        localUserMetas,
      ) = localData;
      var (
        remoteApiConfigMetas,
        remoteChatMetas,
        remoteMessageMetas,
        remoteUserMetas,
      ) = remoteData;

      final preCheckApiConfigActions = _computeMergeActions(
        localMetas: localApiConfigMetas,
        remoteMetas: remoteApiConfigMetas,
      );
      final preCheckChatActions = _computeMergeActions(
        localMetas: localChatMetas,
        remoteMetas: remoteChatMetas,
      );
      final preCheckMessageActions = _computeMergeActions(
        localMetas: localMessageMetas,
        remoteMetas: remoteMessageMetas,
      );
      final preCheckUserActions = _computeMergeActions(
        localMetas: localUserMetas,
        remoteMetas: remoteUserMetas,
      );

      if (preCheckApiConfigActions.toPull.isEmpty &&
          preCheckApiConfigActions.toPush.isEmpty &&
          preCheckChatActions.toPull.isEmpty &&
          preCheckChatActions.toPush.isEmpty &&
          preCheckMessageActions.toPull.isEmpty &&
          preCheckMessageActions.toPush.isEmpty &&
          preCheckUserActions.toPull.isEmpty &&
          preCheckUserActions.toPush.isEmpty) {
        await _updateSnapshotCache();
        return true;
      }

      final apiConfigChanges = await apiConfigHandler.resolveConflicts(
          localApiConfigMetas, remoteApiConfigMetas);
      await userHandler.resolveConflicts(localUserMetas, remoteUserMetas);
      
      final conflictingChatMetas = _findConflictingMetas(localChatMetas, remoteChatMetas);
      final conflictingMessageMetas = _findConflictingMetas(localMessageMetas, remoteMessageMetas);

      final chatChanges =
          await chatHandler.resolveConflicts(conflictingChatMetas, remoteChatMetas);
      final messageChanges = await messageHandler.resolveConflicts(
          conflictingMessageMetas, remoteMessageMetas);

      _updateRemoteMetasInMemory(remoteApiConfigMetas, apiConfigChanges);
      _updateRemoteMetasInMemory(remoteChatMetas, chatChanges);
      _updateRemoteMetasInMemory(remoteMessageMetas, messageChanges);

      final apiConfigActions = _computeMergeActions(
        localMetas: localApiConfigMetas,
        remoteMetas: remoteApiConfigMetas,
      );
      final chatActions = _computeMergeActions(
        localMetas: localChatMetas,
        remoteMetas: remoteChatMetas,
      );
      final messageActions = _computeMergeActions(
        localMetas: localMessageMetas,
        remoteMetas: remoteMessageMetas,
      );
      final userActions = _computeMergeActions(
        localMetas: localUserMetas,
        remoteMetas: remoteUserMetas,
      );

      await remoteConnection.execute('BEGIN');
      try {
        await Future.wait([
          userHandler.pull(userActions.toPull),
          apiConfigHandler.pull(apiConfigActions.toPull),
          chatHandler.pull(chatActions.toPull),
          messageHandler.pull(messageActions.toPull),
        ]);

        await Future.wait([
          userHandler.push(userActions.toPush),
          apiConfigHandler.push(apiConfigActions.toPush),
          chatHandler.push(chatActions.toPush),
          messageHandler.push(messageActions.toPush),
        ]);

        await remoteConnection.execute('COMMIT');

        await _updateSnapshotCache();
        return true;
      } catch (e) {
        await remoteConnection.execute('ROLLBACK');
        return false;
      }
    } catch (e) {
      return false;
    } finally {
      await remoteConnection?.close();
    }
  }

  Future<bool> _performDifferentialPush() async {
    final tempApiConfigHandler = ApiConfigSyncHandler(
      _db,
      null,
      SettingsService.instance.currentUserId,
    );
    final tempChatHandler = ChatSyncHandler(
      _db,
      null,
      SettingsService.instance.currentUserId,
    );
    final tempMessageHandler = MessageSyncHandler(
      _db,
      null,
      SettingsService.instance.currentUserId,
    );
    final tempUserHandler = UserSyncHandler(_db, null);

    try {
      final (
        localApiConfigMetas,
        localChatMetas,
        localMessageMetas,
        localUserMetas,
      ) = await (
        tempApiConfigHandler.getLocalMetas(),
        tempChatHandler.getLocalMetas(),
        tempMessageHandler.getLocalMetas(),
        tempUserHandler.getLocalMetas(),
      ).wait;

      final apiConfigSnapshot =
          _snapshotCache![tempApiConfigHandler.entityType]!;
      final chatSnapshot = _snapshotCache![tempChatHandler.entityType]!;
      final messageSnapshot = _snapshotCache![tempMessageHandler.entityType]!;
      final userSnapshot = _snapshotCache![tempUserHandler.entityType]!;

      final messagesToPush = localMessageMetas
          .where(
            (m) =>
                messageSnapshot[m.key.toString()] == null ||
                m.updatedAt.toUtc().isAfter(messageSnapshot[m.key.toString()]!),
          )
          .toList();

      final apiConfigsToPush = localApiConfigMetas
          .where(
            (m) =>
                apiConfigSnapshot[m.key.toString()] == null ||
                m.updatedAt.toUtc().isAfter(
                  apiConfigSnapshot[m.key.toString()]!,
                ),
          )
          .toList();
      final chatsToPush = localChatMetas
          .where(
            (m) =>
                chatSnapshot[m.key.toString()] == null ||
                m.updatedAt.toUtc().isAfter(chatSnapshot[m.key.toString()]!),
          )
          .toList();
      final usersToPush = localUserMetas
          .where(
            (m) =>
                userSnapshot[m.key.toString()] == null ||
                m.updatedAt.toUtc().isAfter(userSnapshot[m.key.toString()]!),
          )
          .toList();

      final localUserKeys = localUserMetas.map((m) => m.key.toString()).toSet();
      final localApiConfigKeys = localApiConfigMetas
          .map((m) => m.key.toString())
          .toSet();
      final localChatKeys = localChatMetas.map((m) => m.key.toString()).toSet();
      final localMessageKeys = localMessageMetas
          .map((m) => m.key.toString())
          .toSet();

      final userKeysToDelete = userSnapshot.keys
          .where((k) => !localUserKeys.contains(k))
          .toList();
      final apiConfigKeysToDelete = apiConfigSnapshot.keys
          .where((k) => !localApiConfigKeys.contains(k))
          .toList();
      final chatKeysToDelete = chatSnapshot.keys
          .where((k) => !localChatKeys.contains(k))
          .toList();
      final messageKeysToDelete = messageSnapshot.keys
          .where((k) => !localMessageKeys.contains(k))
          .toList();

      if (usersToPush.isEmpty &&
          apiConfigsToPush.isEmpty &&
          chatsToPush.isEmpty &&
          messagesToPush.isEmpty &&
          userKeysToDelete.isEmpty &&
          apiConfigKeysToDelete.isEmpty &&
          chatKeysToDelete.isEmpty &&
          messageKeysToDelete.isEmpty) {
        return true;
      }

      Connection? remoteConnection;
      try {
        remoteConnection = await _remoteConnectionFactory();
        final userId = SettingsService.instance.currentUserId;
        final apiConfigHandler = ApiConfigSyncHandler(
          _db,
          remoteConnection,
          userId,
        );
        final chatHandler = ChatSyncHandler(_db, remoteConnection, userId);
        final messageHandler = MessageSyncHandler(
          _db,
          remoteConnection,
          userId,
        );
        final userHandler = UserSyncHandler(_db, remoteConnection);

        List<SyncMeta> getNewMetas(
          List<SyncMeta> metas,
          Map<String, DateTime> snapshot,
        ) {
          return metas
              .where((m) => snapshot[m.key.toString()] == null)
              .toList();
        }

        final newApiConfigMetas = getNewMetas(
          apiConfigsToPush,
          apiConfigSnapshot,
        );
        final newChatMetas = getNewMetas(chatsToPush, chatSnapshot);
        final newMessageMetas = getNewMetas(messagesToPush, messageSnapshot);
        final newUserMetas = getNewMetas(usersToPush, userSnapshot);

        // This block is now removed. Conflict resolution for chats and messages
        // is handled on the remote side, and it's triggered by the push operation itself
        // if a conflict is detected. The logic inside the handlers is correct.
        // The previous implementation was flawed because it tried to resolve conflicts
        // before the push, and incorrectly updated local metadata.
        // By removing this, we allow the push operation's ON CONFLICT clause (for updates)
        // and the handler's remote conflict resolution (for ID clashes) to work as intended.

        final apiConfigsToPushIds = apiConfigsToPush.map((m) => m.id).toList();
        final chatsToPushIds = chatsToPush.map((m) => m.id).toList();
        final messagesToPushIds = messagesToPush.map((m) => m.id).toList();
        final usersToPushIds = usersToPush.map((m) => m.id).toList();

        await remoteConnection.execute('BEGIN');
        try {
          await Future.wait([
            messageHandler.deleteRemotely(messageKeysToDelete),
            chatHandler.deleteRemotely(chatKeysToDelete),
            apiConfigHandler.deleteRemotely(apiConfigKeysToDelete),
            userHandler.deleteRemotely(userKeysToDelete),
          ]);

          await Future.wait([
            userHandler.push(usersToPushIds),
            apiConfigHandler.push(apiConfigsToPushIds),
            chatHandler.push(chatsToPushIds),
            messageHandler.push(messagesToPushIds),
          ]);

          await remoteConnection.execute('COMMIT');

          await _updateSnapshotCache();
          return true;
        } catch (e) {
          await remoteConnection.execute('ROLLBACK');
          return false;
        }
      } finally {
        await remoteConnection?.close();
      }
    } catch (e) {
      return false;
    }
  }

  void _updateMetasInMemory(
    List<SyncMeta> metas,
    Map<dynamic, dynamic> changes,
  ) {
    for (int i = 0; i < metas.length; i++) {
      final meta = metas[i];
      if (changes.containsKey(meta.id)) {
        final newId = changes[meta.id];
        metas[i] = SyncMeta(
          id: newId,
          createdAt: meta.createdAt,
          updatedAt: meta
              .updatedAt,
        );
      }
    }
  }

  void _updateRemoteMetasInMemory(
    List<SyncMeta> remoteMetas,
    Map<dynamic, dynamic> changes,
  ) {
    for (int i = 0; i < remoteMetas.length; i++) {
      final meta = remoteMetas[i];
      if (changes.containsKey(meta.id)) {
        final newId = changes[meta.id];
        remoteMetas[i] = SyncMeta(
          id: newId,
          createdAt: meta.createdAt,
          updatedAt: meta.updatedAt,
        );
      }
    }
  }

  Future<void> _cleanupRemoteOrphanMessages(Connection remoteConnection) async {
    try {
      await remoteConnection.execute(
        Sql('DELETE FROM messages WHERE chat_id IS NULL'),
      );

      await remoteConnection.execute(
        Sql('''
        DELETE FROM messages
        WHERE chat_id IS NOT NULL AND chat_id NOT IN (SELECT id FROM chats)
      '''),
      );
    } catch (e) {
      // Log the error but don't let it stop the entire sync process.
    }
  }

  Future<void> syncAllUsers() async {
    final syncSettings = _providerContainer.read(syncSettingsProvider);
    if (!syncSettings.isEnabled || syncSettings.connectionString.isEmpty) {
      return;
    }
    
    // 同步前清理
    await _providerContainer.read(chatRepositoryProvider).performSanityChecks();

    _providerContainer.read(isSyncingProvider.notifier).state = true;
    try {
      Connection? remoteConnection;
      try {
        remoteConnection = await _remoteConnectionFactory();
        final userHandler = UserSyncHandler(_db, remoteConnection);

        final localMetas = await userHandler.getLocalMetas();
        final remoteMetas = await userHandler.getRemoteMetas();

        final actions = _computeSyncActions(
          localMetas: localMetas,
          remoteMetas: remoteMetas,
        );
        final userIdsToPull = {
          ...actions.toPull,
          ...actions.toCreateLocally,
        }.toList();

        if (userIdsToPull.isEmpty) {
          return;
        }

        await userHandler.pull(userIdsToPull);
      } catch (e) {
        rethrow;
      } finally {
        await remoteConnection?.close();
      }
    } finally {
      _providerContainer.read(isSyncingProvider.notifier).state = false;
      await _providerContainer.read(chatRepositoryProvider).performSanityChecks();
    }
  }
}

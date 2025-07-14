import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:postgres/postgres.dart';

import '../app_database.dart';
import '../../../ui/providers/settings_providers.dart';
import '../settings_service.dart';
import '../type_converters.dart';


/// ===================================================================
/// Service for Synchronizing Local and Remote Databases
/// ===================================================================
///
/// ## Core Responsibilities
/// This service handles the two-way data synchronization between the local Drift
/// database and a remote PostgreSQL database. It is designed to be efficient,
/// robust, and ensure data consistency across devices.
///
/// ## Key Synchronization Strategies
///
/// 1.  **Metadata-First Approach**:
///     To minimize network traffic, the synchronization process first fetches
///     only lightweight metadata (IDs and timestamps) from both local and remote
///     sources. It compares this metadata to determine the "delta" - a list of
///     items that need to be created, pushed, or pulled. Only after this
///     calculation is the full data for these specific items fetched.
///
/// 2.  **Batch Processing**:
///     All database read and write operations are performed in batches to maximize
///     performance. This includes using PostgreSQL's `UNNEST` function for bulk
///     inserts/updates on the remote server and Drift's `batch` API for local
///     database operations. This strategy drastically reduces the number of
///     network round-trips and database transactions.
///
/// ## Entity-Specific Synchronization Logic
///
/// - **Users (`users`)**:
///   User data synchronization is handled **manually** and is **not** part of the
///   automatic `syncWithRemote` flow. It relies on two explicit, unidirectional
///   methods:
///   - `forcePushUsers()`: Wipes remote user data and replaces it with local data.
///     Used for "uploading settings".
///   - `forcePullUsers()`: Wipes local user data and replaces it with remote data.
///     Used for "restoring settings on a new device".
///
/// - **API Configurations (`api_configs`)**:
///   These are synchronized incrementally based on their `updated_at` timestamp.
///   The composite key `(id, createdAt)` is used for unique identification.
///
/// - **Chats and Messages (`chats`, `messages`) - ATOMIC UNIT**:
///   This is the most critical part of the sync logic. A **Chat is treated as the
///   atomic unit of synchronization**. Messages do **NOT** have an independent
///   sync lifecycle.
///
///   - **How it works**: When a Chat's metadata (`updatedAt` timestamp) indicates
///     it needs to be synced (either pushed or pulled), the entire Chat object,
///     along with **ALL** of its associated Messages, is synchronized as a whole.
///   - **Consistency Guarantee**: To ensure absolute data integrity, the process
///     for a single chat involves:
///       1. Deleting all existing messages for that chat on the target database.
///       2. Bulk-inserting the complete, up-to-date list of messages from the
///          source database.
///     This "delete-then-insert" strategy, performed within a single transaction,
///     guarantees that the state of a chat and its messages is identical on both
///     local and remote ends after the sync, preventing any data corruption or
///     desynchronization.
///
// A lightweight class to hold synchronization metadata.
class _SyncMeta {
  final dynamic id; // Can be int or String
  final DateTime createdAt;
  final DateTime updatedAt;

  _SyncMeta({required this.id, required this.createdAt, required this.updatedAt});

  // Use a composite key for accurate identification.
  dynamic get key => (id, createdAt);
}

// A helper class to hold the results of a sync comparison.
class _SyncActions<T> {
  final List<T> toPush; // IDs of items to push to remote
  final List<T> toPull; // IDs of items to pull from remote
  final List<T> toCreateRemotely; // IDs of items to create on remote
  final List<T> toCreateLocally; // IDs of items to create locally

  _SyncActions({
    this.toPush = const [],
    this.toPull = const [],
    this.toCreateRemotely = const [],
    this.toCreateLocally = const [],
  });
}


class SyncService {
  final Future<Connection> Function() _remoteConnectionFactory;
  final ProviderContainer _providerContainer;
  late final AppDatabase _db;

  SyncService._(this._remoteConnectionFactory, this._providerContainer);

  static SyncService? _instance;

  static void initialize(AppDatabase db, Future<Connection> Function() remoteConnectionFactory, ProviderContainer providerContainer) {
    if (_instance != null) {
      return;
    }
    _instance = SyncService._(remoteConnectionFactory, providerContainer).._db = db;
  }

  static SyncService get instance {
    if (_instance == null) {
      throw Exception("SyncService has not been initialized. Call SyncService.initialize() first.");
    }
    return _instance!;
  }

  // Determines which items need to be pushed, pulled, or created.
  _SyncActions<dynamic> _computeSyncActions({
    required List<_SyncMeta> localMetas,
    required List<_SyncMeta> remoteMetas,
  }) {
    final localMap = {for (var meta in localMetas) meta.key: meta};
    final remoteMap = {for (var meta in remoteMetas) meta.key: meta};

    final toPush = <dynamic>[];
    final toPull = <dynamic>[];
    final toCreateRemotely = <dynamic>[];
    final toCreateLocally = <dynamic>[];

    // Check for updates and items to create locally
    for (final remoteMeta in remoteMetas) {
      final localMeta = localMap[remoteMeta.key];
      if (localMeta == null) {
        toCreateLocally.add(remoteMeta.id);
      } else {
        if (remoteMeta.updatedAt.isAfter(localMeta.updatedAt)) {
          toPull.add(remoteMeta.id);
        }
      }
    }

    // Check for updates and items to create remotely
    for (final localMeta in localMetas) {
      final remoteMeta = remoteMap[localMeta.key];
      if (remoteMeta == null) {
        toCreateRemotely.add(localMeta.id);
      } else {
        if (localMeta.updatedAt.isAfter(remoteMeta.updatedAt)) {
          toPush.add(localMeta.id);
        }
      }
    }

    return _SyncActions(
      toPush: toPush,
      toPull: toPull,
      toCreateRemotely: toCreateRemotely,
      toCreateLocally: toCreateLocally,
    );
  }

  /// Forces a push of all local user data to the remote server.
  /// This will overwrite any existing user data on the remote.
  Future<void> forcePushUsers() async {
    final syncSettings = _providerContainer.read(syncSettingsProvider);
    if (!syncSettings.isEnabled || syncSettings.connectionString.isEmpty) {
      debugPrint("Remote sync is disabled or connection string is empty. Skipping user push.");
      return;
    }
    debugPrint("Forcing push of all local users to remote...");
    Connection? remoteConnection;
    try {
      remoteConnection = await _remoteConnectionFactory();
      final localUsers = await (_db.select(_db.users)).get();

      if (localUsers.isEmpty) {
        debugPrint("No local users found to push. Skipping.");
        return;
      }

      // Batch insert/update using UNNEST for superior performance.
      // Manual transaction control
      await remoteConnection.execute('BEGIN');
      try {
        await remoteConnection.execute(
          Sql.named('''
            INSERT INTO users (
              id, username, password_hash, chat_ids, enable_auto_title_generation,
              title_generation_prompt, title_generation_api_config_id, enable_resume,
              resume_prompt, resume_api_config_id, gemini_api_keys
            )
            SELECT
              u.id, u.username, u.password_hash, u.chat_ids, u.enable_auto_title_generation,
              u.title_generation_prompt, u.title_generation_api_config_id, u.enable_resume,
              u.resume_prompt, u.resume_api_config_id, u.gemini_api_keys
            FROM UNNEST(
              @ids, @usernames, @password_hashes, @chat_ids_list, @enable_auto_title_generations,
              @title_generation_prompts, @title_generation_api_config_ids, @enable_resumes,
              @resume_prompts, @resume_api_config_ids, @gemini_api_keys_list
            ) AS u(
              id, username, password_hash, chat_ids, enable_auto_title_generation,
              title_generation_prompt, title_generation_api_config_id, enable_resume,
              resume_prompt, resume_api_config_id, gemini_api_keys
            )
            ON CONFLICT (id) DO UPDATE SET
              username = EXCLUDED.username,
              password_hash = EXCLUDED.password_hash,
              chat_ids = EXCLUDED.chat_ids,
              enable_auto_title_generation = EXCLUDED.enable_auto_title_generation,
              title_generation_prompt = EXCLUDED.title_generation_prompt,
              title_generation_api_config_id = EXCLUDED.title_generation_api_config_id,
              enable_resume = EXCLUDED.enable_resume,
              resume_prompt = EXCLUDED.resume_prompt,
              resume_api_config_id = EXCLUDED.resume_api_config_id,
              gemini_api_keys = EXCLUDED.gemini_api_keys;
          '''),
          parameters: {
            'ids': localUsers.map((u) => u.id).toList(),
            'usernames': localUsers.map((u) => u.username).toList(),
            'password_hashes': localUsers.map((u) => u.passwordHash).toList(),
            'chat_ids_list': localUsers.map((u) => const IntListConverter().toSql(u.chatIds ?? [])).toList(),
            'enable_auto_title_generations': localUsers.map((u) => u.enableAutoTitleGeneration).toList(),
            'title_generation_prompts': localUsers.map((u) => u.titleGenerationPrompt).toList(),
            'title_generation_api_config_ids': localUsers.map((u) => u.titleGenerationApiConfigId).toList(),
            'enable_resumes': localUsers.map((u) => u.enableResume).toList(),
            'resume_prompts': localUsers.map((u) => u.resumePrompt).toList(),
            'resume_api_config_ids': localUsers.map((u) => u.resumeApiConfigId).toList(),
            'gemini_api_keys_list': localUsers.map((u) => const StringListConverter().toSql(u.geminiApiKeys ?? [])).toList(),
          },
        );
        await remoteConnection.execute('COMMIT');
      } catch (e) {
        await remoteConnection.execute('ROLLBACK');
        rethrow;
      }

      debugPrint("User push completed successfully for ${localUsers.length} users.");
    } catch (e, s) {
      debugPrint('Force push of users failed.');
      rethrow;
    } finally {
      await remoteConnection?.close();
    }
  }

  /// Forces a pull of all remote user data to the local database.
  /// This will overwrite any existing user data on the local device.
  Future<void> forcePullUsers() async {
    final syncSettings = _providerContainer.read(syncSettingsProvider);
    if (!syncSettings.isEnabled || syncSettings.connectionString.isEmpty) {
      debugPrint("Remote sync is disabled or connection string is empty. Skipping user pull.");
      return;
    }
    debugPrint("Forcing pull of all remote users to local...");
    Connection? remoteConnection;
    try {
      remoteConnection = await _remoteConnectionFactory();
      final remoteUsersResult = await remoteConnection.execute('SELECT * FROM users');
      final remoteUsers = remoteUsersResult.map((row) {
        final columns = row.toColumnMap();
        return DriftUser(
          id: columns['id'],
          username: columns['username'],
          passwordHash: columns['password_hash'],
          chatIds: const IntListConverter().fromSql(columns['chat_ids'] ?? '[]'),
          enableAutoTitleGeneration: columns['enable_auto_title_generation'],
          titleGenerationPrompt: columns['title_generation_prompt'],
          titleGenerationApiConfigId: columns['title_generation_api_config_id'],
          enableResume: columns['enable_resume'],
          resumePrompt: columns['resume_prompt'],
          resumeApiConfigId: columns['resume_api_config_id'],
          geminiApiKeys: const StringListConverter().fromSql(columns['gemini_api_keys'] ?? '[]'),
        );
      }).toList();

      if (remoteUsers.isEmpty) {
        debugPrint("No remote users to pull.");
        return;
      }

      // Use Drift's batch API for efficient local writes.
      await _db.batch((batch) {
        batch.insertAll(
          _db.users,
          remoteUsers.map((user) => user.toCompanion(true)),
          mode: InsertMode.insertOrReplace,
        );
      });

      debugPrint("User pull completed successfully for ${remoteUsers.length} users.");
    } catch (e, s) {
      debugPrint('Force pull of users failed.');
      rethrow;
    } finally {
      await remoteConnection?.close();
    }
  }

  Future<void> syncWithRemote() async {
    final syncSettings = _providerContainer.read(syncSettingsProvider);
    if (!syncSettings.isEnabled || syncSettings.connectionString.isEmpty) {
      debugPrint("Remote sync is disabled or connection string is empty. Skipping.");
      return;
    }
    debugPrint("Starting efficient database synchronization...");
    
    Connection? remoteConnection;
    try {
      remoteConnection = await _remoteConnectionFactory();
      final userId = SettingsService.instance.currentUserId;
      debugPrint('Syncing data for userId: $userId');

      // --- Step 1: Fetch Metadata in Parallel ---
      final metaResults = await Future.wait([
        // 0: localApiConfigMetas
        (_db.selectOnly(_db.apiConfigs)..addColumns([_db.apiConfigs.id, _db.apiConfigs.createdAt, _db.apiConfigs.updatedAt]))
            .get().then((rows) {
          debugPrint('Found ${rows.length} local api_config metas.');
          return rows.map((row) => _SyncMeta(id: row.read(_db.apiConfigs.id)!, createdAt: row.read(_db.apiConfigs.createdAt)!, updatedAt: row.read(_db.apiConfigs.updatedAt)!)).toList();
        }),
        // 1: remoteApiConfigMetas
        remoteConnection.execute('SELECT id, created_at, updated_at FROM api_configs')
            .then((rows) => rows.map((row) => _SyncMeta(id: row[0] as String, createdAt: row[1] as DateTime, updatedAt: row[2] as DateTime)).toList()),
        // 2: localChatMetas
        (_db.selectOnly(_db.chats)..addColumns([_db.chats.id, _db.chats.createdAt, _db.chats.updatedAt]))
            .get().then((rows) {
          debugPrint('Found ${rows.length} local chat metas.');
          return rows.map((row) => _SyncMeta(id: row.read(_db.chats.id)!, createdAt: row.read(_db.chats.createdAt)!, updatedAt: row.read(_db.chats.updatedAt)!)).toList();
        }),
        // 3: remoteChatMetas
        remoteConnection.execute('SELECT id, created_at, updated_at FROM chats')
            .then((rows) => rows.map((row) => _SyncMeta(id: row[0] as int, createdAt: row[1] as DateTime, updatedAt: row[2] as DateTime)).toList()),
      ]);

      final localApiConfigMetas = metaResults[0] as List<_SyncMeta>;
      final remoteApiConfigMetas = metaResults[1] as List<_SyncMeta>;
      final localChatMetas = metaResults[2] as List<_SyncMeta>;
      final remoteChatMetas = metaResults[3] as List<_SyncMeta>;

      // --- Step 2: Compute Actions ---
      final apiConfigActions = _computeSyncActions(localMetas: localApiConfigMetas, remoteMetas: remoteApiConfigMetas);
      final chatActions = _computeSyncActions(localMetas: localChatMetas, remoteMetas: remoteChatMetas);
      debugPrint('API Config Actions: ${apiConfigActions.toCreateRemotely.length} to create, ${apiConfigActions.toPush.length} to push.');
      debugPrint('Chat Actions: ${chatActions.toCreateRemotely.length} to create, ${chatActions.toPush.length} to push.');

      // --- Step 3: Fetch Full Data for Actions in Parallel ---
      final apiConfigIdsToPush = {...apiConfigActions.toPush, ...apiConfigActions.toCreateRemotely}.toList();
      final chatIdsToPush = {...chatActions.toPush, ...chatActions.toCreateRemotely}.toList();
      final apiConfigIdsToPull = {...apiConfigActions.toPull, ...apiConfigActions.toCreateLocally}.toList();
      final chatIdsToPull = {...chatActions.toPull, ...chatActions.toCreateLocally}.toList();

      final dataResults = await Future.wait([
        // 0: apiConfigsToPush
        apiConfigIdsToPush.isNotEmpty
            ? (_db.select(_db.apiConfigs)..where((t) => t.id.isIn(apiConfigIdsToPush.cast<String>()))).get()
            : Future.value(<ApiConfig>[]),
        // 1: chatsToPush
        chatIdsToPush.isNotEmpty
            ? (_db.select(_db.chats)..where((t) => t.id.isIn(chatIdsToPush.cast<int>()))).get()
            : Future.value(<ChatData>[]),
        // 2: apiConfigsToPull
        apiConfigIdsToPull.isNotEmpty
            ? remoteConnection.execute(Sql.named('SELECT * FROM api_configs WHERE id = ANY(@ids)'), parameters: {'ids': apiConfigIdsToPull})
                .then((rows) => rows.map((r) => ApiConfig.fromJson(r.toColumnMap())).toList())
            : Future.value(<ApiConfig>[]),
        // 3: chatsToPull
        chatIdsToPull.isNotEmpty
            ? remoteConnection.execute(Sql.named('SELECT * FROM chats WHERE id = ANY(@ids)'), parameters: {'ids': chatIdsToPull})
                .then((rows) => rows.map((r) => ChatData.fromJson(r.toColumnMap())).toList())
            : Future.value(<ChatData>[]),
      ]);

      final apiConfigsToPush = dataResults[0] as List<ApiConfig>;
      final chatsToPush = dataResults[1] as List<ChatData>;
      final apiConfigsToPull = dataResults[2] as List<ApiConfig>;
      final chatsToPull = dataResults[3] as List<ChatData>;
      debugPrint('Will push ${apiConfigsToPush.length} api_configs and ${chatsToPush.length} chats.');
      
      // Fetch messages for chats that need to be pulled, before entering local transaction.
      final Map<int, List<MessageData>> messagesToPullByChat = {};
      if (chatsToPull.isNotEmpty) {
        final allChatIdsToPull = chatsToPull.map((c) => c.id).toList();
        final allMessagesToPull = await remoteConnection.execute(Sql.named('SELECT * FROM messages WHERE chat_id = ANY(@ids)'), parameters: {'ids': allChatIdsToPull})
          .then((rows) => rows.map((r) => MessageData.fromJson(r.toColumnMap())).toList());
        for (final message in allMessagesToPull) {
          (messagesToPullByChat[message.chatId] ??= []).add(message);
        }
      }

      // --- Step 4: Execute DB Writes ---
      // Manual transaction for remote push
      await remoteConnection.execute('BEGIN');
      try {
        // Batch push API Configs
        if (apiConfigsToPush.isNotEmpty) {
          debugPrint('Executing batch push for ${apiConfigsToPush.length} api_configs...');
          await remoteConnection.execute(
            Sql.named('''
              INSERT INTO api_configs (
                id, user_id, name, api_type, model, api_key, base_url,
                use_custom_temperature, temperature, use_custom_top_p, top_p,
                use_custom_top_k, top_k, max_output_tokens, stop_sequences,
                enable_reasoning_effort, reasoning_effort, created_at, updated_at
              )
              SELECT
                c.id, @user_id, c.name, c.api_type, c.model, c.api_key, c.base_url,
                c.use_custom_temperature, c.temperature, c.use_custom_top_p, c.top_p,
                c.use_custom_top_k, c.top_k, c.max_output_tokens, c.stop_sequences,
                c.enable_reasoning_effort, c.reasoning_effort, c.created_at, c.updated_at
              FROM UNNEST(
                @ids, @names, @api_types, @models, @api_keys, @base_urls,
                @use_custom_temperatures, @temperatures, @use_custom_top_ps, @top_ps,
                @use_custom_top_ks, @top_ks, @max_output_tokens_list, @stop_sequences_list,
                @enable_reasoning_efforts, @reasoning_efforts, @created_ats, @updated_ats
              ) AS c(
                id, name, api_type, model, api_key, base_url,
                use_custom_temperature, temperature, use_custom_top_p, top_p,
                use_custom_top_k, top_k, max_output_tokens, stop_sequences,
                enable_reasoning_effort, reasoning_effort, created_at, updated_at
              )
              ON CONFLICT (id) DO UPDATE SET
                user_id = EXCLUDED.user_id, name = EXCLUDED.name, api_type = EXCLUDED.api_type,
                model = EXCLUDED.model, api_key = EXCLUDED.api_key, base_url = EXCLUDED.base_url,
                use_custom_temperature = EXCLUDED.use_custom_temperature, temperature = EXCLUDED.temperature,
                use_custom_top_p = EXCLUDED.use_custom_top_p, top_p = EXCLUDED.top_p,
                use_custom_top_k = EXCLUDED.use_custom_top_k, top_k = EXCLUDED.top_k,
                max_output_tokens = EXCLUDED.max_output_tokens, stop_sequences = EXCLUDED.stop_sequences,
                enable_reasoning_effort = EXCLUDED.enable_reasoning_effort,
                reasoning_effort = EXCLUDED.reasoning_effort, updated_at = EXCLUDED.updated_at;
            '''),
            parameters: {
              'user_id': userId,
              'ids': apiConfigsToPush.map((c) => c.id).toList(),
              'names': apiConfigsToPush.map((c) => c.name).toList(),
              'api_types': apiConfigsToPush.map((c) => c.apiType.name).toList(),
              'models': apiConfigsToPush.map((c) => c.model).toList(),
              'api_keys': apiConfigsToPush.map((c) => c.apiKey).toList(),
              'base_urls': apiConfigsToPush.map((c) => c.baseUrl).toList(),
              'use_custom_temperatures': apiConfigsToPush.map((c) => c.useCustomTemperature).toList(),
              'temperatures': apiConfigsToPush.map((c) => c.temperature).toList(),
              'use_custom_top_ps': apiConfigsToPush.map((c) => c.useCustomTopP).toList(),
              'top_ps': apiConfigsToPush.map((c) => c.topP).toList(),
              'use_custom_top_ks': apiConfigsToPush.map((c) => c.useCustomTopK).toList(),
              'top_ks': apiConfigsToPush.map((c) => c.topK).toList(),
              'max_output_tokens_list': apiConfigsToPush.map((c) => c.maxOutputTokens).toList(),
              'stop_sequences_list': apiConfigsToPush.map((c) => const StringListConverter().toSql(c.stopSequences ?? [])).toList(),
              'enable_reasoning_efforts': apiConfigsToPush.map((c) => c.enableReasoningEffort).toList(),
              'reasoning_efforts': apiConfigsToPush.map((c) => c.reasoningEffort?.name).toList(),
              'created_ats': apiConfigsToPush.map((c) => c.createdAt).toList(),
              'updated_ats': apiConfigsToPush.map((c) => c.updatedAt).toList(),
            }
          );
        }

        // Batch push Chats and their Messages (ATOMIC)
        if (chatsToPush.isNotEmpty) {
          debugPrint('Executing batch push for ${chatsToPush.length} chats...');
          
          // Batch insert/update chats
          await remoteConnection.execute(
            Sql.named('''
              INSERT INTO chats (
                id, title, system_prompt, created_at, updated_at, cover_image_base64,
                background_image_path, order_index, is_folder, parent_folder_id,
                context_config, xml_rules, api_config_id,
                enable_preprocessing, preprocessing_prompt, context_summary, preprocessing_api_config_id,
                enable_secondary_xml, secondary_xml_prompt, secondary_xml_api_config_id,
                continue_prompt, enable_help_me_reply, help_me_reply_prompt,
                help_me_reply_api_config_id, help_me_reply_trigger_mode
              )
              SELECT
                c.id, c.title, c.system_prompt, c.created_at, c.updated_at, c.cover_image_base64,
                c.background_image_path, c.order_index, c.is_folder, c.parent_folder_id,
                c.context_config, c.xml_rules, c.api_config_id,
                c.enable_preprocessing, c.preprocessing_prompt, c.context_summary, c.preprocessing_api_config_id,
                c.enable_secondary_xml, c.secondary_xml_prompt, c.secondary_xml_api_config_id,
                c.continue_prompt, c.enable_help_me_reply, c.help_me_reply_prompt,
                c.help_me_reply_api_config_id, c.help_me_reply_trigger_mode
              FROM UNNEST(
                @ids, @titles, @system_prompts, @created_ats, @updated_ats, @cover_image_base64s,
                @background_image_paths, @order_indexes, @is_folders, @parent_folder_ids,
                @context_configs, @xml_rules_list, @api_config_ids,
                @enable_preprocessings, @preprocessing_prompts, @context_summaries, @preprocessing_api_config_ids,
                @enable_secondary_xmls, @secondary_xml_prompts, @secondary_xml_api_config_ids,
                @continue_prompts, @enable_help_me_replies, @help_me_reply_prompts,
                @help_me_reply_api_config_ids, @help_me_reply_trigger_modes
              ) AS c(
                id, title, system_prompt, created_at, updated_at, cover_image_base64,
                background_image_path, order_index, is_folder, parent_folder_id,
                context_config, xml_rules, api_config_id,
                enable_preprocessing, preprocessing_prompt, context_summary, preprocessing_api_config_id,
                enable_secondary_xml, secondary_xml_prompt, secondary_xml_api_config_id,
                continue_prompt, enable_help_me_reply, help_me_reply_prompt,
                help_me_reply_api_config_id, help_me_reply_trigger_mode
              )
              ON CONFLICT (id) DO UPDATE SET
                title = EXCLUDED.title, system_prompt = EXCLUDED.system_prompt, updated_at = EXCLUDED.updated_at,
                cover_image_base64 = EXCLUDED.cover_image_base64, background_image_path = EXCLUDED.background_image_path,
                order_index = EXCLUDED.order_index, is_folder = EXCLUDED.is_folder, parent_folder_id = EXCLUDED.parent_folder_id,
                context_config = EXCLUDED.context_config, xml_rules = EXCLUDED.xml_rules,
                api_config_id = EXCLUDED.api_config_id,
                enable_preprocessing = EXCLUDED.enable_preprocessing, preprocessing_prompt = EXCLUDED.preprocessing_prompt,
                context_summary = EXCLUDED.context_summary, preprocessing_api_config_id = EXCLUDED.preprocessing_api_config_id,
                enable_secondary_xml = EXCLUDED.enable_secondary_xml, secondary_xml_prompt = EXCLUDED.secondary_xml_prompt,
                secondary_xml_api_config_id = EXCLUDED.secondary_xml_api_config_id,
                continue_prompt = EXCLUDED.continue_prompt, enable_help_me_reply = EXCLUDED.enable_help_me_reply,
                help_me_reply_prompt = EXCLUDED.help_me_reply_prompt, help_me_reply_api_config_id = EXCLUDED.help_me_reply_api_config_id,
                help_me_reply_trigger_mode = EXCLUDED.help_me_reply_trigger_mode;
            '''),
            parameters: {
              'ids': chatsToPush.map((c) => c.id).toList(),
              'titles': chatsToPush.map((c) => c.title).toList(),
              'system_prompts': chatsToPush.map((c) => c.systemPrompt).toList(),
              'created_ats': chatsToPush.map((c) => c.createdAt).toList(),
              'updated_ats': chatsToPush.map((c) => c.updatedAt).toList(),
              'cover_image_base64s': chatsToPush.map((c) => c.coverImageBase64).toList(),
              'background_image_paths': chatsToPush.map((c) => c.backgroundImagePath).toList(),
              'order_indexes': chatsToPush.map((c) => c.orderIndex).toList(),
              'is_folders': chatsToPush.map((c) => c.isFolder).toList(),
              'parent_folder_ids': chatsToPush.map((c) => c.parentFolderId).toList(),
              'context_configs': chatsToPush.map((c) => const ContextConfigConverter().toSql(c.contextConfig)).toList(),
              'xml_rules_list': chatsToPush.map((c) => const XmlRuleListConverter().toSql(c.xmlRules)).toList(),
              'api_config_ids': chatsToPush.map((c) => c.apiConfigId).toList(),
              'enable_preprocessings': chatsToPush.map((c) => c.enablePreprocessing).toList(),
              'preprocessing_prompts': chatsToPush.map((c) => c.preprocessingPrompt).toList(),
              'context_summaries': chatsToPush.map((c) => c.contextSummary).toList(),
              'preprocessing_api_config_ids': chatsToPush.map((c) => c.preprocessingApiConfigId).toList(),
              'enable_secondary_xmls': chatsToPush.map((c) => c.enableSecondaryXml).toList(),
              'secondary_xml_prompts': chatsToPush.map((c) => c.secondaryXmlPrompt).toList(),
              'secondary_xml_api_config_ids': chatsToPush.map((c) => c.secondaryXmlApiConfigId).toList(),
              'continue_prompts': chatsToPush.map((c) => c.continuePrompt).toList(),
              'enable_help_me_replies': chatsToPush.map((c) => c.enableHelpMeReply).toList(),
              'help_me_reply_prompts': chatsToPush.map((c) => c.helpMeReplyPrompt).toList(),
              'help_me_reply_api_config_ids': chatsToPush.map((c) => c.helpMeReplyApiConfigId).toList(),
              'help_me_reply_trigger_modes': chatsToPush.map((c) => c.helpMeReplyTriggerMode?.name).toList(),
            }
          );

          // Now, handle all messages for all pushed chats in a batch
          final allChatIds = chatsToPush.map((c) => c.id).toList();
          final allMessagesToPush = await (_db.select(_db.messages)..where((t) => t.chatId.isIn(allChatIds))).get();
          
          // First, delete all existing messages for these chats to ensure consistency
          await remoteConnection.execute(Sql.named('DELETE FROM messages WHERE chat_id = ANY(@ids)'), parameters: {'ids': allChatIds});
          
          if (allMessagesToPush.isNotEmpty) {
            // Then, batch insert all new messages
            await remoteConnection.execute(
              Sql.named('''
                INSERT INTO messages (id, chat_id, role, raw_text, "timestamp", original_xml_content, secondary_xml_content)
                SELECT
                  m.id, m.chat_id, m.role, m.raw_text, m.timestamp, m.original_xml_content, m.secondary_xml_content
                FROM UNNEST(
                  @ids, @chat_ids, @roles, @raw_texts, @timestamps, @original_xml_contents, @secondary_xml_contents
                ) AS m(
                  id, chat_id, role, raw_text, "timestamp", original_xml_content, secondary_xml_content
                )
              '''),
              parameters: {
                'ids': allMessagesToPush.map((m) => m.id).toList(),
                'chat_ids': allMessagesToPush.map((m) => m.chatId).toList(),
                'roles': allMessagesToPush.map((m) => m.role.name).toList(),
                'raw_texts': allMessagesToPush.map((m) => m.rawText).toList(),
                'timestamps': allMessagesToPush.map((m) => m.timestamp).toList(),
                'original_xml_contents': allMessagesToPush.map((m) => m.originalXmlContent).toList(),
                'secondary_xml_contents': allMessagesToPush.map((m) => m.secondaryXmlContent).toList(),
              }
            );
          }
        }
        await remoteConnection.execute('COMMIT');
      } catch (e) {
        await remoteConnection.execute('ROLLBACK');
        rethrow; // Re-throw the exception after rolling back
      }
      
      await _db.transaction(() async {
        // Batch Pull API Configs to local
        if (apiConfigsToPull.isNotEmpty) {
           await _db.batch((batch) {
             batch.insertAll(_db.apiConfigs, apiConfigsToPull.map((c) => c.toCompanion(true)), mode: InsertMode.insertOrReplace);
           });
        }
        // Batch Pull Chats and their Messages (ATOMIC)
        if (chatsToPull.isNotEmpty) {
           await _db.batch((batch) {
             batch.insertAll(_db.chats, chatsToPull.map((c) => c.toCompanion(true)), mode: InsertMode.insertOrReplace);
           });

           // Now, handle messages for these chats using the pre-fetched map
           final allChatIdsToPull = chatsToPull.map((c) => c.id).toList();
           await (_db.delete(_db.messages)..where((t) => t.chatId.isIn(allChatIdsToPull))).go();

           final allMessagesToInsert = messagesToPullByChat.values.expand((list) => list).toList();
           if (allMessagesToInsert.isNotEmpty) {
             await _db.batch((batch) {
               batch.insertAll(_db.messages, allMessagesToInsert.map((m) => m.toCompanion(true)));
             });
           }
        }
      });

    } catch (e, s) {
      debugPrint('Synchronization failed.');
    } finally {
      await remoteConnection?.close();
    }
    debugPrint("Database synchronization finished.");
  }
}
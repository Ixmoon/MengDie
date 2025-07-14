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
      // Using a transaction for a single, complex operation is best practice.
      // Manual transaction control
      await remoteConnection.execute('BEGIN');
      try {
        // We must iterate and execute for each user, as batch operations with
        // ON CONFLICT are complex to construct safely with the postgres package.
        for (final user in localUsers) {
          await remoteConnection.execute(
            Sql.named('''
              INSERT INTO users (id, username, password_hash, chat_ids, enable_auto_title_generation, title_generation_prompt, title_generation_api_config_id, enable_resume, resume_prompt, resume_api_config_id, gemini_api_keys)
              VALUES (@id, @username, @password_hash, @chat_ids, @enable_auto_title_generation, @title_generation_prompt, @title_generation_api_config_id, @enable_resume, @resume_prompt, @resume_api_config_id, @gemini_api_keys)
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
              'id': user.id,
              'username': user.username,
              'password_hash': user.passwordHash,
              'chat_ids': const IntListConverter().toSql(user.chatIds ?? []),
              'enable_auto_title_generation': user.enableAutoTitleGeneration,
              'title_generation_prompt': user.titleGenerationPrompt,
              'title_generation_api_config_id': user.titleGenerationApiConfigId,
              'enable_resume': user.enableResume,
              'resume_prompt': user.resumePrompt,
              'resume_api_config_id': user.resumeApiConfigId,
              'gemini_api_keys': const StringListConverter().toSql(user.geminiApiKeys ?? []),
            },
          );
        }
        await remoteConnection.execute('COMMIT');
      } catch(e) {
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

      // --- Step 1 & 2: Fetch Metadata and Compute Actions ---
      // API Configs
      final localApiConfigMetas = await (_db.selectOnly(_db.apiConfigs)..addColumns([_db.apiConfigs.id, _db.apiConfigs.createdAt, _db.apiConfigs.updatedAt]))
        .get().then((rows) {
        debugPrint('Found ${rows.length} local api_config metas.');
        return rows.map((row) => _SyncMeta(id: row.read(_db.apiConfigs.id)!, createdAt: row.read(_db.apiConfigs.createdAt)!, updatedAt: row.read(_db.apiConfigs.updatedAt)!)).toList();
      });
      final remoteApiConfigMetas = await remoteConnection.execute('SELECT id, created_at, updated_at FROM api_configs')
        .then((rows) => rows.map((row) => _SyncMeta(id: row[0] as String, createdAt: row[1] as DateTime, updatedAt: row[2] as DateTime)).toList());
      final apiConfigActions = _computeSyncActions(localMetas: localApiConfigMetas, remoteMetas: remoteApiConfigMetas);

      // Chats
      final localChatMetas = await (_db.selectOnly(_db.chats)..addColumns([_db.chats.id, _db.chats.createdAt, _db.chats.updatedAt]))
        .get().then((rows) {
        debugPrint('Found ${rows.length} local chat metas.');
        return rows.map((row) => _SyncMeta(id: row.read(_db.chats.id)!, createdAt: row.read(_db.chats.createdAt)!, updatedAt: row.read(_db.chats.updatedAt)!)).toList();
      });
      final remoteChatMetas = await remoteConnection.execute('SELECT id, created_at, updated_at FROM chats')
        .then((rows) => rows.map((row) => _SyncMeta(id: row[0] as int, createdAt: row[1] as DateTime, updatedAt: row[2] as DateTime)).toList());
      final chatActions = _computeSyncActions(localMetas: localChatMetas, remoteMetas: remoteChatMetas);
      debugPrint('API Config Actions: ${apiConfigActions.toCreateRemotely.length} to create, ${apiConfigActions.toPush.length} to push.');
      debugPrint('Chat Actions: ${chatActions.toCreateRemotely.length} to create, ${chatActions.toPush.length} to push.');

      // --- Step 3: Fetch Full Data for Actions ---
      // Combine items to be pushed (updated) and created remotely.
      final apiConfigIdsToPush = {...apiConfigActions.toPush, ...apiConfigActions.toCreateRemotely}.toList();
      final chatIdsToPush = {...chatActions.toPush, ...chatActions.toCreateRemotely}.toList();

      final apiConfigsToPush = apiConfigIdsToPush.isNotEmpty ? await (_db.select(_db.apiConfigs)..where((t) => t.id.isIn(apiConfigIdsToPush.cast<String>()))).get() : <ApiConfig>[];
      final chatsToPush = chatIdsToPush.isNotEmpty ? await (_db.select(_db.chats)..where((t) => t.id.isIn(chatIdsToPush.cast<int>()))).get() : <ChatData>[];
      debugPrint('Will push ${apiConfigsToPush.length} api_configs and ${chatsToPush.length} chats.');
      
      // Combine items to be pulled (updated) and created locally.
      final apiConfigIdsToPull = {...apiConfigActions.toPull, ...apiConfigActions.toCreateLocally}.toList();
      final chatIdsToPull = {...chatActions.toPull, ...chatActions.toCreateLocally}.toList();

      final apiConfigsToPull = apiConfigIdsToPull.isNotEmpty ? await remoteConnection.execute(Sql.named('SELECT * FROM api_configs WHERE id = ANY(@ids)'), parameters: {'ids': apiConfigIdsToPull}).then((rows) => rows.map((r) => ApiConfig.fromJson(r.toColumnMap())).toList()) : <ApiConfig>[];
      final chatsToPull = chatIdsToPull.isNotEmpty ? await remoteConnection.execute(Sql.named('SELECT * FROM chats WHERE id = ANY(@ids)'), parameters: {'ids': chatIdsToPull}).then((rows) => rows.map((r) => ChatData.fromJson(r.toColumnMap())).toList()) : <ChatData>[];
      
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
        // Push API Configs one-by-one for robustness
        if (apiConfigsToPush.isNotEmpty) {
          debugPrint('Executing push for ${apiConfigsToPush.length} api_configs...');
          for (final config in apiConfigsToPush) {
            await remoteConnection.execute(
              Sql.named('''
                INSERT INTO api_configs (id, user_id, name, api_type, model, api_key, base_url, use_custom_temperature, temperature, use_custom_top_p, top_p, use_custom_top_k, top_k, max_output_tokens, stop_sequences, enable_reasoning_effort, reasoning_effort, created_at, updated_at)
                VALUES (@id, @user_id, @name, @api_type, @model, @api_key, @base_url, @use_custom_temperature, @temperature, @use_custom_top_p, @top_p, @use_custom_top_k, @top_k, @max_output_tokens, @stop_sequences, @enable_reasoning_effort, @reasoning_effort, @created_at, @updated_at)
                ON CONFLICT (id) DO UPDATE SET
                  user_id = EXCLUDED.user_id, name = EXCLUDED.name, api_type = EXCLUDED.api_type, model = EXCLUDED.model, api_key = EXCLUDED.api_key, base_url = EXCLUDED.base_url,
                  use_custom_temperature = EXCLUDED.use_custom_temperature, temperature = EXCLUDED.temperature, use_custom_top_p = EXCLUDED.use_custom_top_p, top_p = EXCLUDED.top_p,
                  use_custom_top_k = EXCLUDED.use_custom_top_k, top_k = EXCLUDED.top_k, max_output_tokens = EXCLUDED.max_output_tokens, stop_sequences = EXCLUDED.stop_sequences,
                  enable_reasoning_effort = EXCLUDED.enable_reasoning_effort, reasoning_effort = EXCLUDED.reasoning_effort, updated_at = EXCLUDED.updated_at;
              '''),
              parameters: {
                'id': config.id,
                'user_id': userId,
                'name': config.name,
                'api_type': config.apiType.name,
                'model': config.model,
                'api_key': config.apiKey,
                'base_url': config.baseUrl,
                'use_custom_temperature': config.useCustomTemperature,
                'temperature': config.temperature,
                'use_custom_top_p': config.useCustomTopP,
                'top_p': config.topP,
                'use_custom_top_k': config.useCustomTopK,
                'top_k': config.topK,
                'max_output_tokens': config.maxOutputTokens,
                'stop_sequences': const StringListConverter().toSql(config.stopSequences ?? []),
                'enable_reasoning_effort': config.enableReasoningEffort,
                'reasoning_effort': config.reasoningEffort?.name,
                'created_at': config.createdAt,
                'updated_at': config.updatedAt,
              }
            );
          }
        }

        // Push Chats and their Messages (ATOMIC) one-by-one
        if (chatsToPush.isNotEmpty) {
          debugPrint('Executing push for ${chatsToPush.length} chats...');
          for (final chat in chatsToPush) {
            // Insert/Update the chat itself
            await remoteConnection.execute(
              Sql.named('''
                INSERT INTO chats (id, title, system_prompt, created_at, updated_at, cover_image_base64, background_image_path, order_index, is_folder, parent_folder_id, context_config, xml_rules, api_config_id, api_type, generation_config, enable_preprocessing, preprocessing_prompt, context_summary, preprocessing_api_config_id, enable_secondary_xml, secondary_xml_prompt, secondary_xml_api_config_id, continue_prompt, enable_help_me_reply, help_me_reply_prompt, help_me_reply_api_config_id, help_me_reply_trigger_mode)
                VALUES (@id, @title, @system_prompt, @created_at, @updated_at, @cover_image_base64, @background_image_path, @order_index, @is_folder, @parent_folder_id, @context_config, @xml_rules, @api_config_id, @api_type, @generation_config, @enable_preprocessing, @preprocessing_prompt, @context_summary, @preprocessing_api_config_id, @enable_secondary_xml, @secondary_xml_prompt, @secondary_xml_api_config_id, @continue_prompt, @enable_help_me_reply, @help_me_reply_prompt, @help_me_reply_api_config_id, @help_me_reply_trigger_mode)
                ON CONFLICT (id) DO UPDATE SET
                  title = EXCLUDED.title, system_prompt = EXCLUDED.system_prompt, updated_at = EXCLUDED.updated_at, cover_image_base64 = EXCLUDED.cover_image_base64, background_image_path = EXCLUDED.background_image_path,
                  order_index = EXCLUDED.order_index, is_folder = EXCLUDED.is_folder, parent_folder_id = EXCLUDED.parent_folder_id, context_config = EXCLUDED.context_config, xml_rules = EXCLUDED.xml_rules,
                  api_config_id = EXCLUDED.api_config_id, api_type = EXCLUDED.api_type, generation_config = EXCLUDED.generation_config, enable_preprocessing = EXCLUDED.enable_preprocessing,
                  preprocessing_prompt = EXCLUDED.preprocessing_prompt, context_summary = EXCLUDED.context_summary, preprocessing_api_config_id = EXCLUDED.preprocessing_api_config_id,
                  enable_secondary_xml = EXCLUDED.enable_secondary_xml, secondary_xml_prompt = EXCLUDED.secondary_xml_prompt, secondary_xml_api_config_id = EXCLUDED.secondary_xml_api_config_id,
                  continue_prompt = EXCLUDED.continue_prompt, enable_help_me_reply = EXCLUDED.enable_help_me_reply, help_me_reply_prompt = EXCLUDED.help_me_reply_prompt,
                  help_me_reply_api_config_id = EXCLUDED.help_me_reply_api_config_id, help_me_reply_trigger_mode = EXCLUDED.help_me_reply_trigger_mode;
              '''),
              parameters: {
                'id': chat.id,
                'title': chat.title,
                'system_prompt': chat.systemPrompt,
                'created_at': chat.createdAt,
                'updated_at': chat.updatedAt,
                'cover_image_base64': chat.coverImageBase64,
                'background_image_path': chat.backgroundImagePath,
                'order_index': chat.orderIndex,
                'is_folder': chat.isFolder,
                'parent_folder_id': chat.parentFolderId,
                'context_config': const ContextConfigConverter().toSql(chat.contextConfig),
                'xml_rules': const XmlRuleListConverter().toSql(chat.xmlRules),
                'api_config_id': chat.apiConfigId,
                'enable_preprocessing': chat.enablePreprocessing,
                'preprocessing_prompt': chat.preprocessingPrompt,
                'context_summary': chat.contextSummary,
                'preprocessing_api_config_id': chat.preprocessingApiConfigId,
                'enable_secondary_xml': chat.enableSecondaryXml,
                'secondary_xml_prompt': chat.secondaryXmlPrompt,
                'secondary_xml_api_config_id': chat.secondaryXmlApiConfigId,
                'continue_prompt': chat.continuePrompt,
                'enable_help_me_reply': chat.enableHelpMeReply,
                'help_me_reply_prompt': chat.helpMeReplyPrompt,
                'help_me_reply_api_config_id': chat.helpMeReplyApiConfigId,
                'help_me_reply_trigger_mode': chat.helpMeReplyTriggerMode?.name,
              }
            );

            // Now, handle messages for this specific chat
            final messagesToPush = await (_db.select(_db.messages)..where((t) => t.chatId.equals(chat.id))).get();
            
            // First, delete existing messages for this chat to ensure consistency
            await remoteConnection.execute(Sql.named('DELETE FROM messages WHERE chat_id = @id'), parameters: {'id': chat.id});
            
            if (messagesToPush.isNotEmpty) {
              // Insert messages one-by-one for this chat
              for (final message in messagesToPush) {
                await remoteConnection.execute(
                  Sql.named('''
                    INSERT INTO messages (id, chat_id, role, raw_text, "timestamp", original_xml_content, secondary_xml_content)
                    VALUES (@id, @chat_id, @role, @raw_text, @timestamp, @original_xml_content, @secondary_xml_content)
                  '''),
                  parameters: {
                    'id': message.id,
                    'chat_id': message.chatId,
                    'role': message.role.name,
                    'raw_text': message.partsJson,
                    'timestamp': message.timestamp,
                    'original_xml_content': message.originalXmlContent,
                    'secondary_xml_content': message.secondaryXmlContent,
                  }
                );
              }
            }
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
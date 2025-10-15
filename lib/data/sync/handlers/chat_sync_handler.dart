import 'package:drift/drift.dart';
import 'package:postgres/postgres.dart';

import '../../database/app_database.dart';
import '../sync_meta.dart';
import 'base_sync_handler.dart';
import '../../database/type_converters.dart';

class ChatSyncHandler extends BaseSyncHandler<ChatData> {
  final int userId;
  ChatSyncHandler(super.db, super.remoteConnection, this.userId);

  @override
  String get entityType => 'chats';

  Future<List<int>> _getChatIdsForCurrentUser() async {
    if (userId == 0) return [];
    final user = await (db.select(
      db.users,
    )..where((u) => u.id.equals(userId))).getSingleOrNull();
    return user?.chatIds ?? [];
  }

  @override
  Future<List<SyncMeta>> getLocalMetas() async {
    final chatIds = await _getChatIdsForCurrentUser();
    if (chatIds.isEmpty) return [];

    final query = db.selectOnly(db.chats)..where(db.chats.id.isIn(chatIds));
    final rows =
        await (query..addColumns([
              db.chats.id,
              db.chats.createdAt,
              db.chats.updatedAt,
            ]))
            .get();

    return rows
        .map(
          (row) => SyncMeta(
            id: row.read(db.chats.id)!,
            createdAt: const MicrosecondDateTimeConverter().fromSql(
              row.read(db.chats.createdAt)!,
            ),
            updatedAt: const MicrosecondDateTimeConverter().fromSql(
              row.read(db.chats.updatedAt)!,
            ),
          ),
        )
        .toList();
  }

  @override
  Future<List<SyncMeta>> getRemoteMetas({List<dynamic>? localIds}) async {
    final chatIds = await _getChatIdsForCurrentUser();
    if (chatIds.isEmpty) return [];

    // Determine the final set of IDs to query remotely
    final idsToQuery =
        localIds?.cast<int>().where((id) => chatIds.contains(id)).toList() ??
        chatIds;
    if (idsToQuery.isEmpty) return [];

    final rows = await remoteConnection!.execute(
      Sql.named(
        'SELECT id, created_at, updated_at FROM chats WHERE id = ANY(@ids)',
      ),
      parameters: {'ids': idsToQuery},
    );

    return rows
        .map(
          (row) => SyncMeta(
            id: row[0] as int,
            createdAt: row[1] as DateTime,
            updatedAt: row[2] as DateTime,
          ),
        )
        .toList();
  }

  @override
  Future<void> push(List<dynamic> ids) async {
    if (ids.isEmpty) return;
    final chatIds = ids.cast<int>();
    final chatsToPush = await (db.select(
      db.chats,
    )..where((t) => t.id.isIn(chatIds))).get();
    if (chatsToPush.isEmpty) return;

    await _batchPushChats(remoteConnection!, chatsToPush);
  }

  @override
  Future<void> pull(List<dynamic> ids) async {
    if (ids.isEmpty) return;
    final chatIds = ids.cast<int>();

    final rows = await remoteConnection!.execute(
      Sql.named('SELECT * FROM chats WHERE id = ANY(@ids)'),
      parameters: {'ids': chatIds},
    );
    final chatsToPull = rows.map((r) {
      final map = r.toColumnMap();
      final now = DateTime.now();
      final created = map['created_at'] ?? now;
      final updated = map['updated_at'] ?? created;
      return ChatData(
        id: map['id'],
        title: map['title'],
        systemPrompt: map['system_prompt'],
        createdAt: created,
        updatedAt: updated,
        coverImageBase64: null,
        backgroundImagePath: map['background_image_path'],
        orderIndex: map['order_index'],
        isFolder: map['is_folder'],
        parentFolderId: map['parent_folder_id'],
        contextConfig: const ContextConfigConverter().fromSql(
          map['context_config'],
        ),
        xmlRules: const XmlRuleListConverter().fromSql(map['xml_rules']),
        apiConfigId: map['api_config_id'],
        enablePreprocessing: map['enable_preprocessing'],
        preprocessingPrompt: map['preprocessing_prompt'],
        contextSummary: map['context_summary'],
        lastSummarizedMessageId: map['last_summarized_message_id'],
        preprocessingApiConfigId: map['preprocessing_api_config_id'],
        enableSecondaryXml: map['enable_secondary_xml'],
        secondaryXmlPrompt: map['secondary_xml_prompt'],
        secondaryXmlApiConfigId: map['secondary_xml_api_config_id'],
        continuePrompt: map['continue_prompt'],
        enableHelpMeReply: map['enable_help_me_reply'],
        helpMeReplyPrompt: map['help_me_reply_prompt'],
        helpMeReplyApiConfigId: map['help_me_reply_api_config_id'],
        helpMeReplyTriggerMode: map['help_me_reply_trigger_mode'] == null
            ? null
            : const HelpMeReplyTriggerModeConverter().fromSql(
                map['help_me_reply_trigger_mode'],
              ),
      );
    }).toList();
    if (chatsToPull.isEmpty) return;

    await db.batch((batch) {
      batch.insertAll(
        db.chats,
        chatsToPull.map((c) => c.toCompanion(true)),
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  @override
  Future<Map<dynamic, dynamic>> resolveConflicts(
    List<SyncMeta> localMetas,
    List<SyncMeta> remoteMetas,
  ) async {
    final localIdMap = {for (var meta in localMetas) meta.id: meta};
    final remoteIdMap = {for (var meta in remoteMetas) meta.id: meta};
    final conflictingIds = <int>{};

    // Find conflicts (same ID, different createdAt)
    for (final id in localIdMap.keys) {
      if (remoteIdMap.containsKey(id)) {
        final localMeta = localIdMap[id]!;
        final remoteMeta = remoteIdMap[id]!;
        // If local is newer, it wins. We modify the remote record.
        if (localMeta.createdAt.toUtc() != remoteMeta.createdAt.toUtc()) {
          conflictingIds.add(id as int);
        }
      }
    }

    final idChangeMap = <int, int>{};
    if (conflictingIds.isNotEmpty) {
      await remoteConnection!.execute('BEGIN');
      try {
        for (final id in conflictingIds) {
          // Pass the connection itself as the execution context
          final newId = await _resolveRemoteChatConflict(remoteConnection!, id);
          if (newId != null) {
            idChangeMap[id] = newId;
          }
        }
        await remoteConnection!.execute('COMMIT');
      } catch (e) {
        await remoteConnection!.execute('ROLLBACK');
        rethrow; // Propagate the error
      }
    }
    return idChangeMap;
  }

  @override
  Future<void> deleteRemotely(List<String> keys) async {
    if (keys.isEmpty) return;
    // 1. Correctly parse the integer IDs from the string keys.
    final chatIdsToDelete =
        keys.map((key) => int.tryParse(key) ?? -1).where((id) => id != -1).toSet().toList();

    if (chatIdsToDelete.isNotEmpty) {
      final c = remoteConnection!;
      
      // 2. Before deleting, update the chat_ids array in the users table.
      // This prevents orphaned IDs and maintains data integrity.
      final allUsersResult = await c.execute(Sql('SELECT id, chat_ids FROM users'));
      
      for (final row in allUsersResult) {
        final userId = row[0] as int;
        final rawChatIds = row[1];
        List<int> currentChatIds = [];

        if (rawChatIds is String && rawChatIds.startsWith('{') && rawChatIds.endsWith('}')) {
          final idsString = rawChatIds.substring(1, rawChatIds.length - 1);
          if (idsString.isNotEmpty) {
            currentChatIds = idsString.split(',').map((idStr) => int.tryParse(idStr.trim()) ?? 0).where((id) => id != 0).toList();
          }
        } else if (rawChatIds is List) {
          currentChatIds = rawChatIds.cast<int>();
        }

        final newChatIds = currentChatIds.where((id) => !chatIdsToDelete.contains(id)).toList();

        // Only update if the list has actually changed.
        if (newChatIds.length != currentChatIds.length) {
          final newChatIdsLiteral = newChatIds.isEmpty ? '{}' : '{${newChatIds.join(',')}}';
          await c.execute(
            Sql.named('UPDATE users SET chat_ids = @newChatIds::integer[] WHERE id = @userId'),
            parameters: {'newChatIds': newChatIdsLiteral, 'userId': userId},
          );
        }
      }

      // 3. Delete associated messages first.
      await c.execute(
        Sql.named('DELETE FROM messages WHERE chat_id = ANY(@ids)'),
        parameters: {'ids': chatIdsToDelete},
      );
      // 4. Finally, delete the chats themselves.
      await c.execute(
        Sql.named('DELETE FROM chats WHERE id = ANY(@ids)'),
        parameters: {'ids': chatIdsToDelete},
      );
    }
  }

  // ============== CONFLICT RESOLUTION HELPERS ==============

  /// Resolves a chat ID conflict on the remote database.
  /// This gives precedence to the local data by creating a new ID for the
  /// conflicting remote data and updating all its foreign key references.
  Future<int?> _resolveRemoteChatConflict(
    Connection c,
    int oldId,
  ) async {
    try {
      // 1. Re-insert the conflicting chat to get a new ID
      final newIdResult = await c.execute(Sql.named('''
        INSERT INTO chats (
          title, system_prompt, created_at, updated_at,
          order_index, is_folder, parent_folder_id,
          background_image_path, context_config, xml_rules, api_config_id,
          enable_preprocessing, preprocessing_prompt, context_summary, last_summarized_message_id, preprocessing_api_config_id,
          enable_secondary_xml, secondary_xml_prompt, secondary_xml_api_config_id,
          continue_prompt, enable_help_me_reply, help_me_reply_prompt,
          help_me_reply_api_config_id, help_me_reply_trigger_mode
        )
        SELECT
          title, system_prompt, created_at, updated_at,
          order_index, is_folder, parent_folder_id,
          background_image_path, context_config, xml_rules, api_config_id,
          enable_preprocessing, preprocessing_prompt, context_summary, last_summarized_message_id, preprocessing_api_config_id,
          enable_secondary_xml, secondary_xml_prompt, secondary_xml_api_config_id,
          continue_prompt, enable_help_me_reply, help_me_reply_prompt,
          help_me_reply_api_config_id, help_me_reply_trigger_mode
        FROM chats WHERE id = @oldId::integer
        RETURNING id;
      '''), parameters: {'oldId': oldId});

      if (newIdResult.isEmpty || newIdResult.first.isEmpty) return null;
      final newId = newIdResult.first.first as int;

      // 2. Re-create all messages from the old chat under the new chat.
      // This ensures messages also get new unique IDs, aligning with the "copy" strategy.
      await c.execute(
        Sql.named('''
          INSERT INTO messages (chat_id, role, raw_text, "timestamp", updated_at, original_xml_content, secondary_xml_content)
          SELECT @newId::integer, role, raw_text, "timestamp", updated_at, original_xml_content, secondary_xml_content
          FROM messages WHERE chat_id = @oldId::integer
        '''),
        parameters: {'newId': newId, 'oldId': oldId},
      );
      
      // Once messages are copied, delete the originals.
      await c.execute(
        Sql.named('DELETE FROM messages WHERE chat_id = @oldId::integer'),
        parameters: {'oldId': oldId},
      );

      // 3. Update foreign keys in other related tables
      await c.execute(
        Sql.named(
            'UPDATE chats SET parent_folder_id = @newId::integer WHERE parent_folder_id = @oldId::integer'),
        parameters: {'newId': newId, 'oldId': oldId},
      );

      // 4. Update the chat_ids array in the users table.
      // We revert to a "read-process-write" pattern, but with a robust SELECT query
      // that uses array_position() to avoid the type inference bug with the ANY operator.
      // Fetch ALL users and perform the check in Dart. This is a robust but less efficient
      // workaround for the persistent driver/DB issue with array parameters in WHERE clauses.
      final allUsersResult = await c.execute(
        Sql('SELECT id, chat_ids FROM users'),
      );

      for (final row in allUsersResult) {
        final userId = row[0] as int;
        final rawChatIds = row[1];
        List<int> oldChatIds = [];

        // Manually parse the PostgreSQL array string format: '{1,2,3}'
        if (rawChatIds is String &&
            rawChatIds.startsWith('{') &&
            rawChatIds.endsWith('}')) {
          final idsString = rawChatIds.substring(1, rawChatIds.length - 1);
          if (idsString.isNotEmpty) {
            oldChatIds = idsString
                .split(',')
                .map((idStr) => int.tryParse(idStr.trim()) ?? 0)
                .where((id) => id != 0)
                .toList();
          }
        } else if (rawChatIds is List) {
          // Handle cases where the driver might return a list directly
          oldChatIds = rawChatIds.cast<int>();
        }

        // Check if this user is affected
        if (oldChatIds.contains(oldId)) {
          final newChatIds =
              oldChatIds.map((id) => id == oldId ? newId : id).toList();
          // Manually format the list into a PostgreSQL-compatible array literal string
          final newChatIdsLiteral = '{${newChatIds.join(',')}}';
          await c.execute(
            Sql.named(
                'UPDATE users SET chat_ids = @newChatIds::integer[] WHERE id = @userId'),
            parameters: {
              'newChatIds': newChatIdsLiteral,
              'userId': userId,
            },
          );
        }
      }

      // 5. Re-create all messages from the old chat under the new chat.
      await c.execute(
        Sql.named('''
          INSERT INTO messages (chat_id, role, raw_text, "timestamp", updated_at, original_xml_content, secondary_xml_content)
          SELECT @newId::integer, role, raw_text, "timestamp", updated_at, original_xml_content, secondary_xml_content
          FROM messages WHERE chat_id = @oldId::integer
        '''),
        parameters: {'newId': newId, 'oldId': oldId},
      );

      // 6. Delete the old chat record (and its messages, thanks to CASCADE)
      await c.execute(
        Sql.named('DELETE FROM chats WHERE id = @oldId::integer'),
        parameters: {'oldId': oldId},
      );

      return newId;
    } catch (e) {
      // If any part of the transaction fails, it will be rolled back.
      // We rethrow to make the SyncService aware of the failure.
      rethrow;
    }
  }

  /// (Old method, now unused) Resolves a chat ID conflict on the local database.
  Future<int?> _resolveChatConflict(int oldId, List<DriftUser> allUsers) async {
    final chat = await (db.select(
      db.chats,
    )..where((tbl) => tbl.id.equals(oldId))).getSingleOrNull();
    if (chat == null) {
      return null;
    }

    final messages = await (db.select(
      db.messages,
    )..where((tbl) => tbl.chatId.equals(oldId))).get();

    final newChatCompanion =
        chat.toCompanion(false).copyWith(id: const Value.absent());
    final newChat = await db.into(db.chats).insertReturning(newChatCompanion);
    final newId = newChat.id;

    if (messages.isNotEmpty) {
      final messageIds = messages.map((m) => m.id).toList();
      await (db.update(db.messages)..where((tbl) => tbl.id.isIn(messageIds)))
          .write(MessagesCompanion(chatId: Value(newId)));
    }

    await (db.update(db.chats)
          ..where((tbl) => tbl.parentFolderId.equals(oldId)))
        .write(ChatsCompanion(parentFolderId: Value(newId)));

    final affectedUsers = allUsers
        .where((user) => user.chatIds?.contains(oldId) ?? false)
        .toList();

    if (affectedUsers.isNotEmpty) {
      await db.batch((batch) {
        for (final user in affectedUsers) {
          final newChatIds =
              user.chatIds!.map((id) => id == oldId ? newId : id).toList();
          batch.update(
            db.users,
            UsersCompanion(chatIds: Value(newChatIds)),
            where: (u) => u.id.equals(user.id),
          );
        }
      });
    }

    await (db.delete(db.chats)..where((tbl) => tbl.id.equals(oldId))).go();
    return newId;
  }

  // ============== PRIVATE DATA FETCHING & BATCH PUSH HELPERS (moved from SyncService) ==============

  Future<void> _batchPushChats(
    Connection remoteConnection,
    List<ChatData> chats,
  ) async {
    if (chats.isEmpty) return;

    // --- START: Manual Conflict Resolution ---
    // Before pushing, check for ID conflicts with different creation times.
    final chatIdsToPush = chats.map((c) => c.id).toList();
    final remoteMetasResult = await remoteConnection.execute(
      Sql.named(
        'SELECT id, created_at FROM chats WHERE id = ANY(@ids)',
      ),
      parameters: {'ids': chatIdsToPush},
    );

    final remoteMetas = remoteMetasResult.map((row) => SyncMeta(
          id: row[0] as int,
          createdAt: row[1] as DateTime,
          updatedAt: DateTime.now(), // Not used for this check
        )).toList();
        
    final localMetas = chats.map((c) => SyncMeta(
      id: c.id,
      createdAt: c.createdAt,
      updatedAt: c.updatedAt,
    )).toList();

    final conflictingIds = <int>{};
    final remoteMetaMap = {for (var meta in remoteMetas) meta.id: meta};

    for (final localMeta in localMetas) {
      final remoteMeta = remoteMetaMap[localMeta.id];
      if (remoteMeta != null && remoteMeta.createdAt.toUtc() != localMeta.createdAt.toUtc()) {
        conflictingIds.add(localMeta.id);
      }
    }

    if (conflictingIds.isNotEmpty) {
      for (final id in conflictingIds) {
        await _resolveRemoteChatConflict(remoteConnection, id);
      }
    }
    // --- END: Manual Conflict Resolution ---

    await remoteConnection.execute(
      Sql.named('''
        INSERT INTO chats (
          id, title, system_prompt, created_at, updated_at,
          order_index, is_folder, parent_folder_id,
          background_image_path, context_config, xml_rules, api_config_id,
          enable_preprocessing, preprocessing_prompt, context_summary, last_summarized_message_id, preprocessing_api_config_id,
          enable_secondary_xml, secondary_xml_prompt, secondary_xml_api_config_id,
          continue_prompt, enable_help_me_reply, help_me_reply_prompt,
          help_me_reply_api_config_id, help_me_reply_trigger_mode
        )
        SELECT
          c.id, c.title, c.system_prompt, c.created_at, c.updated_at,
          c.order_index, c.is_folder, c.parent_folder_id,
          c.background_image_path, c.context_config, c.xml_rules, c.api_config_id,
          c.enable_preprocessing, c.preprocessing_prompt, c.context_summary, c.last_summarized_message_id, c.preprocessing_api_config_id,
          c.enable_secondary_xml, c.secondary_xml_prompt, c.secondary_xml_api_config_id,
          c.continue_prompt, c.enable_help_me_reply, c.help_me_reply_prompt,
          c.help_me_reply_api_config_id, c.help_me_reply_trigger_mode
        FROM UNNEST(
          @ids::integer[], @titles::text[], @system_prompts::text[], @created_ats::timestamp[], @updated_ats::timestamp[],
          @order_indexes::integer[], @is_folders::boolean[], @parent_folder_ids::integer[],
          @background_image_paths::text[], @context_configs::text[], @xml_rules_list::text[], @api_config_ids::text[],
          @enable_preprocessings::boolean[], @preprocessing_prompts::text[], @context_summaries::text[], @last_summarized_message_ids::integer[], @preprocessing_api_config_ids::text[],
          @enable_secondary_xmls::boolean[], @secondary_xml_prompts::text[], @secondary_xml_api_config_ids::text[],
          @continue_prompts::text[], @enable_help_me_replies::boolean[], @help_me_reply_prompts::text[],
          @help_me_reply_api_config_ids::text[], @help_me_reply_trigger_modes::text[]
        ) AS c(
          id, title, system_prompt, created_at, updated_at,
          order_index, is_folder, parent_folder_id,
          background_image_path, context_config, xml_rules, api_config_id,
          enable_preprocessing, preprocessing_prompt, context_summary, last_summarized_message_id, preprocessing_api_config_id,
          enable_secondary_xml, secondary_xml_prompt, secondary_xml_api_config_id,
          continue_prompt, enable_help_me_reply, help_me_reply_prompt,
          help_me_reply_api_config_id, help_me_reply_trigger_mode
        )
        ON CONFLICT (id) DO UPDATE SET
          title = EXCLUDED.title, system_prompt = EXCLUDED.system_prompt, updated_at = EXCLUDED.updated_at,
          order_index = EXCLUDED.order_index, is_folder = EXCLUDED.is_folder, parent_folder_id = EXCLUDED.parent_folder_id,
          background_image_path = EXCLUDED.background_image_path, context_config = EXCLUDED.context_config, xml_rules = EXCLUDED.xml_rules,
          api_config_id = EXCLUDED.api_config_id,
          enable_preprocessing = EXCLUDED.enable_preprocessing, preprocessing_prompt = EXCLUDED.preprocessing_prompt,
          context_summary = EXCLUDED.context_summary, last_summarized_message_id = EXCLUDED.last_summarized_message_id, preprocessing_api_config_id = EXCLUDED.preprocessing_api_config_id,
          enable_secondary_xml = EXCLUDED.enable_secondary_xml, secondary_xml_prompt = EXCLUDED.secondary_xml_prompt,
          secondary_xml_api_config_id = EXCLUDED.secondary_xml_api_config_id,
          continue_prompt = EXCLUDED.continue_prompt, enable_help_me_reply = EXCLUDED.enable_help_me_reply,
          help_me_reply_prompt = EXCLUDED.help_me_reply_prompt, help_me_reply_api_config_id = EXCLUDED.help_me_reply_api_config_id,
          help_me_reply_trigger_mode = EXCLUDED.help_me_reply_trigger_mode;
      '''),
      parameters: {
        'ids': TypedValue(Type.integerArray, chats.map((c) => c.id).toList()),
        'titles': TypedValue(
          Type.textArray,
          chats.map((c) => c.title).toList(),
        ),
        'system_prompts': TypedValue(
          Type.textArray,
          chats.map((c) => c.systemPrompt).toList(),
        ),
        'created_ats': TypedValue(
          Type.timestampArray,
          chats.map((c) => c.createdAt).toList(),
        ),
        'updated_ats': TypedValue(
          Type.timestampArray,
          chats.map((c) => c.updatedAt).toList(),
        ),
        'order_indexes': TypedValue(
          Type.integerArray,
          chats.map((c) => c.orderIndex).toList(),
        ),
        'is_folders': TypedValue(
          Type.booleanArray,
          chats.map((c) => c.isFolder).toList(),
        ),
        'parent_folder_ids': TypedValue(
          Type.integerArray,
          chats.map((c) => c.parentFolderId).toList(),
        ),
        'background_image_paths': TypedValue(
          Type.textArray,
          chats.map((c) => c.backgroundImagePath).toList(),
        ),
        'context_configs': TypedValue(
          Type.textArray,
          chats
              .map((c) => const ContextConfigConverter().toSql(c.contextConfig))
              .toList(),
        ),
        'xml_rules_list': TypedValue(
          Type.textArray,
          chats
              .map((c) => const XmlRuleListConverter().toSql(c.xmlRules))
              .toList(),
        ),
        'api_config_ids': TypedValue(
          Type.textArray,
          chats.map((c) => c.apiConfigId).toList(),
        ),
        'enable_preprocessings': TypedValue(
          Type.booleanArray,
          chats.map((c) => c.enablePreprocessing).toList(),
        ),
        'preprocessing_prompts': TypedValue(
          Type.textArray,
          chats.map((c) => c.preprocessingPrompt).toList(),
        ),
        'context_summaries': TypedValue(
          Type.textArray,
          chats.map((c) => c.contextSummary).toList(),
        ),
        'last_summarized_message_ids': TypedValue(
          Type.integerArray,
          chats.map((c) => c.lastSummarizedMessageId).toList(),
        ),
        'preprocessing_api_config_ids': TypedValue(
          Type.textArray,
          chats.map((c) => c.preprocessingApiConfigId).toList(),
        ),
        'enable_secondary_xmls': TypedValue(
          Type.booleanArray,
          chats.map((c) => c.enableSecondaryXml).toList(),
        ),
        'secondary_xml_prompts': TypedValue(
          Type.textArray,
          chats.map((c) => c.secondaryXmlPrompt).toList(),
        ),
        'secondary_xml_api_config_ids': TypedValue(
          Type.textArray,
          chats.map((c) => c.secondaryXmlApiConfigId).toList(),
        ),
        'continue_prompts': TypedValue(
          Type.textArray,
          chats.map((c) => c.continuePrompt).toList(),
        ),
        'enable_help_me_replies': TypedValue(
          Type.booleanArray,
          chats.map((c) => c.enableHelpMeReply).toList(),
        ),
        'help_me_reply_prompts': TypedValue(
          Type.textArray,
          chats.map((c) => c.helpMeReplyPrompt).toList(),
        ),
        'help_me_reply_api_config_ids': TypedValue(
          Type.textArray,
          chats.map((c) => c.helpMeReplyApiConfigId).toList(),
        ),
        'help_me_reply_trigger_modes': TypedValue(
          Type.textArray,
          chats.map((c) => c.helpMeReplyTriggerMode?.name).toList(),
        ),
      },
    );
  }
}

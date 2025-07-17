import 'package:drift/drift.dart';
import 'package:postgres/postgres.dart';

import '../../database/app_database.dart';
import '../sync_meta.dart';
import 'base_sync_handler.dart';
import '../../database/type_converters.dart';

class ChatSyncHandler extends BaseSyncHandler<ChatData> {
  ChatSyncHandler(super.db, super.remoteConnection);

  @override
  String get entityType => 'chats';

  @override
  Future<List<SyncMeta>> getLocalMetas() async {
    final rows = await (db.selectOnly(db.chats)..addColumns([db.chats.id, db.chats.createdAt, db.chats.updatedAt])).get();
    return rows.map((row) => SyncMeta(
      id: row.read(db.chats.id)!,
      createdAt: row.read(db.chats.createdAt)!,
      updatedAt: row.read(db.chats.updatedAt)!
    )).toList();
  }

  @override
  Future<List<SyncMeta>> getRemoteMetas({List<dynamic>? localIds}) async {
    Result rows;
    if (localIds != null) {
      // Optimization for conflict resolution: only fetch remote metas for corresponding local IDs.
      if (localIds.isEmpty) {
        return [];
      }
      rows = await remoteConnection!.execute(
        Sql.named('SELECT id, created_at, updated_at FROM chats WHERE id = ANY(@ids)'),
        parameters: {'ids': localIds},
      );
    } else {
      // Fetch all remote metas when no specific IDs are provided (for initial merge-sync).
      rows = await remoteConnection!.execute(
        Sql.named('SELECT id, created_at, updated_at FROM chats'),
      );
    }

    return rows.map((row) => SyncMeta(
      id: row[0] as int,
      createdAt: row[1] as DateTime,
      updatedAt: row[2] as DateTime
    )).toList();
  }

  @override
  Future<void> push(List<dynamic> ids) async {
    if (ids.isEmpty) return;
    final chatIds = ids.cast<int>();
    final chatsToPush = await (db.select(db.chats)..where((t) => t.id.isIn(chatIds))).get();
    if (chatsToPush.isEmpty) return;
    
    await _batchPushChats(remoteConnection!, chatsToPush);
  }

  @override
  Future<void> pull(List<dynamic> ids) async {
    if (ids.isEmpty) return;
    final chatIds = ids.cast<int>();
    
    final rows = await remoteConnection!.execute(Sql.named('SELECT * FROM chats WHERE id = ANY(@ids)'), parameters: {'ids': chatIds});
    final chatsToPull = rows.map((r) {
        final map = r.toColumnMap();
        return ChatData(
          id: map['id'],
          title: map['title'],
          systemPrompt: map['system_prompt'],
          createdAt: map['created_at'] ?? DateTime.now(),
          updatedAt: map['updated_at'] ?? DateTime.now(),
          coverImageBase64: null, // coverImageBase64 is not synced.
          backgroundImagePath: map['background_image_path'],
          orderIndex: map['order_index'],
          isFolder: map['is_folder'],
          parentFolderId: map['parent_folder_id'],
          contextConfig: const ContextConfigConverter().fromSql(map['context_config']),
          xmlRules: const XmlRuleListConverter().fromSql(map['xml_rules']),
          apiConfigId: map['api_config_id'],
          enablePreprocessing: map['enable_preprocessing'],
          preprocessingPrompt: map['preprocessing_prompt'],
          contextSummary: map['context_summary'],
          preprocessingApiConfigId: map['preprocessing_api_config_id'],
          enableSecondaryXml: map['enable_secondary_xml'],
          secondaryXmlPrompt: map['secondary_xml_prompt'],
          secondaryXmlApiConfigId: map['secondary_xml_api_config_id'],
          continuePrompt: map['continue_prompt'],
          enableHelpMeReply: map['enable_help_me_reply'],
          helpMeReplyPrompt: map['help_me_reply_prompt'],
          helpMeReplyApiConfigId: map['help_me_reply_api_config_id'],
          helpMeReplyTriggerMode: map['help_me_reply_trigger_mode'] == null ? null : const HelpMeReplyTriggerModeConverter().fromSql(map['help_me_reply_trigger_mode']),
        );
    }).toList();
    if (chatsToPull.isEmpty) return;

    await db.batch((batch) {
      batch.insertAll(db.chats, chatsToPull.map((c) => c.toCompanion(true)), mode: InsertMode.insertOrReplace);
    });
  }

  @override
  Future<Map<dynamic, dynamic>> resolveConflicts(List<SyncMeta> localMetas, List<SyncMeta> remoteMetas) async {
    final localIdMap = {for (var meta in localMetas) meta.id: meta};
    final remoteIdMap = {for (var meta in remoteMetas) meta.id: meta};
    final conflictingIds = <int>{};

    for (final id in localIdMap.keys) {
      if (remoteIdMap.containsKey(id)) {
        final localMeta = localIdMap[id]!;
        final remoteMeta = remoteIdMap[id]!;
        if (localMeta.createdAt.toUtc() != remoteMeta.createdAt.toUtc()) {
          conflictingIds.add(id as int);
        }
      }
    }

    final idChangeMap = <int, int>{};
    if (conflictingIds.isNotEmpty) {
      // Optimization: Fetch all potentially affected users into memory once.
      final allUsers = await (db.select(db.users)).get();

      await db.transaction(() async {
        for (final id in conflictingIds) {
          final newId = await _resolveChatConflict(id, allUsers);
          if (newId != null) {
            idChangeMap[id] = newId;
          }
        }
      });
    }
    return idChangeMap;
  }

  @override
  Future<void> deleteRemotely(List<String> keys) async {
    if (keys.isEmpty) return;
    final chatIdsToDelete = keys.map((key) {
      try {
        return int.tryParse(key.substring(1, key.indexOf(','))) ?? -1;
      } catch (e) {
        return -1;
      }
    }).where((id) => id != -1).toList();

    if (chatIdsToDelete.isNotEmpty) {
      await remoteConnection!.execute(Sql.named('DELETE FROM messages WHERE chat_id = ANY(@ids)'), parameters: {'ids': chatIdsToDelete});
      await remoteConnection!.execute(Sql.named('DELETE FROM chats WHERE id = ANY(@ids)'), parameters: {'ids': chatIdsToDelete});
    }
  }

  // ============== CONFLICT RESOLUTION HELPER (moved from SyncService) ==============

  Future<int?> _resolveChatConflict(int oldId, List<DriftUser> allUsers) async {
    final chat = await (db.select(db.chats)..where((tbl) => tbl.id.equals(oldId))).getSingleOrNull();
    if (chat == null) {
      return null;
    }

    final messages = await (db.select(db.messages)..where((tbl) => tbl.chatId.equals(oldId))).get();
    
    final newChatCompanion = chat.toCompanion(false).copyWith(id: const Value.absent());
    final newChat = await db.into(db.chats).insertReturning(newChatCompanion);
    final newId = newChat.id;

    if (messages.isNotEmpty) {
      final messageIds = messages.map((m) => m.id).toList();
      await (db.update(db.messages)..where((tbl) => tbl.id.isIn(messageIds)))
          .write(MessagesCompanion(chatId: Value(newId)));
    }

    await (db.update(db.chats)..where((tbl) => tbl.parentFolderId.equals(oldId)))
        .write(ChatsCompanion(parentFolderId: Value(newId)));

    // Optimization: Instead of querying the DB for each conflict, we now filter the pre-fetched user list in memory.
    // This significantly reduces DB load when many chat conflicts occur.
    final affectedUsers = allUsers.where((user) => user.chatIds?.contains(oldId) ?? false).toList();

    if (affectedUsers.isNotEmpty) {
      await db.batch((batch) {
        for (final user in affectedUsers) {
          final newChatIds = user.chatIds!.map((id) => id == oldId ? newId : id).toList();
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

  Future<void> _batchPushChats(Connection remoteConnection, List<ChatData> chats) async {
    if (chats.isEmpty) return;
    
    await remoteConnection.execute(
      Sql.named('''
        INSERT INTO chats (
          id, title, system_prompt, created_at, updated_at,
          order_index, is_folder, parent_folder_id,
          background_image_path, context_config, xml_rules, api_config_id,
          enable_preprocessing, preprocessing_prompt, context_summary, preprocessing_api_config_id,
          enable_secondary_xml, secondary_xml_prompt, secondary_xml_api_config_id,
          continue_prompt, enable_help_me_reply, help_me_reply_prompt,
          help_me_reply_api_config_id, help_me_reply_trigger_mode
        )
        SELECT
          c.id, c.title, c.system_prompt, c.created_at, c.updated_at,
          c.order_index, c.is_folder, c.parent_folder_id,
          c.background_image_path, c.context_config, c.xml_rules, c.api_config_id,
          c.enable_preprocessing, c.preprocessing_prompt, c.context_summary, c.preprocessing_api_config_id,
          c.enable_secondary_xml, c.secondary_xml_prompt, c.secondary_xml_api_config_id,
          c.continue_prompt, c.enable_help_me_reply, c.help_me_reply_prompt,
          c.help_me_reply_api_config_id, c.help_me_reply_trigger_mode
        FROM UNNEST(
          @ids::integer[], @titles::text[], @system_prompts::text[], @created_ats::timestamp[], @updated_ats::timestamp[],
          @order_indexes::integer[], @is_folders::boolean[], @parent_folder_ids::integer[],
          @background_image_paths::text[], @context_configs::text[], @xml_rules_list::text[], @api_config_ids::text[],
          @enable_preprocessings::boolean[], @preprocessing_prompts::text[], @context_summaries::text[], @preprocessing_api_config_ids::text[],
          @enable_secondary_xmls::boolean[], @secondary_xml_prompts::text[], @secondary_xml_api_config_ids::text[],
          @continue_prompts::text[], @enable_help_me_replies::boolean[], @help_me_reply_prompts::text[],
          @help_me_reply_api_config_ids::text[], @help_me_reply_trigger_modes::text[]
        ) AS c(
          id, title, system_prompt, created_at, updated_at,
          order_index, is_folder, parent_folder_id,
          background_image_path, context_config, xml_rules, api_config_id,
          enable_preprocessing, preprocessing_prompt, context_summary, preprocessing_api_config_id,
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
          context_summary = EXCLUDED.context_summary, preprocessing_api_config_id = EXCLUDED.preprocessing_api_config_id,
          enable_secondary_xml = EXCLUDED.enable_secondary_xml, secondary_xml_prompt = EXCLUDED.secondary_xml_prompt,
          secondary_xml_api_config_id = EXCLUDED.secondary_xml_api_config_id,
          continue_prompt = EXCLUDED.continue_prompt, enable_help_me_reply = EXCLUDED.enable_help_me_reply,
          help_me_reply_prompt = EXCLUDED.help_me_reply_prompt, help_me_reply_api_config_id = EXCLUDED.help_me_reply_api_config_id,
          help_me_reply_trigger_mode = EXCLUDED.help_me_reply_trigger_mode;
      '''),
      parameters: {
        'ids': TypedValue(Type.integerArray, chats.map((c) => c.id).toList()),
        'titles': TypedValue(Type.textArray, chats.map((c) => c.title).toList()),
        'system_prompts': TypedValue(Type.textArray, chats.map((c) => c.systemPrompt).toList()),
        'created_ats': TypedValue(Type.timestampArray, chats.map((c) => c.createdAt).toList()),
        'updated_ats': TypedValue(Type.timestampArray, chats.map((c) => c.updatedAt).toList()),
        'order_indexes': TypedValue(Type.integerArray, chats.map((c) => c.orderIndex).toList()),
        'is_folders': TypedValue(Type.booleanArray, chats.map((c) => c.isFolder).toList()),
        'parent_folder_ids': TypedValue(Type.integerArray, chats.map((c) => c.parentFolderId).toList()),
        'background_image_paths': TypedValue(Type.textArray, chats.map((c) => c.backgroundImagePath).toList()),
        'context_configs': TypedValue(Type.textArray, chats.map((c) => const ContextConfigConverter().toSql(c.contextConfig)).toList()),
        'xml_rules_list': TypedValue(Type.textArray, chats.map((c) => const XmlRuleListConverter().toSql(c.xmlRules)).toList()),
        'api_config_ids': TypedValue(Type.textArray, chats.map((c) => c.apiConfigId).toList()),
        'enable_preprocessings': TypedValue(Type.booleanArray, chats.map((c) => c.enablePreprocessing).toList()),
        'preprocessing_prompts': TypedValue(Type.textArray, chats.map((c) => c.preprocessingPrompt).toList()),
        'context_summaries': TypedValue(Type.textArray, chats.map((c) => c.contextSummary).toList()),
        'preprocessing_api_config_ids': TypedValue(Type.textArray, chats.map((c) => c.preprocessingApiConfigId).toList()),
        'enable_secondary_xmls': TypedValue(Type.booleanArray, chats.map((c) => c.enableSecondaryXml).toList()),
        'secondary_xml_prompts': TypedValue(Type.textArray, chats.map((c) => c.secondaryXmlPrompt).toList()),
        'secondary_xml_api_config_ids': TypedValue(Type.textArray, chats.map((c) => c.secondaryXmlApiConfigId).toList()),
        'continue_prompts': TypedValue(Type.textArray, chats.map((c) => c.continuePrompt).toList()),
        'enable_help_me_replies': TypedValue(Type.booleanArray, chats.map((c) => c.enableHelpMeReply).toList()),
        'help_me_reply_prompts': TypedValue(Type.textArray, chats.map((c) => c.helpMeReplyPrompt).toList()),
        'help_me_reply_api_config_ids': TypedValue(Type.textArray, chats.map((c) => c.helpMeReplyApiConfigId).toList()),
        'help_me_reply_trigger_modes': TypedValue(Type.textArray, chats.map((c) => c.helpMeReplyTriggerMode?.name).toList()),
      }
    );
  }
}
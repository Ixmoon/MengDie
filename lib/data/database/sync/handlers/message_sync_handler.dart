import 'package:drift/drift.dart';
import 'package:postgres/postgres.dart';

import '../../app_database.dart';
import '../sync_meta.dart';
import 'base_sync_handler.dart';
import '../../type_converters.dart';

class MessageSyncHandler extends BaseSyncHandler<MessageData> {
  MessageSyncHandler(super.db, super.remoteConnection);

  @override
  String get entityType => 'messages';

  @override
  Future<List<SyncMeta>> getLocalMetas() async {
    final rows = await (db.selectOnly(db.messages)..addColumns([db.messages.id, db.messages.timestamp, db.messages.updatedAt])).get();
    return rows.map((row) => SyncMeta(
      id: row.read(db.messages.id)!,
      // For messages, timestamp is the creation time.
      createdAt: row.read(db.messages.timestamp)!,
      updatedAt: row.read(db.messages.updatedAt) ?? row.read(db.messages.timestamp)!
    )).toList();
  }

  @override
  Future<List<SyncMeta>> getRemoteMetas({List<dynamic>? localIds}) async {
    Result rows;
    if (localIds != null && localIds.isNotEmpty) {
      // Optimization for conflict resolution: only fetch remote metas for corresponding local IDs.
      rows = await remoteConnection!.execute(
        Sql.named('SELECT id, "timestamp", updated_at FROM messages WHERE id = ANY(@ids)'),
        parameters: {'ids': localIds},
      );
    } else {
      // Fetch all remote metas when no specific IDs are provided.
      rows = await remoteConnection!.execute(
        Sql.named('SELECT id, "timestamp", updated_at FROM messages'),
      );
    }
    
    return rows.map((row) {
      final id = row[0] as int;
      final createdAt = row[1] as DateTime;
      // Handle potential nulls from the database if the column was added recently
      final updatedAt = row[2] is DateTime ? row[2] as DateTime : createdAt;
      return SyncMeta(
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
    }).toList();
  }

  @override
  Future<void> push(List<dynamic> ids) async {
    if (ids.isEmpty) return;
    final messageIds = ids.cast<int>();
    final messagesToPush = await (db.select(db.messages)..where((t) => t.id.isIn(messageIds))).get();
    if (messagesToPush.isEmpty) return;

    await _batchPushMessages(remoteConnection!, messagesToPush);
  }

  @override
  Future<void> pull(List<dynamic> ids) async {
    if (ids.isEmpty) return;
    final messageIds = ids.cast<int>();

    final rows = await remoteConnection!.execute(Sql.named('SELECT * FROM messages WHERE id = ANY(@ids)'), parameters: {'ids': messageIds});
    final messagesToPull = rows.map((row) {
      final map = row.toColumnMap();
      return MessageData(
        id: map['id'],
        chatId: map['chat_id'],
        rawText: map['raw_text'],
        role: const MessageRoleConverter().fromSql(map['role']),
        timestamp: map['timestamp'],
        updatedAt: map['updated_at'],
        originalXmlContent: map['original_xml_content'],
        secondaryXmlContent: map['secondary_xml_content'],
      );
    }).toList();
    if (messagesToPull.isEmpty) return;

    await db.batch((batch) {
      batch.insertAll(db.messages, messagesToPull.map((m) => m.toCompanion(true)), mode: InsertMode.insertOrReplace);
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
      // Pre-fetch any data needed for foreign key updates, similar to ChatSyncHandler.
      // final allSomeOtherEntities = await (db.select(db.someOtherEntities)).get();

      await db.transaction(() async {
        for (final id in conflictingIds) {
          // Pass the pre-fetched data to the conflict resolution helper.
          final newId = await _resolveMessageConflict(id);
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
    final messageIdsToDelete = keys.map((key) {
      try {
        // Assuming the key format is (id, createdAt)
        return int.tryParse(key.substring(1, key.indexOf(','))) ?? -1;
      } catch (e) {
        return -1;
      }
    }).where((id) => id != -1).toList();

    if (messageIdsToDelete.isNotEmpty) {
      await remoteConnection!.execute(Sql.named('DELETE FROM messages WHERE id = ANY(@ids)'), parameters: {'ids': messageIdsToDelete});
    }
  }

  Future<int?> _resolveMessageConflict(int oldId) async {
    final message = await (db.select(db.messages)..where((tbl) => tbl.id.equals(oldId))).getSingleOrNull();
    if (message == null) {
      return null;
    }

    // 1. Create a new message with a new ID
    final newMessageCompanion = message.toCompanion(false).copyWith(id: const Value.absent());
    final newMessage = await db.into(db.messages).insertReturning(newMessageCompanion);
    final newId = newMessage.id;

    // 2. **LINKED UPDATE**: Update all foreign key references in other tables.
    //    Currently, no other table references `messages.id`.
    //    If, in the future, a table `message_attachments` is added with a
    //    `message_id` foreign key, the update logic would be added here:
    //
    //    await (db.update(db.messageAttachments)..where((tbl) => tbl.messageId.equals(oldId)))
    //        .write(MessageAttachmentsCompanion(messageId: Value(newId)));

    // 3. Delete the old message
    await (db.delete(db.messages)..where((tbl) => tbl.id.equals(oldId))).go();

    return newId;
  }

  Future<void> _batchPushMessages(Connection remoteConnection, List<MessageData> messages) async {
    if (messages.isEmpty) return;

    await remoteConnection.execute(
      Sql.named('''
        INSERT INTO messages (id, chat_id, role, raw_text, "timestamp", updated_at, original_xml_content, secondary_xml_content)
        SELECT
          m.id, m.chat_id, m.role, m.raw_text, m.timestamp, m.updated_at, m.original_xml_content, m.secondary_xml_content
        FROM UNNEST(
          @ids::integer[], @chat_ids::integer[], @roles::text[], @raw_texts::text[], @timestamps::timestamp[], @updated_ats::timestamp[], @original_xml_contents::text[], @secondary_xml_contents::text[]
        ) AS m(
          id, chat_id, role, raw_text, "timestamp", updated_at, original_xml_content, secondary_xml_content
        )
        ON CONFLICT (id) DO UPDATE SET
          role = EXCLUDED.role,
          raw_text = EXCLUDED.raw_text,
          "timestamp" = EXCLUDED."timestamp",
          updated_at = EXCLUDED.updated_at,
          original_xml_content = EXCLUDED.original_xml_content,
          secondary_xml_content = EXCLUDED.secondary_xml_content,
          chat_id = EXCLUDED.chat_id;
      '''),
      parameters: {
        'ids': TypedValue(Type.integerArray, messages.map((m) => m.id).toList()),
        'chat_ids': TypedValue(Type.integerArray, messages.map((m) => m.chatId!).toList()),
        'roles': TypedValue(Type.textArray, messages.map((m) => m.role.name).toList()),
        'raw_texts': TypedValue(Type.textArray, messages.map((m) => m.rawText).toList()),
        'timestamps': TypedValue(Type.timestampArray, messages.map((m) => m.timestamp).toList()),
        'updated_ats': TypedValue(Type.timestampArray, messages.map((m) => m.updatedAt ?? m.timestamp).toList()),
        'original_xml_contents': TypedValue(Type.textArray, messages.map((m) => m.originalXmlContent).toList()),
        'secondary_xml_contents': TypedValue(Type.textArray, messages.map((m) => m.secondaryXmlContent).toList()),
      }
    );
  }
}
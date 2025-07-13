import 'package:drift/drift.dart';
import 'package:postgres/postgres.dart';
import '../app_database.dart';
import '../common_enums.dart';
import '../sync/sync_service.dart';
import '../tables/messages.dart';

part 'message_dao.g.dart';

@DriftAccessor(tables: [Messages])
class MessageDao extends DatabaseAccessor<AppDatabase> with _$MessageDaoMixin {
  final AppDatabase db;

  MessageDao(this.db) : super(db);

  Future<List<MessageData>> getMessagesForChat(int chatId, {bool forceRemoteRead = false}) async {
    // Attempt to read from remote first, based on the "OR" logic handled by SyncService.
    final remoteMessages = await SyncService.instance.remoteRead<List<MessageData>>(
      force: forceRemoteRead,
      remoteReadAction: (remote) async {
        final result = await remote.execute(
          'SELECT * FROM messages WHERE chat_id = @chatId ORDER BY timestamp ASC',
          parameters: {'chatId': chatId},
        );
        return result.map((row) => _mapRemoteRowToMessageData(row.toColumnMap())).toList();
      },
    );

    // If we got data from the remote, update the local database.
    if (remoteMessages != null && remoteMessages.isNotEmpty) {
      await batch((b) {
        b.insertAll(messages, remoteMessages, mode: InsertMode.insertOrReplace);
      });
    }

    // Always return data from the local database, which is now up-to-date if remote read succeeded.
    return (select(messages)
          ..where((t) => t.chatId.equals(chatId))
          ..orderBy([(t) => OrderingTerm(expression: t.timestamp)]))
        .get();
  }

  Future<List<MessageData>> getLastNMessagesForChat(int chatId, int n) {
    if (n <= 0) return Future.value([]);
    return (select(messages)
          ..where((t) => t.chatId.equals(chatId))
          ..orderBy([(t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)])
          ..limit(n))
        .get()
        .then((list) => list.reversed.toList());
  }

  Future<MessageData?> getMessageById(int messageId) {
    return (select(messages)..where((t) => t.id.equals(messageId))).getSingleOrNull();
  }

  Future<MessageData?> getLastModelMessage(int chatId) {
    return (select(messages)
          ..where((t) => t.chatId.equals(chatId))
          ..where((t) => t.role.equals("model"))
          ..orderBy([(t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<int> saveMessage(MessagesCompanion message, {bool forceRemoteWrite = false}) async {
    final messageId = await into(messages).insert(message, mode: InsertMode.insertOrReplace);

    SyncService.instance.backgroundWrite(
      force: forceRemoteWrite,
      remoteTransaction: (remote) async {
        final params = _messageToRemoteParams(message.copyWith(id: Value(messageId)));
        await remote.execute(
          'INSERT INTO messages (id, chat_id, role, parts_json, timestamp, original_xml_content, secondary_xml_content) '
          'VALUES (@id, @chat_id, @role, @parts_json, @timestamp, @original_xml_content, @secondary_xml_content) '
          'ON CONFLICT (id) DO UPDATE SET '
          'role = @role, parts_json = @parts_json, timestamp = @timestamp, original_xml_content = @original_xml_content, secondary_xml_content = @secondary_xml_content',
          parameters: params,
        );
      },
      rollbackAction: () async {
        await (delete(messages)..where((t) => t.id.equals(messageId))).go();
      },
    );
    return messageId;
  }

  Future<void> saveMessages(List<MessagesCompanion> messageEntries, {bool forceRemoteWrite = false}) async {
    await batch((batch) {
      batch.insertAll(messages, messageEntries);
    });

    SyncService.instance.backgroundWrite(
      force: forceRemoteWrite,
      remoteTransaction: (remote) async {
        for (final message in messageEntries) {
          final params = _messageToRemoteParams(message);
          await remote.execute(
            'INSERT INTO messages (id, chat_id, role, parts_json, timestamp, original_xml_content, secondary_xml_content) '
            'VALUES (@id, @chat_id, @role, @parts_json, @timestamp, @original_xml_content, @secondary_xml_content) '
            'ON CONFLICT (id) DO UPDATE SET '
            'role = @role, parts_json = @parts_json, timestamp = @timestamp, original_xml_content = @original_xml_content, secondary_xml_content = @secondary_xml_content',
            parameters: params,
          );
        }
      },
      rollbackAction: () async {
        final ids = messageEntries.map((m) => m.id.value).toList();
        await (delete(messages)..where((t) => t.id.isIn(ids))).go();
      },
    );
  }

  Future<bool> deleteMessage(int messageId, {bool forceRemoteWrite = false}) async {
    final messageToDelete = await getMessageById(messageId);
    if (messageToDelete == null) return false;

    final count = await (delete(messages)..where((t) => t.id.equals(messageId))).go();

    if (count > 0) {
      SyncService.instance.backgroundWrite(
        force: forceRemoteWrite,
        remoteTransaction: (remote) async {
          await remote.execute(
            'DELETE FROM messages WHERE id = @id',
            parameters: {'id': messageId},
          );
        },
        rollbackAction: () async {
          await into(messages).insertOnConflictUpdate(messageToDelete.toCompanion(false));
        },
      );
    }
    return count > 0;
  }
  
  Stream<List<MessageData>> watchMessagesForChat(int chatId) {
    return (select(messages)
      ..where((tbl) => tbl.chatId.equals(chatId))
      ..orderBy([(t) => OrderingTerm(expression: t.timestamp)])
    ).watch();
  }

  Map<String, dynamic> _messageToRemoteParams(MessagesCompanion message) {
    return {
      'id': message.id.value,
      'chat_id': message.chatId.value,
      'role': message.role.value.name,
      'parts_json': message.partsJson.value,
      'timestamp': message.timestamp.value,
      'original_xml_content': message.originalXmlContent.value,
      'secondary_xml_content': message.secondaryXmlContent.value,
    };
  }

  /// Helper to map a raw SQL row to a Drift MessageData object.
  MessageData _mapRemoteRowToMessageData(Map<String, dynamic> row) {
    return MessageData(
      id: row['id'],
      chatId: row['chat_id'],
      role: MessageRole.values.byName(row['role']),
      partsJson: row['parts_json'],
      timestamp: row['timestamp'],
      originalXmlContent: row['original_xml_content'],
      secondaryXmlContent: row['secondary_xml_content'],
    );
  }
}

import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/messages.dart';

part 'message_dao.g.dart'; // Drift will generate this file

@DriftAccessor(tables: [Messages])
class MessageDao extends DatabaseAccessor<AppDatabase> with _$MessageDaoMixin {
  final AppDatabase db;

  MessageDao(this.db) : super(db);

  Future<List<MessageData>> getMessagesForChat(int chatId) {
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

  Future<int> saveMessage(MessagesCompanion message) {
    // Use insertOrReplace to handle both new messages (ID is absent) 
    // and existing messages (ID is present, so it will update/replace)
    return into(messages).insert(message, mode: InsertMode.insertOrReplace);
  }

  Future<void> saveMessages(List<MessagesCompanion> messageEntries) {
    return batch((batch) {
      batch.insertAll(messages, messageEntries);
    });
  }

  Future<bool> deleteMessage(int messageId) async {
    final count = await (delete(messages)..where((t) => t.id.equals(messageId))).go();
    return count > 0;
  }
  
  Stream<List<MessageData>> watchMessagesForChat(int chatId) {
    return (select(messages)
      ..where((tbl) => tbl.chatId.equals(chatId))
      ..orderBy([(t) => OrderingTerm(expression: t.timestamp)])
    ).watch();
  }
}

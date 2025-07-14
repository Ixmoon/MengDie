import 'package:drift/drift.dart';
import '../app_database.dart';
import '../common_enums.dart';
import '../tables/messages.dart';

part 'message_dao.g.dart';

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

  Future<MessageData?> findFirstModelMessage(int chatId) {
    return (select(messages)
          ..where((t) => t.chatId.equals(chatId))
          ..where((t) => t.role.equals("model"))
          ..orderBy([(t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.asc)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<int> saveMessage(MessagesCompanion message) {
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

import 'package:drift/drift.dart';
import '../app_database.dart';
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

  Future<int> _updateWithTimestamp(int messageId, MessagesCompanion message) {
    // When updating, we explicitly set the updatedAt field to the current time.
    final companionWithTimestamp = message.copyWith(updatedAt: Value(DateTime.now().toUtc()));
    return (update(messages)..where((t) => t.id.equals(messageId))).write(companionWithTimestamp);
  }

  /// Saves a new message or updates an existing one, ensuring `updatedAt` is handled correctly.
  Future<int> saveOrUpdateMessage(MessagesCompanion message) {
    if (message.id.present && message.id.value > 0) {
      // If an ID is present and valid, it's an update.
      print("Updating message with id: ${message.id.value}");
      return _updateWithTimestamp(message.id.value, message);
    } else {
      // Otherwise, it's a new message.
      print("Inserting new message");
      return into(messages).insert(message.copyWith(id: const Value.absent()));
    }
  }

  Future<void> saveMessages(List<MessagesCompanion> messageEntries) {
    return batch((batch) {
      batch.insertAll(messages, messageEntries);
    });
  }

  Future<int> deleteMessage(int messageId) async {
    return await (delete(messages)..where((t) => t.id.equals(messageId))).go();
  }
  
  Stream<List<MessageData>> watchMessagesForChat(int chatId) {
    return (select(messages)
      ..where((tbl) => tbl.chatId.equals(chatId))
      ..orderBy([(t) => OrderingTerm(expression: t.timestamp)])
    ).watch();
  }
}

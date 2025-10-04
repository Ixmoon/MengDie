import 'package:flutter/foundation.dart';
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
      debugPrint("Updating message with id: ${message.id.value}");
      return _updateWithTimestamp(message.id.value, message);
    } else {
      // Otherwise, it's a new message.
      debugPrint("Inserting new message");
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

  /// Inserts a message at a specific index in the chat's timeline.
  Future<int> insertMessageAt(MessagesCompanion newMessage, int index) async {
    return transaction(() async {
      final chatId = newMessage.chatId.value;
      final allMessagesForChat = await (select(messages)
            ..where((t) => t.chatId.equals(chatId))
            ..orderBy([(t) => OrderingTerm(expression: t.timestamp)]))
          .get();

      DateTime newTimestamp;

      if (allMessagesForChat.isEmpty || index >= allMessagesForChat.length) {
        // Insert at the end
        newTimestamp = DateTime.now().toUtc();
      } else if (index <= 0) {
        // Insert at the beginning
        final firstTimestamp = allMessagesForChat.first.timestamp;
        newTimestamp = firstTimestamp.subtract(const Duration(milliseconds: 1));
      } else {
        // Insert in the middle
        final prevTimestamp = allMessagesForChat[index - 1].timestamp;
        final nextTimestamp = allMessagesForChat[index].timestamp;
        final middleMillis = (prevTimestamp.millisecondsSinceEpoch + nextTimestamp.millisecondsSinceEpoch) ~/ 2;
        newTimestamp = DateTime.fromMillisecondsSinceEpoch(middleMillis, isUtc: true);
        
        // Ensure timestamp is unique, though extremely unlikely to collide.
        if (newTimestamp.isAtSameMomentAs(prevTimestamp) || newTimestamp.isAtSameMomentAs(nextTimestamp)) {
          newTimestamp = nextTimestamp.subtract(const Duration(milliseconds: 1));
        }
      }

      final companionWithTimestamp = newMessage.copyWith(
        timestamp: Value(newTimestamp),
        id: const Value.absent(), // Ensure it's an insert
      );

      return await into(messages).insert(companionWithTimestamp);
    });
  }
  
  Stream<List<MessageData>> watchMessagesForChat(int chatId) {
    return (select(messages)
      ..where((tbl) => tbl.chatId.equals(chatId))
      ..orderBy([(t) => OrderingTerm(expression: t.timestamp)])
    ).watch();
  }
}

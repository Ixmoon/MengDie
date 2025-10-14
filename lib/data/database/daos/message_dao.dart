import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/messages.dart';

part 'message_dao.g.dart';

@DriftAccessor(tables: [Messages])
class MessageDao extends DatabaseAccessor<AppDatabase> with _$MessageDaoMixin {
  final AppDatabase db;

  MessageDao(this.db) : super(db);

  Future<List<MessageData>> getMessagesForChat(
    int chatId, {
    int? afterMessageId,
  }) {
    final query = select(messages)
      ..where((t) => t.chatId.equals(chatId))
      ..orderBy([(t) => OrderingTerm(expression: t.timestamp)]);

    if (afterMessageId != null) {
      query.where((t) => t.id.isBiggerThanValue(afterMessageId));
    }

    return query.get();
  }

  Future<List<MessageData>> getLastNMessagesForChat(int chatId, int n) {
    if (n <= 0) return Future.value([]);
    return (select(messages)
          ..where((t) => t.chatId.equals(chatId))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc),
          ])
          ..limit(n))
        .get()
        .then((list) => list.reversed.toList());
  }

  Future<MessageData?> getMessageById(int messageId) {
    return (select(
      messages,
    )..where((t) => t.id.equals(messageId))).getSingleOrNull();
  }

  Future<MessageData?> getLastModelMessage(int chatId) {
    return (select(messages)
          ..where((t) => t.chatId.equals(chatId))
          ..where((t) => t.role.equals("model"))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<MessageData?> findFirstModelMessage(int chatId) {
    return (select(messages)
          ..where((t) => t.chatId.equals(chatId))
          ..where((t) => t.role.equals("model"))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.timestamp, mode: OrderingMode.asc),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<int> _updateWithTimestamp(int messageId, MessagesCompanion message) {
    // When updating, we explicitly set the updatedAt field to the current time.
    final companionWithTimestamp = message.copyWith(
      updatedAt: Value(DateTime.now().toUtc()),
    );
    return (update(
      messages,
    )..where((t) => t.id.equals(messageId))).write(companionWithTimestamp);
  }

  /// Saves a new message or updates an existing one, ensuring `updatedAt` is handled correctly.
  Future<int> saveOrUpdateMessage(MessagesCompanion message) {
    final now = DateTime.now().toUtc();
    final companionWithTime = message.copyWith(
      timestamp: message.timestamp.present ? message.timestamp : Value(now),
      updatedAt: message.updatedAt.present ? message.updatedAt : Value(now),
      id: message.id.present ? message.id : const Value.absent(),
    );
    if (companionWithTime.id.present && companionWithTime.id.value > 0) {
      return _updateWithTimestamp(
        companionWithTime.id.value,
        companionWithTime,
      );
    } else {
      return into(messages).insert(companionWithTime);
    }
  }

  Future<void> saveMessages(List<MessagesCompanion> messageEntries) {
    final now = DateTime.now().toUtc();
    final safeEntries = messageEntries
        .map(
          (msg) => msg.copyWith(
            timestamp: msg.timestamp.present ? msg.timestamp : Value(now),
            updatedAt: msg.updatedAt.present ? msg.updatedAt : Value(now),
            id: msg.id.present ? msg.id : const Value.absent(),
          ),
        )
        .toList();
    return batch((batch) {
      batch.insertAll(messages, safeEntries);
    });
  }

  Future<int> deleteMessage(int messageId) async {
    return await (delete(messages)..where((t) => t.id.equals(messageId))).go();
  }

  Future<int> deleteMessagesAfter(int chatId, int messageId) {
    return transaction(() async {
      final targetMessage = await getMessageById(messageId);
      if (targetMessage == null) return 0;

      return (delete(messages)
            ..where((t) => t.chatId.equals(chatId))
            ..where((t) => t.timestamp.isBiggerThanValue(targetMessage.timestamp
                .toUtc()
                .microsecondsSinceEpoch)))
          .go();
    });
  }

  /// Inserts a message at a specific index in the chat's timeline.
  Future<int> insertMessageAt(MessagesCompanion newMessage, int index) async {
    return transaction(() async {
      final chatId = newMessage.chatId.value;
      final allMessagesForChat =
          await (select(messages)
                ..where((t) => t.chatId.equals(chatId))
                ..orderBy([(t) => OrderingTerm(expression: t.timestamp)]))
              .get();

      DateTime newTimestamp;

      if (allMessagesForChat.isEmpty || index >= allMessagesForChat.length) {
        newTimestamp = DateTime.now().toUtc();
      } else if (index <= 0) {
        final firstTimestamp = allMessagesForChat.first.timestamp;
        newTimestamp = firstTimestamp.subtract(const Duration(milliseconds: 1));
      } else {
        final prevTimestamp = allMessagesForChat[index - 1].timestamp;
        final nextTimestamp = allMessagesForChat[index].timestamp;
        final middleMillis =
            (prevTimestamp.millisecondsSinceEpoch +
                nextTimestamp.millisecondsSinceEpoch) ~/
            2;
        newTimestamp = DateTime.fromMillisecondsSinceEpoch(
          middleMillis,
          isUtc: true,
        );
        if (newTimestamp.isAtSameMomentAs(prevTimestamp) ||
            newTimestamp.isAtSameMomentAs(nextTimestamp)) {
          newTimestamp = nextTimestamp.subtract(
            const Duration(milliseconds: 1),
          );
        }
      }

      final companionWithTimestamp = newMessage.copyWith(
        timestamp: Value(newTimestamp),
        updatedAt: newMessage.updatedAt.present
            ? newMessage.updatedAt
            : Value(newTimestamp),
        id: const Value.absent(),
      );

      return await into(messages).insert(companionWithTimestamp);
    });
  }

  Stream<List<MessageData>> watchMessagesForChat(int chatId) {
    return (select(messages)
          ..where((tbl) => tbl.chatId.equals(chatId))
          ..orderBy([(t) => OrderingTerm(expression: t.timestamp)]))
        .watch();
  }
}

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../domain/models/chat.dart';
import '../app_database.dart';
import '../tables/chats.dart';
import '../tables/messages.dart';

part 'chat_dao.g.dart'; // Drift will generate this file

@DriftAccessor(tables: [Chats, Messages])
class ChatDao extends DatabaseAccessor<AppDatabase> with _$ChatDaoMixin {
  final AppDatabase db;

  ChatDao(this.db) : super(db);

  // --- Database Operations ---

  Future<List<ChatData>> getAllChats() {
    return (select(chats)..orderBy([
          (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
        ]))
        .get();
  }

  Future<ChatData?> getChat(int chatId) {
    return (select(chats)..where((t) => t.id.equals(chatId))).getSingleOrNull();
  }

  Future<int> saveChat(ChatsCompanion chat) {
    final now = DateTime.now();
    final companionWithTime = chat.copyWith(
      createdAt: chat.createdAt.present ? chat.createdAt : Value(now),
      updatedAt: chat.updatedAt.present ? chat.updatedAt : Value(now),
    );
    return into(
      chats,
    ).insert(companionWithTime, mode: InsertMode.insertOrReplace);
  }

  Future<void> updateChat(ChatsCompanion chat) {
    final now = DateTime.now();
    final companionWithTime = chat.copyWith(
      updatedAt: chat.updatedAt.present ? chat.updatedAt : Value(now),
    );
    return (update(
      chats,
    )..where((t) => t.id.equals(chat.id.value))).write(companionWithTime);
  }

  /// Efficiently updates the `updatedAt` timestamp for a given chat.
  Future<void> touchChat(int chatId) {
    return (update(chats)..where((t) => t.id.equals(chatId))).write(
      ChatsCompanion(updatedAt: Value(DateTime.now())),
    );
  }

  Future<bool> deleteChatAndMessages(int chatId) async {
    final count = await db.transaction(() async {
      await (delete(messages)..where((t) => t.chatId.equals(chatId))).go();
      return await (delete(chats)..where((t) => t.id.equals(chatId))).go();
    });
    return count > 0;
  }

  Future<int> deleteMultipleChatsAndMessages(List<int> chatIds) async {
    if (chatIds.isEmpty) return 0;
    return db.transaction(() async {
      await (delete(messages)..where((t) => t.chatId.isIn(chatIds))).go();
      return await (delete(chats)..where((t) => t.id.isIn(chatIds))).go();
    });
  }

  Future<void> updateChatOrder(List<ChatsCompanion> chatsToUpdate) async {
    if (chatsToUpdate.isEmpty) return;

    await db.transaction(() async {
      for (final chatCompanion in chatsToUpdate) {
        final companionWithTime = chatCompanion.copyWith(
          updatedAt: Value(DateTime.now()),
        );
        await (update(chats)..where((t) => t.id.equals(chatCompanion.id.value)))
            .write(companionWithTime);
      }
    });
  }

  Future<void> moveChatsToNewParent(
    List<int> chatIds,
    int? newParentFolderId,
  ) async {
    if (chatIds.isEmpty) return;

    await (update(chats)..where((t) => t.id.isIn(chatIds))).write(
      ChatsCompanion(
        parentFolderId: Value(newParentFolderId),
        orderIndex: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // --- Database Listening Streams ---

  Stream<List<ChatData>> watchChatsInFolder(int? parentFolderId) {
    final query = select(chats)
      ..where(
        (t) => parentFolderId == null
            ? t.parentFolderId.isNull()
            : t.parentFolderId.equals(parentFolderId),
      )
      ..orderBy([
        // 最终修正：手动排序的项目（orderIndex 非 null）在后，自动排序的项目（orderIndex 为 null）在前
        (t) => OrderingTerm(
          expression: t.orderIndex,
          mode: OrderingMode.asc,
          nulls: NullsOrder.first,
        ),
        // 自动排序的项目内部，按创建时间倒序，实现“新建的在最前”
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ]);
    return query.watch();
  }

  Stream<ChatData?> watchChat(int chatId) {
    return (select(
      chats,
    )..where((t) => t.id.equals(chatId))).watchSingleOrNull();
  }

  /// 监听特定用户的聊天列表。
  Stream<List<ChatData>> watchChatsForUser(
    List<int> chatIds,
    int? parentFolderId,
  ) {
    final query = select(chats)
      ..where(
        (t) =>
            t.id.isIn(chatIds) &
            (parentFolderId == null
                ? t.parentFolderId.isNull()
                : t.parentFolderId.equals(parentFolderId)),
      )
      ..orderBy([
        (t) => OrderingTerm(
          expression: t.orderIndex,
          mode: OrderingMode.asc,
          nulls: NullsOrder.first,
        ),
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ]);
    return query.watch();
  }

  /// 监听游客和孤儿聊天。
  Stream<List<ChatData>> watchOrphanChats({
    required List<int> guestChatIds,
    required List<int> ownedChatIds,
    int? parentFolderId,
  }) {
    final query = select(chats)
      ..where((t) {
        // 条件：
        // 1. 聊天ID不在任何已注册用户的列表中 (孤儿聊天)
        //    或者
        // 2. 聊天ID在游客自己的列表中
        final isOrphan = t.id.isNotIn(ownedChatIds);
        final isGuestsOwn = t.id.isIn(guestChatIds);
        // 文件夹过滤条件
        final folderCondition = parentFolderId == null
            ? t.parentFolderId.isNull()
            : t.parentFolderId.equals(parentFolderId);

        return (isOrphan | isGuestsOwn) & folderCondition;
      })
      ..orderBy([
        (t) => OrderingTerm(
          expression: t.orderIndex,
          mode: OrderingMode.asc,
          nulls: NullsOrder.first,
        ),
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ]);
    return query.watch();
  }

  /// 获取所有**非游客**用户的聊天ID列表。
  /// 这是为了识别哪些聊天是“孤儿”聊天（不属于任何注册用户）。
  Future<List<int>> getAllOwnedChatIds() async {
    // 通过添加 where 条件排除了 id 为 0 的游客用户
    final allUsers = await (db.userDao.db.select(
      db.userDao.db.users,
    )..where((u) => u.id.isNotValue(0))).get();
    final allOwnedIds = <int>{};
    for (final user in allUsers) {
      // Safely add chat IDs, ensuring the list is not null.
      final chatIds = user.chatIds;
      if (chatIds != null) {
        allOwnedIds.addAll(chatIds);
      }
    }
    return allOwnedIds.toList();
  }

  Future<List<ChatData>> getChatsInFolder(int? parentFolderId) {
    final query = select(chats)
      ..where(
        (t) => parentFolderId == null
            ? t.parentFolderId.isNull()
            : t.parentFolderId.equals(parentFolderId),
      )
      ..orderBy([
        // 最终修正：手动排序的项目（orderIndex 非 null）在后，自动排序的项目（orderIndex 为 null）在前
        (t) => OrderingTerm(
          expression: t.orderIndex,
          mode: OrderingMode.asc,
          nulls: NullsOrder.first,
        ),
        // 自动排序的项目内部，按创建时间倒序，实现“新建的在最前”
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ]);
    return query.get();
  }

  // --- Import Chat (Refactored to use Domain Model) ---
  Future<int> importChat(Chat chat, {int? parentFolderId}) async {
    final chatCompanion = ChatsCompanion.insert(
      title: Value(chat.title),
      systemPrompt: Value(chat.systemPrompt),
      isFolder: Value(chat.isFolder),
      contextConfig: chat.contextConfig,
      xmlRules: chat.xmlRules,
      createdAt: Value(chat.createdAt),
      updatedAt: Value(chat.updatedAt),
      apiConfigId: Value(chat.apiConfigId),
      parentFolderId: Value(parentFolderId),
      orderIndex: Value(chat.orderIndex),
      coverImageBase64: Value(chat.coverImageBase64),
      backgroundImagePath: Value(chat.backgroundImagePath),
      enablePreprocessing: Value(chat.enablePreprocessing),
      preprocessingPrompt: Value(chat.preprocessingPrompt),
      preprocessingApiConfigId: Value(chat.preprocessingApiConfigId),
      enableSecondaryXml: Value(chat.enableSecondaryXml),
      secondaryXmlPrompt: Value(chat.secondaryXmlPrompt),
      secondaryXmlApiConfigId: Value(chat.secondaryXmlApiConfigId),
      contextSummary: Value(chat.contextSummary),
      continuePrompt: Value(chat.continuePrompt),
      enableHelpMeReply: Value(chat.enableHelpMeReply),
      helpMeReplyPrompt: Value(chat.helpMeReplyPrompt),
      helpMeReplyApiConfigId: Value(chat.helpMeReplyApiConfigId),
      helpMeReplyTriggerMode: Value(chat.helpMeReplyTriggerMode),
    );

    return db.transaction(() async {
      final newChatId = await db.into(db.chats).insert(chatCompanion);

      final List<MessagesCompanion> messageCompanions = [];
      for (final message in chat.messages) {
        final rawText = jsonEncode(
          message.parts.map((p) => p.toJson()).toList(),
        );
        final msgNow = message.timestamp;
        messageCompanions.add(
          MessagesCompanion.insert(
            chatId: newChatId,
            rawText: rawText,
            role: message.role,
            timestamp: Value(msgNow),
            updatedAt: Value(message.updatedAt ?? msgNow),
            originalXmlContent: Value(message.originalXmlContent),
            secondaryXmlContent: Value(message.secondaryXmlContent),
          ),
        );
      }

      if (messageCompanions.isNotEmpty) {
        await db.batch((batch) {
          batch.insertAll(db.messages, messageCompanions);
        });
      }
      return newChatId;
    });
  }

  /// 通用方法，用于分叉或克隆聊天。
  ///
  /// [newChatCompanion] 是预设好的新聊天对象。
  /// [originalChatId] 是原始聊天的ID。
  /// [upToMessageId] (可选) 如果提供，则只复制到此消息ID为止（分叉行为）。
  /// 如果为 null，则复制所有消息（克隆行为）。
  Future<int> forkOrCloneChat(
    ChatsCompanion newChatCompanion,
    int originalChatId, {
    int? upToMessageId,
  }) async {
    return db.transaction(() async {
      // 1. 插入由 Repository 层准备好的新聊天记录
      final newChatId = await into(chats).insert(newChatCompanion);

      // 2. 构建消息查询
      final query = select(messages)
        ..where((t) => t.chatId.equals(originalChatId))
        ..orderBy([(t) => OrderingTerm(expression: t.timestamp)]);

      // 如果是分叉，则添加消息ID限制
      if (upToMessageId != null) {
        query.where((t) => t.id.isSmallerOrEqualValue(upToMessageId));
      }

      final messagesToCopy = await query.get();

      // 3. 为新聊天创建新的消息副本
      final List<MessagesCompanion> newMessages = [];
      for (final msg in messagesToCopy) {
        newMessages.add(
          msg
              .toCompanion(true)
              .copyWith(
                id: const Value.absent(), // 新的自增ID
                chatId: Value(newChatId), // 关联到新的聊天ID
              ),
        );
      }

      // 4. 批量插入复制的消息
      if (newMessages.isNotEmpty) {
        await batch((batch) {
          batch.insertAll(messages, newMessages);
        });
      }

      return newChatId;
    });
  }

  /// 查找所有 backgroundImagePath 包含 '/template' 但 parentFolderId 不为 null 的聊天。
  Future<List<ChatData>> findLostTemplates() {
    final query = select(chats)
      ..where(
        (t) =>
            t.backgroundImagePath.like('%/template%') &
            t.parentFolderId.isNotNull(),
      );
    return query.get();
  }

  /// 查找特定父文件夹下的同名模板文件夹。
  Future<ChatData?> findTemplateFolder(String title, int? parentId) {
    final query = select(chats)
      ..where(
        (t) =>
            t.title.equals(title) &
            t.isFolder.equals(true) &
            t.backgroundImagePath.equals('/template/folder'),
      );
    if (parentId == null) {
      query.where((t) => t.parentFolderId.isNull());
    } else {
      query.where((t) => t.parentFolderId.equals(parentId));
    }
    return query.getSingleOrNull();
  }

  /// 将所有 parentFolderId 指向不存在的文件夹的项目移动到根目录。
  Future<int> cleanUpOrphanedItems() async {
    final allFolderIds = await (select(
      chats,
    )..where((t) => t.isFolder.equals(true))).map((c) => c.id).get();
    final Set<int> folderIdSet = Set.from(allFolderIds);

    final orphanedItems =
        await (select(chats)..where(
              (t) =>
                  t.parentFolderId.isNotNull() &
                  t.parentFolderId.isNotIn(folderIdSet),
            ))
            .get();

    if (orphanedItems.isEmpty) {
      return 0;
    }

    final List<int> idsToUpdate = orphanedItems.map((c) => c.id).toList();

    final updatedRowCount =
        await (update(chats)..where((t) => t.id.isIn(idsToUpdate))).write(
          const ChatsCompanion(parentFolderId: Value(null)),
        );

    return updatedRowCount;
  }
}

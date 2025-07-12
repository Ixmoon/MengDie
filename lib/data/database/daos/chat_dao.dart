import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/chats.dart';
import 'dart:convert';
import '../tables/messages.dart'; // For deleting related messages
import '../../models/export_import_dtos.dart'; // For DTOs in importChat
import '../models/drift_context_config.dart';
import '../models/drift_xml_rule.dart';
import '../common_enums.dart' as drift_enums;


part 'chat_dao.g.dart'; // Drift will generate this file

@DriftAccessor(tables: [Chats, Messages])
class ChatDao extends DatabaseAccessor<AppDatabase> with _$ChatDaoMixin {
  final AppDatabase db;

  ChatDao(this.db) : super(db);

  // --- Database Operations ---

  Future<List<ChatData>> getAllChats() {
    return (select(chats)..orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)])).get();
  }

  Future<ChatData?> getChat(int chatId) {
    return (select(chats)..where((t) => t.id.equals(chatId))).getSingleOrNull();
  }

  Future<int> saveChat(ChatsCompanion chat) async {
    // The companion's updatedAt should be set before calling this
    return into(chats).insert(chat, mode: InsertMode.insertOrReplace);
  }
  
  Future<void> updateChat(ChatsCompanion chat) async {
    await (update(chats)..where((t) => t.id.equals(chat.id.value))).write(chat);
  }


  Future<bool> deleteChatAndMessages(int chatId) {
    return transaction(() async {
      // 1. Delete associated messages
      await (delete(messages)..where((t) => t.chatId.equals(chatId))).go();
      // 2. Delete the chat itself
      final count = await (delete(chats)..where((t) => t.id.equals(chatId))).go();
      return count > 0;
    });
  }

  Future<int> deleteMultipleChatsAndMessages(List<int> chatIds) {
    if (chatIds.isEmpty) return Future.value(0);
    return transaction(() async {
      int totalDeleted = 0;
      // 1. Delete associated messages for all chats
      await (delete(messages)..where((t) => t.chatId.isIn(chatIds))).go();
      // 2. Delete the chats themselves
      totalDeleted = await (delete(chats)..where((t) => t.id.isIn(chatIds))).go();
      return totalDeleted;
    });
  }

  Future<void> updateChatOrder(List<ChatsCompanion> chatsToUpdate) {
    if (chatsToUpdate.isEmpty) return Future.value();
    return transaction(() async {
      for (final chatCompanion in chatsToUpdate) {
        await (update(chats)..where((t) => t.id.equals(chatCompanion.id.value))).write(chatCompanion);
      }
    });
  }

  /// 批量移动聊天到新的父文件夹。
  Future<void> moveChatsToNewParent(List<int> chatIds, int? newParentFolderId) {
    if (chatIds.isEmpty) return Future.value();
    return (update(chats)..where((t) => t.id.isIn(chatIds))).write(
      ChatsCompanion(
        parentFolderId: Value(newParentFolderId),
        orderIndex: const Value(null), // 移动到新文件夹后，重置排序
      ),
    );
  }

  // --- Database Listening Streams ---

  Stream<List<ChatData>> watchChatsInFolder(int? parentFolderId) {
    final query = select(chats)
      ..where((t) => parentFolderId == null ? t.parentFolderId.isNull() : t.parentFolderId.equals(parentFolderId))
      ..orderBy([
       // 最终修正：手动排序的项目（orderIndex 非 null）在后，自动排序的项目（orderIndex 为 null）在前
       (t) => OrderingTerm(expression: t.orderIndex, mode: OrderingMode.asc, nulls: NullsOrder.first),
       // 自动排序的项目内部，按创建时间倒序，实现“新建的在最前”
       (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
      ]);
    return query.watch();
  }

  Stream<ChatData?> watchChat(int chatId) {
    return (select(chats)..where((t) => t.id.equals(chatId))).watchSingleOrNull();
  }

  Future<List<ChatData>> getChatsInFolder(int? parentFolderId) {
    final query = select(chats)
      ..where((t) => parentFolderId == null ? t.parentFolderId.isNull() : t.parentFolderId.equals(parentFolderId))
      ..orderBy([
       // 最终修正：手动排序的项目（orderIndex 非 null）在后，自动排序的项目（orderIndex 为 null）在前
       (t) => OrderingTerm(expression: t.orderIndex, mode: OrderingMode.asc, nulls: NullsOrder.first),
       // 自动排序的项目内部，按创建时间倒序，实现“新建的在最前”
       (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
      ]);
    return query.get();
  }

  // --- Import Chat ---
  Future<int> importChatFromDto(ChatExportDto chatDto, AppDatabase attachedDb, {int? parentFolderId}) async {
    final contextConfigDrift = DriftContextConfig(
        mode: drift_enums.ContextManagementMode.values.firstWhere(
                  (e) => e.name == chatDto.contextConfig.mode.name,
                  orElse:()=> drift_enums.ContextManagementMode.turns),
        maxTurns: chatDto.contextConfig.maxTurns,
        maxContextTokens: chatDto.contextConfig.maxContextTokens,
      );

    final xmlRulesDrift = chatDto.xmlRules.map((dto) =>
        DriftXmlRule(
          tagName: dto.tagName,
          action: drift_enums.XmlAction.values.firstWhere(
                      (e) => e.name == dto.action.name,
                      orElse: ()=> drift_enums.XmlAction.ignore)
        )
      ).toList();
    
    final now = DateTime.now();

    final chatCompanion = ChatsCompanion.insert(
      title: Value(chatDto.title),
      systemPrompt: Value(chatDto.systemPrompt),
      isFolder: Value(chatDto.isFolder),
      contextConfig: contextConfigDrift,
      xmlRules: xmlRulesDrift,
      // 优先使用 DTO 中的时间戳，否则使用当前时间作为备用
      createdAt: chatDto.createdAt ?? now,
      updatedAt: chatDto.updatedAt ?? now,
      apiConfigId: Value(chatDto.apiConfigId),
      parentFolderId: Value(parentFolderId),
      orderIndex: const Value(0),
      coverImageBase64: Value(chatDto.coverImageBase64),
      backgroundImagePath: const Value(null),
      // new fields
      enablePreprocessing: Value(chatDto.enablePreprocessing),
      preprocessingPrompt: Value(chatDto.preprocessingPrompt),
      preprocessingApiConfigId: Value(chatDto.preprocessingApiConfigId),
      enableSecondaryXml: Value(chatDto.enableSecondaryXml),
      secondaryXmlPrompt: Value(chatDto.secondaryXmlPrompt),
      secondaryXmlApiConfigId: Value(chatDto.secondaryXmlApiConfigId),
      contextSummary: Value(chatDto.contextSummary),
      continuePrompt: Value(chatDto.continuePrompt),
    );

    return attachedDb.transaction(() async {
      final newChatId = await attachedDb.into(attachedDb.chats).insert(chatCompanion);

      final List<MessagesCompanion> messageCompanions = [];
      for (final messageDto in chatDto.messages) {
        String partsJson;
        // Prioritize the new 'parts' field if it exists and is not empty
        if (messageDto.parts != null && messageDto.parts!.isNotEmpty) {
          partsJson = jsonEncode(messageDto.parts);
        } else {
          // Fallback to legacy 'rawText'
          final parts = [{'type': 'text', 'text': messageDto.rawText}];
          partsJson = jsonEncode(parts);
        }

        messageCompanions.add(
          MessagesCompanion.insert(
            chatId: newChatId,
            partsJson: partsJson,
            role: messageDto.role, // DTO now uses the same enum
            timestamp: DateTime.now(), // MessageExportDto does not have timestamp, generate new
          )
        );
      }

      if (messageCompanions.isNotEmpty) {
        await attachedDb.batch((batch) {
          batch.insertAll(attachedDb.messages, messageCompanions);
        });
      }
      return newChatId;
    });
    // return Future.value(0); // Remove dummy return
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
        newMessages.add(msg.toCompanion(true).copyWith(
          id: const Value.absent(), // 新的自增ID
          chatId: Value(newChatId), // 关联到新的聊天ID
        ));
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
}

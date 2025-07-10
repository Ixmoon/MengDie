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

  // --- Database Listening Streams ---

  Stream<List<ChatData>> watchChatsInFolder(int? parentFolderId) {
    final query = select(chats)
      ..where((t) => parentFolderId == null ? t.parentFolderId.isNull() : t.parentFolderId.equals(parentFolderId))
      ..orderBy([
        (t) => OrderingTerm(expression: t.orderIndex, mode: OrderingMode.asc, nulls: NullsOrder.last),
        (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)
      ]);
    return query.watch();
  }

  Stream<ChatData?> watchChat(int chatId) {
    return (select(chats)..where((t) => t.id.equals(chatId))).watchSingleOrNull();
  }

  // --- Import Chat ---
  Future<int> importChatFromDto(ChatExportDto chatDto, AppDatabase attachedDb) async {
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
      createdAt: now,
      updatedAt: now,
      apiConfigId: Value(chatDto.apiConfigId),
      parentFolderId: const Value(null),
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

  Future<int> forkChat(int originalChatId, int fromMessageId) async {
    return db.transaction(() async {
      // 1. Get the original chat
      final originalChat = await getChat(originalChatId);
      if (originalChat == null) {
        throw Exception('Original chat not found for forking.');
      }

      // 2. Create a new chat companion from the original, resetting some fields
      final now = DateTime.now();
      final forkedChatCompanion = originalChat.toCompanion(true).copyWith(
        id: const Value.absent(), // New ID will be assigned
        title: Value('${originalChat.title} (Forked)'),
        createdAt: Value(now),
        updatedAt: Value(now),
        contextSummary: const Value(null), // Clear summary on fork
      );
      
      final newChatId = await into(chats).insert(forkedChatCompanion);

      // 3. Get messages from the original chat up to the specified message ID
      final messagesToCopy = await (select(messages)
        ..where((t) => t.chatId.equals(originalChatId))
        ..where((t) => t.id.isSmallerOrEqualValue(fromMessageId))
        ..orderBy([(t) => OrderingTerm(expression: t.timestamp)])
      ).get();

      // 4. Create new message companions for the new chat
      final List<MessagesCompanion> newMessages = [];
      for (final msg in messagesToCopy) {
        newMessages.add(msg.toCompanion(true).copyWith(
          id: const Value.absent(), // New ID
          chatId: Value(newChatId), // Link to the new chat
        ));
      }

      // 5. Batch insert the copied messages
      if (newMessages.isNotEmpty) {
        await batch((batch) {
          batch.insertAll(messages, newMessages);
        });
      }

      return newChatId;
    });
  }
}

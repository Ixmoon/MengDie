import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/chats.dart';
import 'dart:convert';
import '../tables/messages.dart'; // For deleting related messages
import '../../../../models/export_import_dtos.dart'; // For DTOs in importChat
// Import the new Drift model classes if needed for conversion, or the original ones if they are kept
import '../models/drift_generation_config.dart';
import '../models/drift_context_config.dart';
import '../models/drift_xml_rule.dart';
import '../models/drift_safety_setting_rule.dart'; // Added import for DriftSafetySettingRule
import '../common_enums.dart' as drift_enums; // Alias to avoid conflict with old enums


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
    // Implementation for importing chat from DTO
    // print("ChatDao.importChatFromDto is not fully implemented yet for Drift."); // Remove print

    final generationConfigDrift = DriftGenerationConfig(
        modelName: chatDto.generationConfig.modelName,
        temperature: chatDto.generationConfig.temperature,
        topP: chatDto.generationConfig.topP,
        topK: chatDto.generationConfig.topK,
        maxOutputTokens: chatDto.generationConfig.maxOutputTokens,
        stopSequences: chatDto.generationConfig.stopSequences,
        useCustomTemperature: chatDto.generationConfig.useCustomTemperature, // 新增
        useCustomTopP: chatDto.generationConfig.useCustomTopP, // 新增
        useCustomTopK: chatDto.generationConfig.useCustomTopK, // 新增
        safetySettings: chatDto.generationConfig.safetySettings.map((dto) {
            // Assuming DTO enums (LocalHarmCategory, LocalHarmBlockThreshold) are from 'models/enums.dart'
            // and drift_enums are from '../common_enums.dart'
            // The DTO uses LocalHarmCategory from models/enums.dart, which should be compatible if names match
            final dtoCategoryName = dto.category.name; // Assuming .name gives string like 'harassment'
            final dtoThresholdName = dto.threshold.name;

            return DriftSafetySettingRule( // This class is from ../models/drift_safety_setting_rule.dart
              category: drift_enums.LocalHarmCategory.values.firstWhere(
                  (e) => e.name == dtoCategoryName, 
                  orElse: () => drift_enums.LocalHarmCategory.unknown),
              threshold: drift_enums.LocalHarmBlockThreshold.values.firstWhere(
                  (e) => e.name == dtoThresholdName, 
                  orElse: () => drift_enums.LocalHarmBlockThreshold.unspecified),
            );
          }
        ).toList(),
      );

    final contextConfigDrift = DriftContextConfig(
        mode: drift_enums.ContextManagementMode.values.firstWhere(
                  (e) => e.name == chatDto.contextConfig.mode.name, // DTO uses ContextManagementMode from 'models/enums.dart'
                  orElse:()=> drift_enums.ContextManagementMode.turns), // Default to 'turns'
        maxTurns: chatDto.contextConfig.maxTurns,
        maxContextTokens: chatDto.contextConfig.maxContextTokens,
      );

    final xmlRulesDrift = chatDto.xmlRules.map((dto) =>
        DriftXmlRule(
          tagName: dto.tagName, 
          action: drift_enums.XmlAction.values.firstWhere(
                      (e) => e.name == dto.action.name, // DTO uses XmlAction from 'models/enums.dart'
                      orElse: ()=> drift_enums.XmlAction.ignore)
        )
      ).toList();
    
    final now = DateTime.now();

    // Fields not in ChatExportDto: apiType, selectedOpenAIConfigId, parentFolderId, orderIndex, coverImagePath, backgroundImagePath
    final chatCompanion = ChatsCompanion.insert(
      title: Value(chatDto.title),
      systemPrompt: Value(chatDto.systemPrompt),
      isFolder: Value(chatDto.isFolder), // DTO has isFolder, default is false
      generationConfig: generationConfigDrift, 
      contextConfig: contextConfigDrift,       
      xmlRules: xmlRulesDrift,                 
      createdAt: now,
      updatedAt: now,
      // apiType is not in ChatExportDto, default to gemini or make it nullable in table if it can be absent
      apiType: drift_enums.LlmType.values.firstWhere(
                    (e) => e.name == chatDto.apiType.name, // DTO 使用 LlmType from 'models/enums.dart'
                    orElse: () => drift_enums.LlmType.gemini), // 默认值
      selectedOpenAIConfigId: Value(chatDto.selectedOpenAIConfigId), // 使用 DTO 中的 selectedOpenAIConfigId
      parentFolderId: const Value(null),      // Not in DTO
      orderIndex: const Value(0),              // Not in DTO, default to 0
      // coverImagePath: const Value(null),    // 移除或注释掉，因为我们现在使用 Base64
      coverImageBase64: Value(chatDto.coverImageBase64), // 新增：使用 DTO 中的 Base64 字符串
      backgroundImagePath: const Value(null),  // Not in DTO
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
}

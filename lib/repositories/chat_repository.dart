import 'package:flutter/material.dart'; // for debugPrint
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value; // For Value() and absent
// import 'package:isar/isar.dart'; // Removed Isar

// 导入模型和核心 Provider
import '../models/models.dart'; // Still used for Chat, Message model classes
import '../models/export_import_dtos.dart'; // 导入 DTOs
import '../providers/core_providers.dart'; // Needs appDatabaseProvider
import '../data/database/drift/app_database.dart'; 
import '../data/database/drift/daos/chat_dao.dart'; // Import ChatDao for type annotation
// drift_tables alias might not be strictly necessary if AppDatabase.g.dart exports companions correctly.
// For now, let's assume ChatsCompanion is accessible via AppDatabase or its generated parts.

// 本文件包含用于管理 Chat 数据集合的仓库类和提供者。

// --- Chat Repository Provider ---
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final appDb = ref.watch(appDatabaseProvider);
  return ChatRepository(appDb);
});

// --- Chat Repository Implementation ---
class ChatRepository {
  final AppDatabase _db;
  late final ChatDao _chatDao; // DAO for chat operations

  ChatRepository(this._db) {
    _chatDao = _db.chatDao; // Initialize DAO from AppDatabase instance
  }

  // Helper to convert Drift ChatData to original Chat model
  Chat _fromChatData(ChatData data) {
    // Assumes Chat model in collection_models.dart now uses Drift-compatible types for embedded objects and enums
    return Chat()
      ..id = data.id
      ..title = data.title
      ..systemPrompt = data.systemPrompt
      ..createdAt = data.createdAt
      ..updatedAt = data.updatedAt
      // ..coverImagePath = data.coverImagePath // 旧字段，ChatData 中已不存在
      ..coverImageBase64 = data.coverImageBase64 // 新字段：从 ChatData 读取 Base64
      ..backgroundImagePath = data.backgroundImagePath
      ..orderIndex = data.orderIndex
      ..isFolder = data.isFolder
      ..parentFolderId = data.parentFolderId
      ..generationConfig = data.generationConfig // This is DriftGenerationConfig from drift/models
      ..contextConfig = data.contextConfig     // This is DriftContextConfig from drift/models
      ..xmlRules = data.xmlRules               // This is List<DriftXmlRule> from drift/models
      ..apiType = data.apiType                 // This is drift_enums.LlmType from drift/common_enums
      ..selectedOpenAIConfigId = data.selectedOpenAIConfigId;
  }

  // Helper to convert original Chat model to Drift ChatsCompanion
  ChatsCompanion _toChatsCompanion(Chat chat, {bool updateTime = true}) {
    DateTime newUpdatedAt = updateTime ? DateTime.now() : chat.updatedAt;
    
    return ChatsCompanion( // Assuming ChatsCompanion is available from app_database.g.dart or tables.dart
      id: chat.id == 0 ? const Value.absent() : Value(chat.id),
      title: Value(chat.title),
      systemPrompt: Value(chat.systemPrompt),
      createdAt: Value(chat.createdAt),
      updatedAt: Value(newUpdatedAt),
      // coverImagePath: Value(chat.coverImagePath), // 旧字段
      coverImageBase64: Value(chat.coverImageBase64), // 新字段：将 Chat 模型中的 Base64 写入 Companion
      backgroundImagePath: Value(chat.backgroundImagePath),
      orderIndex: Value(chat.orderIndex),
      isFolder: Value(chat.isFolder),
      parentFolderId: Value(chat.parentFolderId),
      // These fields in Chat model are now DriftGenerationConfig, DriftContextConfig, etc.
      // The TypeConverter in the table definition handles conversion to String for DB.
      // Companion expects the Dart type.
      generationConfig: Value(chat.generationConfig), 
      contextConfig: Value(chat.contextConfig),       
      xmlRules: Value(chat.xmlRules),                 
      apiType: Value(chat.apiType),                   
      selectedOpenAIConfigId: Value(chat.selectedOpenAIConfigId),
    );
  }


  // --- 数据库操作 ---
  Future<List<Chat>> getAllChats() async {
    debugPrint("ChatRepository: 获取所有聊天 (Drift)...");
    final chatDataList = await _chatDao.getAllChats();
    return chatDataList.map(_fromChatData).toList();
  }

  Future<Chat?> getChat(int chatId) async {
    debugPrint("ChatRepository: 获取聊天 ID: $chatId (Drift)...");
    final chatData = await _chatDao.getChat(chatId);
    return chatData != null ? _fromChatData(chatData) : null;
  }

  Future<int> saveChat(Chat chat) async {
    debugPrint("ChatRepository: 保存聊天 ID: ${chat.id}, 标题: ${chat.title} (Drift)...");
    final companion = _toChatsCompanion(chat);
    return await _chatDao.saveChat(companion); // saveChat in DAO handles insertOrReplace
  }
  
  Future<bool> deleteChat(int chatId) async {
    debugPrint("ChatRepository: 删除聊天 ID: $chatId 及其消息 (Drift)...");
    return await _chatDao.deleteChatAndMessages(chatId);
  }

  Future<int> deleteChats(List<int> chatIds) async {
    if (chatIds.isEmpty) return 0;
    debugPrint("ChatRepository: 批量删除聊天 IDs: $chatIds 及其消息 (Drift)...");
    return await _chatDao.deleteMultipleChatsAndMessages(chatIds);
  }

  Future<void> updateChatOrder(List<Chat> chatsToUpdate) async {
    if (chatsToUpdate.isEmpty) return;
    debugPrint("ChatRepository: 批量更新 ${chatsToUpdate.length} 个聊天的 orderIndex (Drift)...");
    final companions = chatsToUpdate.map((c) => _toChatsCompanion(c, updateTime: true)).toList();
    await _chatDao.updateChatOrder(companions);
    debugPrint("ChatRepository: 批量更新 orderIndex 完成 (Drift)。");
  }

  // --- 数据库监听流 ---
  Stream<List<Chat>> watchChatsInFolder(int? parentFolderId) {
    debugPrint("ChatRepository: 监听文件夹 ID: $parentFolderId 下的聊天变化 (Drift)...");
    return _chatDao.watchChatsInFolder(parentFolderId).map((list) => list.map(_fromChatData).toList());
  }

  Stream<Chat?> watchChat(int chatId) {
    debugPrint("ChatRepository: 监听聊天 ID: $chatId 的变化 (Drift)...");
    return _chatDao.watchChat(chatId).map((data) => data != null ? _fromChatData(data) : null);
  }

  // --- 导入聊天 ---
  Future<int> importChat(ChatExportDto chatDto) async {
    debugPrint("ChatRepository: 开始导入聊天: ${chatDto.title ?? '无标题'} (Drift)...");
    // The DAO method importChatFromDto needs the AppDatabase instance itself for transactions with type converters
    return await _chatDao.importChatFromDto(chatDto, _db);
  }
}

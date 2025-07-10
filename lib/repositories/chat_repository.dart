import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart'; // for debugPrint
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 导入模型和核心 Provider
import '../models/models.dart';
import '../models/export_import_dtos.dart'; // 导入 DTOs
import '../providers/core_providers.dart'; // Needs appDatabaseProvider
import '../database/app_database.dart'; 
import '../database/daos/chat_dao.dart'; // Import ChatDao for type annotation
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

  // --- 数据库操作 ---
  Future<List<Chat>> getAllChats() async {
    debugPrint("ChatRepository: 获取所有聊天 (Drift)...");
    final chatDataList = await _chatDao.getAllChats();
    return chatDataList.map(Chat.fromData).toList();
  }

  Future<Chat?> getChat(int chatId) async {
    debugPrint("ChatRepository: 获取聊天 ID: $chatId (Drift)...");
    final chatData = await _chatDao.getChat(chatId);
    return chatData != null ? Chat.fromData(chatData) : null;
  }

  Future<int> saveChat(Chat chat) async {
    debugPrint("ChatRepository: 保存聊天 ID: ${chat.id}, 标题: ${chat.title} (Drift)...");
    final companion = chat.toCompanion(forInsert: chat.id == 0);
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
    final companions = chatsToUpdate.map((c) => c.toCompanion(updateTime: true)).toList();
    await _chatDao.updateChatOrder(companions);
    debugPrint("ChatRepository: 批量更新 orderIndex 完成 (Drift)。");
  }

  // --- 数据库监听流 ---
  Stream<List<Chat>> watchChatsInFolder(int? parentFolderId) {
    debugPrint("ChatRepository: 监听文件夹 ID: $parentFolderId 下的聊天变化 (Drift)...");
    return _chatDao.watchChatsInFolder(parentFolderId).map((list) => list.map(Chat.fromData).toList());
  }

  Stream<Chat?> watchChat(int chatId) {
    debugPrint("ChatRepository: 监听聊天 ID: $chatId 的变化 (Drift)...");
    return _chatDao.watchChat(chatId).map((data) => data != null ? Chat.fromData(data) : null);
  }

  // --- 导入聊天 ---
  Future<int> importChat(ChatExportDto chatDto) async {
    debugPrint("ChatRepository: 开始导入聊天: ${chatDto.title ?? '无标题'} (Drift)...");
    return await _chatDao.importChatFromDto(chatDto, _db);
  }

  Future<int> forkChat(int originalChatId, int fromMessageId) async {
    debugPrint("ChatRepository: Forking chat ID: $originalChatId from message ID: $fromMessageId (Drift)...");
    return await _chatDao.forkChat(originalChatId, fromMessageId);
  }

  // --- Migration Helpers ---
  Future<List<Map<String, dynamic>>> getRawChatsForMigration() async {
    // This is a raw query to fetch data from columns that may no longer exist in the schema
    // This is an advanced Drift feature and should be used with caution.
    final result = await _db.customSelect('SELECT id, title, generation_config, api_type FROM chats').get();
    return result.map((row) {
      final data = row.data;
      // The generation_config is a JSON string, so we need to decode it.
      if (data['generation_config'] is String) {
        data['generation_config'] = json.decode(data['generation_config']);
      }
      return data;
    }).toList();
  }

  Future<void> updateApiConfigId(int chatId, String apiConfigId) async {
    await (_db.update(_db.chats)..where((t) => t.id.equals(chatId)))
        .write(ChatsCompanion(apiConfigId: Value(apiConfigId)));
  }
}

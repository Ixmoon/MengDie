import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart'; // for debugPrint
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat.dart';
import '../models/export_import_dtos.dart';
import '../../providers/core_providers.dart';
import '../database/app_database.dart';
import '../database/common_enums.dart';
import '../database/daos/api_config_dao.dart';
import '../database/daos/chat_dao.dart';
import '../mappers/chat_mapper.dart';

// 本文件包含用于管理 Chat 数据集合的仓库类和提供者。

// --- Chat Repository Provider ---
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final appDb = ref.watch(appDatabaseProvider);
  // Now depends on both chatDao and apiConfigDao
  return ChatRepository(appDb, appDb.chatDao, appDb.apiConfigDao);
});

// --- Chat Repository Implementation ---
class ChatRepository {
  final AppDatabase _db;
  final ChatDao _chatDao;
  final ApiConfigDao _apiConfigDao;

  ChatRepository(this._db, this._chatDao, this._apiConfigDao);

  // --- 数据库操作 ---
  Future<List<Chat>> getAllChats() async {
    debugPrint("ChatRepository: 获取所有聊天 (Drift)...");
    final chatDataList = await _chatDao.getAllChats();
    return chatDataList.map(ChatMapper.fromData).toList();
  }

  Future<Chat?> getChat(int chatId) async {
    debugPrint("ChatRepository: 获取聊天 ID: $chatId (Drift)...");
    final chatData = await _chatDao.getChat(chatId);
    return chatData != null ? ChatMapper.fromData(chatData) : null;
  }

  Future<int> saveChat(Chat chat) async {
    debugPrint("ChatRepository: 保存聊天 ID: ${chat.id}, 标题: ${chat.title} (Drift)...");

    LlmType? apiType;
    if (chat.apiConfigId != null) {
      final apiConfigData = await _apiConfigDao.getApiConfigById(chat.apiConfigId!);
      if (apiConfigData != null) {
        apiType = apiConfigData.apiType;
      }
    }

    final companion = ChatMapper.toCompanion(chat, forInsert: chat.id == 0, apiType: apiType);
    return await _chatDao.saveChat(companion);
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
    final companions = chatsToUpdate.map((c) => ChatMapper.toCompanion(c)).toList();
    await _chatDao.updateChatOrder(companions);
    debugPrint("ChatRepository: 批量更新 orderIndex 完成 (Drift)。");
  }

  // --- 数据库监听流 ---
  Stream<List<Chat>> watchChatsInFolder(int? parentFolderId) {
    debugPrint("ChatRepository: 监听文件夹 ID: $parentFolderId 下的聊天变化 (Drift)...");
    return _chatDao
        .watchChatsInFolder(parentFolderId)
        .map((list) => list.map(ChatMapper.fromData).toList());
  }

  Stream<Chat?> watchChat(int chatId) {
    debugPrint("ChatRepository: 监听聊天 ID: $chatId 的变化 (Drift)...");
    return _chatDao
        .watchChat(chatId)
        .map((data) => data != null ? ChatMapper.fromData(data) : null);
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

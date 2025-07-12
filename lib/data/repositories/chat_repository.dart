import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart'; // for debugPrint
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat.dart';
import '../models/chat.dart';
import '../models/export_import_dtos.dart';
import '../../ui/providers/core_providers.dart';
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
    final chatData = await _chatDao.getChat(chatId);
    return chatData != null ? ChatMapper.fromData(chatData) : null;
  }

  Future<int> saveChat(Chat chat) async {

    LlmType? apiType;
    if (chat.apiConfigId != null) {
      final apiConfigData = await _apiConfigDao.getApiConfigById(chat.apiConfigId!);
      if (apiConfigData != null) {
        apiType = apiConfigData.apiType;
      }
    }
    // Lmmediate Fix: Ensure apiType is not null to prevent crashes on older schemas.
    // Default to a safe value if no config is found.
    apiType ??= LlmType.gemini;

    final companion = ChatMapper.toCompanion(chat, forInsert: chat.id == 0, apiType: apiType);
    return await _chatDao.saveChat(companion);
  }

  /// 新增一个文件夹，可以是普通文件夹或模板文件夹
  Future<int> addFolder({
    required String title,
    bool isTemplate = false,
    int? parentFolderId,
  }) async {
    debugPrint("ChatRepository: 新增文件夹: $title, 是否为模板: $isTemplate");
    // 模板文件夹使用特殊的时间戳，普通文件夹使用当前时间
    final timestamp = isTemplate ? kTemplateTimestamp : DateTime.now();
    final newFolder = Chat(
      title: title,
      isFolder: true,
      parentFolderId: parentFolderId,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    // 调用 saveChat 来实际保存
    return await saveChat(newFolder);
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

  // 新增：非响应式地获取文件夹内容
  Future<List<Chat>> getChatsInFolder(int? parentFolderId) async {
    debugPrint("ChatRepository: 获取文件夹 ID: $parentFolderId 下的聊天 (Drift)...");
    final chatDataList = await _chatDao.getChatsInFolder(parentFolderId);
    return chatDataList.map(ChatMapper.fromData).toList();
  }

  Future<void> updateChatOrder(List<Chat> chatsToUpdate) async {
    if (chatsToUpdate.isEmpty) return;
    debugPrint("ChatRepository: 批量更新 ${chatsToUpdate.length} 个聊天的 orderIndex (Drift)...");
    final companions = chatsToUpdate.map((c) => ChatMapper.toCompanion(c)).toList();
    await _chatDao.updateChatOrder(companions);
    debugPrint("ChatRepository: 批量更新 orderIndex 完成 (Drift)。");
  }

  /// 批量移动一个或多个聊天到新的父文件夹。
  ///
  /// [chatIds] 要移动的聊天的ID列表。
  /// [newParentFolderId] 目标文件夹的ID。如果为 null，则移动到根目录。
  Future<void> moveChatsToNewParent({
    required List<int> chatIds,
    required int? newParentFolderId,
  }) async {
    if (chatIds.isEmpty) return;
    debugPrint("ChatRepository: 批量移动聊天 $chatIds 到文件夹 $newParentFolderId...");
    await _chatDao.moveChatsToNewParent(chatIds, newParentFolderId);
    debugPrint("ChatRepository: 批量移动完成。");
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
  Future<int> importChat(ChatExportDto chatDto, {int? parentFolderId}) async {
    debugPrint("ChatRepository: 开始导入聊天: ${chatDto.title ?? '无标题'} 到文件夹 ID: $parentFolderId (Drift)...");
    return await _chatDao.importChatFromDto(chatDto, _db, parentFolderId: parentFolderId);
  }

  Future<int> forkChat(int originalChatId, int fromMessageId) async {
    debugPrint("ChatRepository: 分叉聊天 ID: $originalChatId 从消息 ID: $fromMessageId...");
    final originalChat = await getChat(originalChatId);
    if (originalChat == null) {
      throw Exception('找不到ID为 $originalChatId 的原始聊天');
    }

    // 为分叉准备新的 Chat Companion
    final now = DateTime.now();
    final forkedChatCompanion = ChatMapper.toCompanion(originalChat, forInsert: true)
      .copyWith(
        title: Value('${originalChat.title} (分叉)'),
        createdAt: Value(now),
        updatedAt: Value(now),
        contextSummary: const Value(null), // 分叉时清除上下文摘要
        orderIndex: const Value(null), // 分叉的聊天应使用默认排序
    );
    
    // 调用通用的 DAO 方法，并传入消息ID以上限
    return await _chatDao.forkOrCloneChat(
      forkedChatCompanion,
      originalChatId,
      upToMessageId: fromMessageId,
    );
  }

  /// 从一个现有聊天创建新聊天（作为模板），可以指定父文件夹。
  Future<int> createChatFromTemplate(int templateChatId, {int? parentFolderId}) async {
    debugPrint("ChatRepository: 从模板 ID: $templateChatId 创建新聊天到文件夹 ID: $parentFolderId...");
    final templateChat = await getChat(templateChatId);
    if (templateChat == null) {
      throw Exception('找不到ID为 $templateChatId 的模板聊天');
    }

    final now = DateTime.now();
    
    // 使用 copyWith 创建一个新实例，并重置关键字段
    final newChat = templateChat.copyWith({
      'id': 0, // 关键：重置ID以创建新记录
      'title': templateChat.title ?? "无标题", // 使用模板的原始标题
      'createdAt': now, // 关键：设置为当前时间
      'updatedAt': now, // 关键：设置为当前时间
      'parentFolderId': parentFolderId, // 关键：设置新的父文件夹ID
      'orderIndex': null, // 总是放在列表顶部
    });

    // 保存这个新创建的聊天，它将没有任何消息
    return await saveChat(newChat);
  }

  /// 从现有聊天克隆设置，创建一个新的空聊天或模板。
  ///
  /// [sourceChatId] 是被克隆的原始聊天的ID。
  /// [asTemplate] 如果为 true, 克隆体将被保存为模板，否则为普通聊天。
  /// 返回新创建的聊天的ID。
  Future<int> cloneChat(int sourceChatId, {required bool asTemplate}) async {
    debugPrint("ChatRepository: 克隆聊天设置 ID: $sourceChatId, 作为模板: $asTemplate...");
    final originalChat = await getChat(sourceChatId);
    if (originalChat == null) {
      throw Exception('找不到ID为 $sourceChatId 的原始聊天');
    }

    // 准备新聊天的标题和时间戳
    final newTitle = originalChat.title ?? "无标题"; // 直接使用原始标题
    final timestamp = asTemplate ? kTemplateTimestamp : DateTime.now();

    // 使用 copyWith 创建一个新实例，并重置关键字段
    final newChat = originalChat.copyWith({
      'id': 0, // 关键：重置ID以创建新记录
      'title': newTitle,
      'createdAt': timestamp,
      'updatedAt': timestamp,
      'parentFolderId': null, // 总是克隆到根目录
      'orderIndex': null, // 总是放在列表顶部
      'contextSummary': null, // 清空上下文摘要
    });
    
    // 直接保存这个新的Chat对象，它将不包含任何消息
    return await saveChat(newChat);
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

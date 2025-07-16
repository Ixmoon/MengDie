import 'package:drift/drift.dart';
import 'package:stream_transform/stream_transform.dart';
import 'package:flutter/material.dart'; // for debugPrint
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat.dart';
import '../models/export_import_dtos.dart';
import '../mappers/user_mapper.dart';

import '../database/app_database.dart';

import '../database/daos/api_config_dao.dart';
import '../database/daos/chat_dao.dart';
import '../database/daos/user_dao.dart';
import '../mappers/chat_mapper.dart';
import '../../ui/providers/auth_providers.dart';
import '../../ui/providers/repository_providers.dart';


// 本文件包含用于管理 Chat 数据集合的仓库类和提供者。

// --- Chat Repository Implementation ---
class ChatRepository {
  final Ref _ref;
  final AppDatabase _db;
  final ChatDao _chatDao;
  final ApiConfigDao _apiConfigDao;
  final UserDao _userDao;

  ChatRepository(this._ref, this._db, this._chatDao, this._apiConfigDao, this._userDao);

  /// 检查当前用户登录状态，如果已登录，则将新创建的项目ID与其关联。
  Future<void> _bindItemToCurrentUser(int itemId) async {
    final authState = _ref.read(authProvider);
    if (authState.currentUser != null) {
      // 使用 read 方法获取最新的 UserRepository 实例
      await _ref.read(userRepositoryProvider).addChatIdToUser(authState.currentUser!.id, itemId);
    }
  }
  
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

    final companion = ChatMapper.toCompanion(chat, forInsert: chat.id == 0);
    final newId = await _chatDao.saveChat(companion);
    // 如果是新增操作 (id=0)，则自动绑定到当前用户
    if (chat.id == 0) {
      await _bindItemToCurrentUser(newId);
    }
    return newId;
  }

  /// 新增一个文件夹，可以是普通文件夹或模板文件夹
  Future<int> addFolder({
    required String title,
    bool isTemplate = false,
    int? parentFolderId,
  }) async {
    debugPrint("ChatRepository: 新增文件夹: $title, 是否为模板: $isTemplate");
    final now = DateTime.now();
    final newFolder = Chat(
      title: title,
      isFolder: true,
      parentFolderId: parentFolderId,
      createdAt: now,
      updatedAt: now,
      orderIndex: null, // 确保新文件夹置顶
      backgroundImagePath: isTemplate ? '/template/folder' : null, // 新的模板逻辑
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

  Stream<List<Chat>> watchChatsForUser(int userId, int? parentFolderId) {
    // 彻底重构：严格遵循分层设计原则
    // 1. 监听原始 DriftUser? 数据流
    return _userDao.watchUser(userId)
        // 2. **立即**将数据库实体映射为领域模型。这是关键。
        //    在数据流的早期进行转换，确保下游逻辑处理的是干净、可靠的对象。
        .map((driftUser) => driftUser != null ? UserMapper.fromDrift(driftUser) : null)
        // 3. 使用 switchMap 将 User? 数据流转换为聊天列表数据流
        .switchMap((user) {
      // 如果用户不存在，返回空列表流
      if (user == null) {
        return Stream.value([]);
      }

      // 4. 根据用户类型（游客或普通用户）构建查询
      //    由于我们现在处理的是领域模型 User，可以确信 user.chatIds 永远不为 null。
      if (user.id == 0) {
        // 对于游客，查询逻辑保持不变，但不再需要空值检查。
        return Stream.fromFuture(_chatDao.getAllOwnedChatIds()).switchMap((ownedChatIds) {
          return _chatDao.watchOrphanChats(
            guestChatIds: user.chatIds, // 直接使用，无需 `?? []`
            ownedChatIds: ownedChatIds,
            parentFolderId: parentFolderId,
          );
        }).map((list) => list.map(ChatMapper.fromData).toList());
      } else {
        // 对于普通用户，如果聊天列表为空，直接返回空流。
        if (user.chatIds.isEmpty) {
          return Stream.value([]);
        }
        // 否则，监听属于该用户的聊天。
        return _chatDao
            .watchChatsForUser(user.chatIds, parentFolderId)
            .map((list) => list.map(ChatMapper.fromData).toList());
      }
    });
  }

  // --- 导入聊天 ---
  Future<int> importChat(ChatExportDto chatDto, {int? parentFolderId}) async {
    debugPrint("ChatRepository: 开始导入聊天: ${chatDto.title ?? '无标题'} 到文件夹 ID: $parentFolderId (Drift)...");
    final newChatId = await _chatDao.importChatFromDto(chatDto, _db, parentFolderId: parentFolderId);
    await _bindItemToCurrentUser(newChatId);
    return newChatId;
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
    final newChatId = await _chatDao.forkOrCloneChat(
      forkedChatCompanion,
      originalChatId,
      upToMessageId: fromMessageId,
    );
    await _bindItemToCurrentUser(newChatId);
    return newChatId;
    
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
      'orderIndex': null, // 确保新聊天置顶
      'backgroundImagePath': null, // 关键：从模板创建的聊天不是模板
    });

    // saveChat 将自动处理用户绑定
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
    final now = DateTime.now();

    // 使用 copyWith 创建一个新实例，并重置关键字段
    final newChat = originalChat.copyWith({
      'id': 0, // 关键：重置ID以创建新记录
      'title': newTitle,
      'createdAt': now,
      'updatedAt': now,
      'parentFolderId': null, // 总是克隆到根目录
      'orderIndex': null, // 确保克隆体置顶
      'contextSummary': null, // 清空上下文摘要
      'backgroundImagePath': asTemplate ? '/template/chat' : null, // 新的模板逻辑
    });
    
    // 直接保存这个新的Chat对象，它将不包含任何消息
    return await saveChat(newChat);
  }

}

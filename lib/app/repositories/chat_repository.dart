import 'package:drift/drift.dart';
import 'package:stream_transform/stream_transform.dart';
import 'package:flutter/material.dart'; // for debugPrint
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/chat.dart';
import '../../data/mappers/user_mapper.dart';

import '../../data/database/app_database.dart';

import '../../data/database/daos/chat_dao.dart';
import '../../data/database/daos/user_dao.dart';
import '../../data/mappers/chat_mapper.dart';
import '../providers/auth_providers.dart';
import '../providers/repository_providers.dart';


// 本文件包含用于管理 Chat 数据集合的仓库类和提供者。

// --- Chat Repository Implementation ---
class ChatRepository {
  final Ref _ref;
  final AppDatabase _db;
  final ChatDao _chatDao;
  final UserDao _userDao;

  ChatRepository(this._ref, this._db, this._chatDao, this._userDao);

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

  // --- 导入聊天 (已重构) ---
  Future<int> importChat(Chat chat, {int? parentFolderId}) async {
    debugPrint("ChatRepository: 开始导入聊天: ${chat.title ?? '无标题'} 到文件夹 ID: $parentFolderId (Drift)...");
    final newChatId = await _chatDao.importChat(chat, _db, parentFolderId: parentFolderId);
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
    final newChat = templateChat.copyWith(
      id: 0, // 关键：重置ID以创建新记录
      title: templateChat.title ?? "无标题", // 使用模板的原始标题
      createdAt: now, // 关键：设置为当前时间
      updatedAt: now, // 关键：设置为当前时间
      parentFolderId: parentFolderId, // 关键：设置新的父文件夹ID
      orderIndex: null, // 确保新聊天置顶
      backgroundImagePath: null, // 关键：从模板创建的聊天不是模板
    );

    // saveChat 将自动处理用户绑定
    return await saveChat(newChat);
  }

  /// 统一的聊天衍生方法，用于处理分叉、克隆和模板创建。
  ///
  /// [sourceChatId] 原始聊天的 ID。
  /// [upToMessageId]
  ///   - `null`: 复制所有消息 (用于导出等场景)。
  ///   - `0`: 不复制任何消息 (用于克隆、另存为模板)。
  ///   - `> 0`: 复制到指定消息ID为止 (用于分叉)。
  /// [asTemplate] 如果为 true, 新聊天将被标记为模板。
  Future<int> duplicateChat(
    int sourceChatId, {
    int? upToMessageId,
    bool asTemplate = false,
    bool shouldClearSummary = true, // 新增参数，默认为 true 以保持旧行为的安全性
  }) async {
    debugPrint("ChatRepository: duplicateChat from $sourceChatId, upToMessageId: $upToMessageId, asTemplate: $asTemplate");

    final originalChat = await getChat(sourceChatId);
    if (originalChat == null) {
      throw Exception('找���到ID为 $sourceChatId 的原始聊天');
    }

    final now = DateTime.now();
    String newTitle;
    final baseTitle = originalChat.title ?? "无标题";

    // 仅在非模板操作时增加标题序号
    if (!asTemplate) {
      final RegExp titleRegex = RegExp(r'^(.*)-(\d+)$');
      final Match? match = titleRegex.firstMatch(baseTitle);
      if (match != null) {
        final namePart = match.group(1);
        final numberPart = int.tryParse(match.group(2) ?? '');
        if (namePart != null && numberPart != null) {
          newTitle = '$namePart-${numberPart + 1}';
        } else {
          newTitle = '$baseTitle-1';
        }
      } else {
        newTitle = '$baseTitle-1';
      }
    } else {
      newTitle = baseTitle;
    }

    final newChatCompanion = ChatMapper.toCompanion(originalChat, forInsert: true).copyWith(
      title: Value(newTitle),
      createdAt: Value(now),
      updatedAt: Value(now),
      // 核心修改：根据 shouldClearSummary 的值来决定是否保留或清除总结。
      contextSummary: shouldClearSummary ? const Value(null) : Value(originalChat.contextSummary),
      lastSummarizedMessageId: shouldClearSummary ? const Value(null) : Value(originalChat.lastSummarizedMessageId),
      orderIndex: const Value(null),
      // 关键修复：如果是另存为模板，则强制将其放入根目录，忽略原始文件夹。
      parentFolderId: asTemplate ? const Value(null) : Value(originalChat.parentFolderId),
      backgroundImagePath: asTemplate ? const Value('/template/chat') : const Value(null),
    );

    int newChatId;
    if (upToMessageId == 0) {
      // 不复制任何消息：直接保存新的 Chat 对象
      newChatId = await _chatDao.saveChat(newChatCompanion);
    } else {
      // 复制部分或全部消息
      newChatId = await _chatDao.forkOrCloneChat(
        newChatCompanion,
        sourceChatId,
        upToMessageId: upToMessageId, // null 表示全部复制
      );
    }

    await _bindItemToCurrentUser(newChatId);
    return newChatId;
  }

  /// 找回并修复因旧版 bug 导致被错误归类到文件夹中的模板。
  /// 返回被修复的模板数量。
  Future<int> recoverLostTemplates() async {
    debugPrint("ChatRepository: 正在执行丢失模板恢复检查...");
    final lostTemplates = await _chatDao.findLostTemplates();
    if (lostTemplates.isEmpty) {
      debugPrint("ChatRepository: 未发现丢失的模板。");
      return 0;
    }

    final idsToRecover = lostTemplates.map((c) => c.id).toList();
    debugPrint("ChatRepository: 发现 ${idsToRecover.length} 个丢失的模板，正在将其移至根目录...");
    
    await _chatDao.moveChatsToNewParent(idsToRecover, null);
    
    debugPrint("ChatRepository: 模板恢复完成。");
    return idsToRecover.length;
  }
}

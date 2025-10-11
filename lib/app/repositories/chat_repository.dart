import 'package:drift/drift.dart';
import 'package:stream_transform/stream_transform.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/chat.dart';
import '../../data/mappers/user_mapper.dart';

import '../../data/database/daos/chat_dao.dart';
import '../../data/database/daos/user_dao.dart';
import '../../data/mappers/chat_mapper.dart';
import '../providers/auth_providers.dart';
import '../providers/repository_providers.dart';

// 本文件包含用于管理 Chat 数据集合的仓库类和提供者。

// --- Chat Repository Implementation ---
class ChatRepository {
  final Ref _ref;
  final ChatDao _chatDao;
  final UserDao _userDao;

  ChatRepository(this._ref, this._chatDao, this._userDao) {
    // 在仓库初始化时，异步执行一次清理操作
    _cleanUpOrphanedChats();
  }

  /// 检查当前用户登录状态，如果已登录，则将新创建的项目ID与其关联。
  Future<void> _bindItemToCurrentUser(int itemId) async {
    final authState = _ref.read(authProvider);
    if (authState.currentUser != null) {
      // 使用 read 方法获取最新的 UserRepository 实例
      await _ref
          .read(userRepositoryProvider)
          .addChatIdToUser(authState.currentUser!.id, itemId);
    }
  }

  // --- 数据库操作 ---
  Future<List<Chat>> getAllChats() async {
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
    return await _chatDao.deleteChatAndMessages(chatId);
  }

  Future<int> deleteChats(List<int> chatIds) async {
    if (chatIds.isEmpty) return 0;
    return await _chatDao.deleteMultipleChatsAndMessages(chatIds);
  }

  // 新增：非响应式地获取文件夹内容
  Future<List<Chat>> getChatsInFolder(int? parentFolderId) async {
    final chatDataList = await _chatDao.getChatsInFolder(parentFolderId);
    return chatDataList.map(ChatMapper.fromData).toList();
  }

  Future<void> updateChatOrder(List<Chat> chatsToUpdate) async {
    if (chatsToUpdate.isEmpty) return;
    final companions = chatsToUpdate
        .map((c) => ChatMapper.toCompanion(c))
        .toList();
    await _chatDao.updateChatOrder(companions);
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
    await _chatDao.moveChatsToNewParent(chatIds, newParentFolderId);
  }

  // --- 数据库监听流 ---
  Stream<List<Chat>> watchChatsInFolder(int? parentFolderId) {
    return _chatDao
        .watchChatsInFolder(parentFolderId)
        .map((list) => list.map(ChatMapper.fromData).toList());
  }

  Stream<Chat?> watchChat(int chatId) {
    return _chatDao
        .watchChat(chatId)
        .map((data) => data != null ? ChatMapper.fromData(data) : null);
  }

  Stream<List<Chat>> watchChatsForUser(int userId, int? parentFolderId) {
    // 彻底重构：严格遵循分层设计原则
    // 1. 监听原始 DriftUser? 数据流
    return _userDao
        .watchUser(userId)
        // 2. **立即**将数据库实体映射为领域模型。这是关键。
        //    在数据流的早期进行转换，确保下游逻辑处理的是干净、可靠的对象。
        .map(
          (driftUser) =>
              driftUser != null ? UserMapper.fromDrift(driftUser) : null,
        )
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
            return Stream.fromFuture(_chatDao.getAllOwnedChatIds())
                .switchMap((ownedChatIds) {
                  return _chatDao.watchOrphanChats(
                    guestChatIds: user.chatIds, // 直接使用，无需 `?? []`
                    ownedChatIds: ownedChatIds,
                    parentFolderId: parentFolderId,
                  );
                })
                .map((list) => list.map(ChatMapper.fromData).toList());
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
    final newChatId = await _chatDao.importChat(
      chat,
      parentFolderId: parentFolderId,
    );
    await _bindItemToCurrentUser(newChatId);
    return newChatId;
  }

  /// 从一个现有聊天创建新聊天（作为模板），可以指定父文件夹。
  /// 从一个模板新建聊天，原模板保留，新聊天归属指定文件夹（默认与模板一致），不会影响原模板显示
  Future<int> createChatFromTemplate(
    int templateChatId, {
    int? parentFolderId,
  }) async {
    // 关键修复：直接调用 duplicateChat 来完整复制聊天及其所有消息
    // upToMessageId: null 表示复制所有消息
    // asTemplate: false 表示这是一个普通聊天，而不是新模板
    // shouldClearSummary: false 保留摘要，因为这是基于模板创建的
    return await duplicateChat(
      templateChatId,
      upToMessageId: null,
      asTemplate: false,
      shouldClearSummary: false,
      targetFolderId: parentFolderId,
    );
  }

  /// 统一的聊天衍生方法，用于分叉、克隆和模板创建。原聊天保留，新聊天/模板归属可指定文件夹，不影响原聊天显示。
  /// [sourceChatId] 原始聊天的 ID。
  /// [upToMessageId] 复制消息范围。
  /// [asTemplate] 是否另存为模板。
  /// [targetFolderId] 新聊天/模板归属文件夹，默认与原聊天一致。
  Future<int> duplicateChat(
    int sourceChatId, {
    int? upToMessageId,
    bool asTemplate = false,
    bool shouldClearSummary = true,
    int? targetFolderId,
  }) async {
    final originalChat = await getChat(sourceChatId);
    if (originalChat == null) {
      throw Exception('找不到ID为 $sourceChatId 的原始聊天');
    }

    int? finalTargetFolderId = targetFolderId;
    if (asTemplate) {
      // 如果是创建模板，则需要递归创建模板文件夹结构
      final Map<int, int> folderMap = {};
      finalTargetFolderId = await _getOrCreateTemplateFolderPath(
        originalChat.parentFolderId,
        folderMap,
      );
    } else {
      // 否则，使用指定的 targetFolderId 或原始的 parentFolderId
      finalTargetFolderId ??= originalChat.parentFolderId;
    }

    final now = DateTime.now();
    String newTitle;
    final baseTitle = originalChat.title ?? "无标题";

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

    final newChatCompanion =
        ChatMapper.toCompanion(originalChat, forInsert: true).copyWith(
          title: Value(newTitle),
          createdAt: Value(now),
          updatedAt: Value(now),
          contextSummary: shouldClearSummary
              ? const Value(null)
              : Value(originalChat.contextSummary),
          lastSummarizedMessageId: shouldClearSummary
              ? const Value(null)
              : Value(originalChat.lastSummarizedMessageId),
          orderIndex: const Value(null),
          parentFolderId: Value(finalTargetFolderId),
          backgroundImagePath: asTemplate
              ? const Value('/template/chat')
              : const Value(null),
          isFolder: const Value(false),
        );

    int newChatId;
    if (upToMessageId == 0) {
      newChatId = await _chatDao.saveChat(newChatCompanion);
    } else {
      newChatId = await _chatDao.forkOrCloneChat(
        newChatCompanion,
        sourceChatId,
        upToMessageId: upToMessageId,
      );
    }

    await _bindItemToCurrentUser(newChatId);
    return newChatId;
  }

  /// 递归地获取或创建模板文件夹路径，并返回最内层模板文件夹的ID。
  Future<int?> _getOrCreateTemplateFolderPath(
    int? originalParentId,
    Map<int, int> folderMap,
  ) async {
    if (originalParentId == null) {
      return null; // 到达根目录
    }
    if (folderMap.containsKey(originalParentId)) {
      return folderMap[originalParentId]; // 已处理过
    }

    final originalParentFolder = await getChat(originalParentId);
    if (originalParentFolder == null || !originalParentFolder.isFolder) {
      return null; // 父文件夹无效
    }

    // 递归处理上一级文件夹
    final templateGrandparentId = await _getOrCreateTemplateFolderPath(
      originalParentFolder.parentFolderId,
      folderMap,
    );

    // 查找当前文件夹对应的模板文件夹
    final existingTemplateFolder = await _chatDao.findTemplateFolder(
      originalParentFolder.title!,
      templateGrandparentId,
    );

    if (existingTemplateFolder != null) {
      folderMap[originalParentId] = existingTemplateFolder.id;
      return existingTemplateFolder.id;
    } else {
      // 创建新的模板文件夹
      final newTemplateFolderId = await addFolder(
        title: originalParentFolder.title!,
        isTemplate: true,
        parentFolderId: templateGrandparentId,
      );
      folderMap[originalParentId] = newTemplateFolderId;
      return newTemplateFolderId;
    }
  }

  /// 清理孤儿聊天（其 parentFolderId 指向一个不存在的文件夹）。
  Future<void> _cleanUpOrphanedChats() async {
    try {
      await _chatDao.cleanUpOrphanedItems();
    } catch (e) {
      // silent fail
    }
  }
}

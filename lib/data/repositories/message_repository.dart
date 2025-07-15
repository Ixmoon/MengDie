import 'package:flutter/material.dart'; // for debugPrint
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/message.dart';
import '../../ui/providers/core_providers.dart';
import '../database/daos/chat_dao.dart';
import '../database/daos/message_dao.dart';
import '../mappers/message_mapper.dart';

// 本文件包含用于管理 Message 数据集合的仓库类和提供者。

// --- Message Repository Provider ---
final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  final appDb = ref.watch(appDatabaseProvider);
  // Now depends on both messageDao and chatDao
  return MessageRepository(appDb.messageDao, appDb.chatDao);
});

// --- Message Repository Implementation ---
class MessageRepository {
  final MessageDao _messageDao;
  final ChatDao _chatDao;

  MessageRepository(this._messageDao, this._chatDao);

  // --- 数据库操作 ---
  Future<List<Message>> getMessagesForChat(int chatId) async {
    final messageDataList = await _messageDao.getMessagesForChat(chatId);
    return messageDataList.map(MessageMapper.fromData).toList();
  }

  Future<Message?> getMessageById(int messageId) async {
    final messageData = await _messageDao.getMessageById(messageId);
    return messageData != null ? MessageMapper.fromData(messageData) : null;
  }

  Future<Message?> getLastModelMessage(int chatId) async {
    final messageData = await _messageDao.getLastModelMessage(chatId);
    return messageData != null ? MessageMapper.fromData(messageData) : null;
  }

  Future<Message?> getFirstModelMessage(int chatId) async {
    final messageData = await _messageDao.findFirstModelMessage(chatId);
    return messageData != null ? MessageMapper.fromData(messageData) : null;
  }

  Future<List<Message>> getLastNMessagesForChat(int chatId, int n) async {
    if (n <= 0) return [];
    final messageDataList = await _messageDao.getLastNMessagesForChat(chatId, n);
    return messageDataList.map(MessageMapper.fromData).toList();
  }

  Future<int> saveMessage(Message message) async {
    debugPrint("MessageRepository: 保存消息 ID: ${message.id} (Chat ID: ${message.chatId}) (Drift)...");
    final companion = MessageMapper.toCompanion(message);
    final newId = await _messageDao.saveMessage(companion);
    // After saving a message, "touch" the parent chat to update its timestamp.
    await _chatDao.touchChat(message.chatId);
    return newId;
  }

  Future<void> saveMessages(List<Message> messages) async {
    if (messages.isEmpty) return;
    debugPrint("MessageRepository: 批量保存 ${messages.length} 条消息 (Chat ID: ${messages.firstOrNull?.chatId}) (Drift)...");
    final companions = messages.map(MessageMapper.toCompanion).toList();
    await _messageDao.saveMessages(companions);

    // After saving, find the unique chat IDs and "touch" them all.
    final chatIds = messages.map((m) => m.chatId).toSet();
    for (final chatId in chatIds) {
      await _chatDao.touchChat(chatId);
    }
  }

  Future<bool> deleteMessage(int messageId) async {
    debugPrint("MessageRepository: 删除消息 ID: $messageId (Drift)...");
    // First, get the message to find its chat ID.
    final message = await getMessageById(messageId);
    if (message == null) {
      return false; // Message didn't exist.
    }

    final deletedRows = await _messageDao.deleteMessage(messageId);
    if (deletedRows > 0) {
      // If deletion was successful, "touch" the parent chat.
      await _chatDao.touchChat(message.chatId);
      return true;
    }
    return false;
  }

  // --- 数据库监听流 ---
  Stream<List<Message>> watchMessagesForChat(int chatId) {
    debugPrint("MessageRepository: 监听聊天 ID: $chatId 的消息变化 (Drift)...");
    return _messageDao
        .watchMessagesForChat(chatId)
        .map((list) => list.map(MessageMapper.fromData).toList());
  }
}

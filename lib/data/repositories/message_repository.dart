import 'package:flutter/material.dart'; // for debugPrint
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/message.dart';
import '../../ui/providers/core_providers.dart';
import '../database/daos/message_dao.dart';
import '../mappers/message_mapper.dart';

// 本文件包含用于管理 Message 数据集合的仓库类和提供者。

// --- Message Repository Provider ---
final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  final appDb = ref.watch(appDatabaseProvider);
  return MessageRepository(appDb.messageDao);
});

// --- Message Repository Implementation ---
class MessageRepository {
  final MessageDao _messageDao;

  MessageRepository(this._messageDao);

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
    return await _messageDao.saveMessage(companion);
  }

  Future<void> saveMessages(List<Message> messages) async {
    debugPrint("MessageRepository: 批量保存 ${messages.length} 条消息 (Chat ID: ${messages.firstOrNull?.chatId}) (Drift)...");
    final companions = messages.map(MessageMapper.toCompanion).toList();
    await _messageDao.saveMessages(companions);
  }

  Future<bool> deleteMessage(int messageId) async {
    debugPrint("MessageRepository: 删除消息 ID: $messageId (Drift)...");
    return await _messageDao.deleteMessage(messageId);
  }

  // --- 数据库监听流 ---
  Stream<List<Message>> watchMessagesForChat(int chatId) {
    debugPrint("MessageRepository: 监听聊天 ID: $chatId 的消息变化 (Drift)...");
    return _messageDao
        .watchMessagesForChat(chatId)
        .map((list) => list.map(MessageMapper.fromData).toList());
  }
}

import 'package:flutter/material.dart'; // for debugPrint
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value; // For Value() and absent
// import 'package:isar/isar.dart'; // Removed Isar

// 导入模型和核心 Provider
import '../models/models.dart'; // Still used for Message model class (temporarily)
import '../providers/core_providers.dart'; // Needs appDatabaseProvider
import '../data/database/drift/app_database.dart'; 
import '../data/database/drift/daos/message_dao.dart'; // Import MessageDao for type annotation
// import '../data/database/drift/common_enums.dart' as drift_enums; // Already imported by models.dart if Message uses drift_enums

// 本文件包含用于管理 Message 数据集合的仓库类和提供者。

// --- Message Repository Provider ---
final messageRepositoryProvider = Provider<MessageRepository>((ref) {
   final appDb = ref.watch(appDatabaseProvider);
   return MessageRepository(appDb);
});

// --- Message Repository Implementation ---
class MessageRepository {
  final AppDatabase _db;
  late final MessageDao _messageDao;

  MessageRepository(this._db) {
    _messageDao = _db.messageDao;
  }

  // Helper to convert Drift MessageData to original Message model
  Message _fromMessageData(MessageData data) {
    // Assumes Message model in collection_models.dart now uses Drift-compatible types for enums
    return Message(
      id: data.id,
      chatId: data.chatId,
      rawText: data.rawText,
      role: data.role, // This is drift_enums.MessageRole
      timestamp: data.timestamp,
    );
  }

  // Helper to convert original Message model to Drift MessagesCompanion
  MessagesCompanion _toMessagesCompanion(Message message) {
    return MessagesCompanion(
      id: message.id == 0 ? const Value.absent() : Value(message.id),
      chatId: Value(message.chatId),
      rawText: Value(message.rawText),
      role: Value(message.role), // Assumes message.role is drift_enums.MessageRole
      timestamp: Value(message.timestamp),
    );
  }

  // --- 数据库操作 ---
  Future<List<Message>> getMessagesForChat(int chatId) async {
     debugPrint("MessageRepository: 获取聊天 ID: $chatId 的所有消息 (Drift)...");
     final messageDataList = await _messageDao.getMessagesForChat(chatId);
     return messageDataList.map(_fromMessageData).toList();
  }

  Future<List<Message>> getLastNMessagesForChat(int chatId, int n) async {
     if (n <= 0) return [];
     debugPrint("MessageRepository: 获取聊天 ID: $chatId 的最后 $n 条消息 (Drift)...");
     final messageDataList = await _messageDao.getLastNMessagesForChat(chatId, n);
     return messageDataList.map(_fromMessageData).toList();
  }

  Future<int> saveMessage(Message message) async {
     debugPrint("MessageRepository: 保存消息 ID: ${message.id} (Chat ID: ${message.chatId}) (Drift)...");
     final companion = _toMessagesCompanion(message);
     return await _messageDao.saveMessage(companion);
  }

  Future<void> saveMessages(List<Message> messages) async {
     debugPrint("MessageRepository: 批量保存 ${messages.length} 条消息 (Chat ID: ${messages.firstOrNull?.chatId}) (Drift)...");
     final companions = messages.map(_toMessagesCompanion).toList();
     await _messageDao.saveMessages(companions);
  }

  Future<bool> deleteMessage(int messageId) async {
     debugPrint("MessageRepository: 删除消息 ID: $messageId (Drift)...");
     return await _messageDao.deleteMessage(messageId);
  }

  // --- 数据库监听流 ---
  Stream<List<Message>> watchMessagesForChat(int chatId) {
     debugPrint("MessageRepository: 监听聊天 ID: $chatId 的消息变化 (Drift)...");
     return _messageDao.watchMessagesForChat(chatId).map((list) => list.map(_fromMessageData).toList());
  }
}

// lastModelMessageProvider 已移至 chat_state_providers.dart

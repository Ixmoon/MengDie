import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:postgres/postgres.dart';

import '../../models/export_import_dtos.dart';
import '../app_database.dart';
import '../common_enums.dart' as drift_enums;
import '../models/drift_context_config.dart';
import '../models/drift_xml_rule.dart';
import '../sync/sync_service.dart';
import '../tables/chats.dart';
import '../tables/messages.dart';


part 'chat_dao.g.dart'; // Drift will generate this file

@DriftAccessor(tables: [Chats, Messages])
class ChatDao extends DatabaseAccessor<AppDatabase> with _$ChatDaoMixin {
  final AppDatabase db;

  ChatDao(this.db) : super(db);

  // --- Database Operations ---

  Future<List<ChatData>> getAllChats() {
    return (select(chats)..orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)])).get();
  }

  Future<ChatData?> getChat(int chatId, {bool forceRemoteRead = false}) async {
    // Attempt to read from remote first, based on the "OR" logic handled by SyncService.
    final remoteChat = await SyncService.instance.remoteRead<ChatData?>(
      force: forceRemoteRead,
      remoteReadAction: (remote) async {
        final result = await remote.execute(
          'SELECT * FROM chats WHERE id = @id',
          parameters: {'id': chatId},
        );
        if (result.isEmpty) return null;
        final row = result.first.toColumnMap();
        return _mapRemoteRowToChatData(row);
      },
    );

    // If we got data from the remote, update the local database.
    if (remoteChat != null) {
      await into(chats).insertOnConflictUpdate(remoteChat.toCompanion(true));
    }

    // Always return data from the local database, which is now up-to-date if remote read succeeded.
    return (select(chats)..where((t) => t.id.equals(chatId))).getSingleOrNull();
  }

  Future<int> saveChat(ChatsCompanion chat, {bool forceRemoteWrite = false}) async {
    final chatId = await into(chats).insert(chat, mode: InsertMode.insertOrReplace);
    
    SyncService.instance.backgroundWrite(
      force: forceRemoteWrite,
      remoteTransaction: (remote) async {
        final params = _chatToRemoteParams(chat.copyWith(id: Value(chatId)));
        await remote.execute(
          'INSERT INTO chats (id, title, system_prompt, created_at, updated_at, cover_image_base64, background_image_path, order_index, is_folder, parent_folder_id, context_config, xml_rules, api_config_id, enable_preprocessing, preprocessing_prompt, context_summary, preprocessing_api_config_id, enable_secondary_xml, secondary_xml_prompt, secondary_xml_api_config_id, continue_prompt) '
          'VALUES (@id, @title, @system_prompt, @created_at, @updated_at, @cover_image_base64, @background_image_path, @order_index, @is_folder, @parent_folder_id, @context_config, @xml_rules, @api_config_id, @enable_preprocessing, @preprocessing_prompt, @context_summary, @preprocessing_api_config_id, @enable_secondary_xml, @secondary_xml_prompt, @secondary_xml_api_config_id, @continue_prompt) '
          'ON CONFLICT (id) DO UPDATE SET '
          'title = @title, system_prompt = @system_prompt, updated_at = @updated_at, cover_image_base64 = @cover_image_base64, background_image_path = @background_image_path, order_index = @order_index, is_folder = @is_folder, parent_folder_id = @parent_folder_id, context_config = @context_config, xml_rules = @xml_rules, api_config_id = @api_config_id, enable_preprocessing = @enable_preprocessing, preprocessing_prompt = @preprocessing_prompt, context_summary = @context_summary, preprocessing_api_config_id = @preprocessing_api_config_id, enable_secondary_xml = @enable_secondary_xml, secondary_xml_prompt = @secondary_xml_prompt, secondary_xml_api_config_id = @secondary_xml_api_config_id, continue_prompt = @continue_prompt',
          parameters: params,
        );
      },
      rollbackAction: () async {
        await (delete(chats)..where((t) => t.id.equals(chatId))).go();
      },
    );
    return chatId;
  }

  Future<void> updateChat(ChatsCompanion chat, {bool forceRemoteWrite = false}) async {
    final oldChatData = await getChat(chat.id.value);
    await (update(chats)..where((t) => t.id.equals(chat.id.value))).write(chat);

    SyncService.instance.backgroundWrite(
      force: forceRemoteWrite,
      remoteTransaction: (remote) async {
        final params = _chatToRemoteParams(chat);
        await remote.execute(
          'UPDATE chats SET '
          'title = @title, system_prompt = @system_prompt, updated_at = @updated_at, cover_image_base64 = @cover_image_base64, background_image_path = @background_image_path, order_index = @order_index, is_folder = @is_folder, parent_folder_id = @parent_folder_id, context_config = @context_config, xml_rules = @xml_rules, api_config_id = @api_config_id, enable_preprocessing = @enable_preprocessing, preprocessing_prompt = @preprocessing_prompt, context_summary = @context_summary, preprocessing_api_config_id = @preprocessing_api_config_id, enable_secondary_xml = @enable_secondary_xml, secondary_xml_prompt = @secondary_xml_prompt, secondary_xml_api_config_id = @secondary_xml_api_config_id, continue_prompt = @continue_prompt '
          'WHERE id = @id',
          parameters: params,
        );
      },
      rollbackAction: () async {
        if (oldChatData != null) {
          await into(chats).insertOnConflictUpdate(oldChatData.toCompanion(true));
        }
      },
    );
  }

  Future<bool> deleteChatAndMessages(int chatId, {bool forceRemoteWrite = false}) async {
    final chatToDelete = await getChat(chatId);
    if (chatToDelete == null) return false;
    final messagesToDelete = await (select(messages)..where((t) => t.chatId.equals(chatId))).get();

    final count = await db.transaction(() async {
      await (delete(messages)..where((t) => t.chatId.equals(chatId))).go();
      return await (delete(chats)..where((t) => t.id.equals(chatId))).go();
    });

    if (count > 0) {
      SyncService.instance.backgroundWrite(
        force: forceRemoteWrite,
        remoteTransaction: (remote) async {
          await remote.execute('DELETE FROM messages WHERE chat_id = @id', parameters: {'id': chatId});
          await remote.execute('DELETE FROM chats WHERE id = @id', parameters: {'id': chatId});
        },
        rollbackAction: () async {
          await db.transaction(() async {
            await into(chats).insertOnConflictUpdate(chatToDelete.toCompanion(true));
            await batch((b) => b.insertAll(messages, messagesToDelete));
          });
        },
      );
    }
    return count > 0;
  }

  Future<int> deleteMultipleChatsAndMessages(List<int> chatIds, {bool forceRemoteWrite = false}) async {
    if (chatIds.isEmpty) return 0;

    final chatsToDelete = await (select(chats)..where((t) => t.id.isIn(chatIds))).get();
    final messagesToDelete = await (select(messages)..where((t) => t.chatId.isIn(chatIds))).get();

    if (chatsToDelete.isEmpty) return 0;

    final count = await db.transaction(() async {
      await (delete(messages)..where((t) => t.chatId.isIn(chatIds))).go();
      return await (delete(chats)..where((t) => t.id.isIn(chatIds))).go();
    });

    if (count > 0) {
      SyncService.instance.backgroundWrite(
        force: forceRemoteWrite,
        remoteTransaction: (remote) async {
          await remote.execute('DELETE FROM messages WHERE chat_id = ANY(@ids)', parameters: {'ids': chatIds});
          await remote.execute('DELETE FROM chats WHERE id = ANY(@ids)', parameters: {'ids': chatIds});
        },
        rollbackAction: () async {
          await db.transaction(() async {
            await batch((b) => b.insertAll(chats, chatsToDelete));
            await batch((b) => b.insertAll(messages, messagesToDelete));
          });
        },
      );
    }
    return count;
  }

  Future<void> updateChatOrder(List<ChatsCompanion> chatsToUpdate, {bool forceRemoteWrite = false}) async {
    if (chatsToUpdate.isEmpty) return;
    
    final oldChats = await (select(chats)..where((t) => t.id.isIn(chatsToUpdate.map((c) => c.id.value)))).get();

    await db.transaction(() async {
      for (final chatCompanion in chatsToUpdate) {
        await (update(chats)..where((t) => t.id.equals(chatCompanion.id.value))).write(chatCompanion);
      }
    });

    SyncService.instance.backgroundWrite(
      force: forceRemoteWrite,
      remoteTransaction: (remote) async {
        for (final chatCompanion in chatsToUpdate) {
          await remote.execute(
            'UPDATE chats SET order_index = @order_index, updated_at = @updated_at WHERE id = @id',
            parameters: {
              'id': chatCompanion.id.value,
              'order_index': chatCompanion.orderIndex.value,
              'updated_at': chatCompanion.updatedAt.value,
            },
          );
        }
      },
      rollbackAction: () async {
        await db.transaction(() async {
          for (final oldChat in oldChats) {
            await into(chats).insertOnConflictUpdate(oldChat.toCompanion(true));
          }
        });
      },
    );
  }

  Future<void> moveChatsToNewParent(List<int> chatIds, int? newParentFolderId, {bool forceRemoteWrite = false}) async {
    if (chatIds.isEmpty) return;

    final oldChats = await (select(chats)..where((t) => t.id.isIn(chatIds))).get();

    await (update(chats)..where((t) => t.id.isIn(chatIds))).write(
      ChatsCompanion(
        parentFolderId: Value(newParentFolderId),
        orderIndex: const Value(null),
      ),
    );

    SyncService.instance.backgroundWrite(
      force: forceRemoteWrite,
      remoteTransaction: (remote) async {
        await remote.execute(
          'UPDATE chats SET parent_folder_id = @parent_folder_id, order_index = NULL WHERE id = ANY(@ids)',
          parameters: {'parent_folder_id': newParentFolderId, 'ids': chatIds},
        );
      },
      rollbackAction: () async {
        await db.transaction(() async {
          for (final oldChat in oldChats) {
            await into(chats).insertOnConflictUpdate(oldChat.toCompanion(true));
          }
        });
      },
    );
  }

  // Helper to convert chat companion to remote parameters
  Map<String, dynamic> _chatToRemoteParams(ChatsCompanion chat) {
    return {
      'id': chat.id.value,
      'title': chat.title.value,
      'system_prompt': chat.systemPrompt.value,
      'created_at': chat.createdAt.value,
      'updated_at': chat.updatedAt.value,
      'cover_image_base64': chat.coverImageBase64.value,
      'background_image_path': chat.backgroundImagePath.value,
      'order_index': chat.orderIndex.value,
      'is_folder': chat.isFolder.value,
      'parent_folder_id': chat.parentFolderId.value,
      'context_config': jsonEncode(chat.contextConfig.value.toJson()),
      'xml_rules': jsonEncode(chat.xmlRules.value.map((e) => e.toJson()).toList()),
      'api_config_id': chat.apiConfigId.value,
      'enable_preprocessing': chat.enablePreprocessing.value,
      'preprocessing_prompt': chat.preprocessingPrompt.value,
      'context_summary': chat.contextSummary.value,
      'preprocessing_api_config_id': chat.preprocessingApiConfigId.value,
      'enable_secondary_xml': chat.enableSecondaryXml.value,
      'secondary_xml_prompt': chat.secondaryXmlPrompt.value,
      'secondary_xml_api_config_id': chat.secondaryXmlApiConfigId.value,
      'continue_prompt': chat.continuePrompt.value,
    };
  }

  /// Helper to map a raw SQL row to a Drift ChatData object.
  ChatData _mapRemoteRowToChatData(Map<String, dynamic> row) {
    return ChatData(
      id: row['id'],
      title: row['title'],
      systemPrompt: row['system_prompt'],
      createdAt: row['created_at'],
      updatedAt: row['updated_at'],
      coverImageBase64: row['cover_image_base64'],
      backgroundImagePath: row['background_image_path'],
      orderIndex: row['order_index'],
      isFolder: row['is_folder'],
      parentFolderId: row['parent_folder_id'],
      contextConfig: DriftContextConfig.fromJson(jsonDecode(row['context_config'])),
      xmlRules: (jsonDecode(row['xml_rules']) as List)
          .map((e) => DriftXmlRule.fromJson(e))
          .toList(),
      apiConfigId: row['api_config_id'],
      enablePreprocessing: row['enable_preprocessing'],
      preprocessingPrompt: row['preprocessing_prompt'],
      contextSummary: row['context_summary'],
      preprocessingApiConfigId: row['preprocessing_api_config_id'],
      enableSecondaryXml: row['enable_secondary_xml'],
      secondaryXmlPrompt: row['secondary_xml_prompt'],
      secondaryXmlApiConfigId: row['secondary_xml_api_config_id'],
      continuePrompt: row['continue_prompt'],
    );
  }

  // --- Database Listening Streams ---

  Stream<List<ChatData>> watchChatsInFolder(int? parentFolderId) {
    final query = select(chats)
      ..where((t) => parentFolderId == null ? t.parentFolderId.isNull() : t.parentFolderId.equals(parentFolderId))
      ..orderBy([
       // 最终修正：手动排序的项目（orderIndex 非 null）在后，自动排序的项目（orderIndex 为 null）在前
       (t) => OrderingTerm(expression: t.orderIndex, mode: OrderingMode.asc, nulls: NullsOrder.first),
       // 自动排序的项目内部，按创建时间倒序，实现“新建的在最前”
       (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
      ]);
    return query.watch();
  }

  Stream<ChatData?> watchChat(int chatId) {
    return (select(chats)..where((t) => t.id.equals(chatId))).watchSingleOrNull();
  }

  /// 监听特定用户的聊天列表。
  Stream<List<ChatData>> watchChatsForUser(List<int> chatIds, int? parentFolderId) {
    final query = select(chats)
      ..where((t) => t.id.isIn(chatIds) & (parentFolderId == null ? t.parentFolderId.isNull() : t.parentFolderId.equals(parentFolderId)))
      ..orderBy([
        (t) => OrderingTerm(expression: t.orderIndex, mode: OrderingMode.asc, nulls: NullsOrder.first),
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
      ]);
    return query.watch();
  }

  /// 监听游客和孤儿聊天。
  Stream<List<ChatData>> watchOrphanChats({
    required List<int> guestChatIds,
    required List<int> ownedChatIds,
    int? parentFolderId,
  }) {
    final query = select(chats)
      ..where((t) {
        // 条件：
        // 1. 聊天ID不在任何已注册用户的列表中 (孤儿聊天)
        //    或者
        // 2. 聊天ID在游客自己的列表中
        final isOrphan = t.id.isNotIn(ownedChatIds);
        final isGuestsOwn = t.id.isIn(guestChatIds);
        // 文件夹过滤条件
        final folderCondition = parentFolderId == null
            ? t.parentFolderId.isNull()
            : t.parentFolderId.equals(parentFolderId);

        return (isOrphan | isGuestsOwn) & folderCondition;
      })
      ..orderBy([
        (t) => OrderingTerm(expression: t.orderIndex, mode: OrderingMode.asc, nulls: NullsOrder.first),
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
      ]);
    return query.watch();
  }

  /// 获取所有**非游客**用户的聊天ID列表。
  /// 这是为了识别哪些聊天是“孤儿”聊天（不属于任何注册用户）。
  Future<List<int>> getAllOwnedChatIds() async {
    // 通过添加 where 条件排除了 id 为 0 的游客用户
    final allUsers = await (db.userDao.db.select(db.userDao.db.users)..where((u) => u.id.isNotValue(0))).get();
    final allOwnedIds = <int>{};
    for (final user in allUsers) {
      // Safely add chat IDs, ensuring the list is not null.
      final chatIds = user.chatIds;
      if (chatIds != null) {
        allOwnedIds.addAll(chatIds);
      }
    }
    return allOwnedIds.toList();
  }

  Future<List<ChatData>> getChatsInFolder(int? parentFolderId) {
    final query = select(chats)
      ..where((t) => parentFolderId == null ? t.parentFolderId.isNull() : t.parentFolderId.equals(parentFolderId))
      ..orderBy([
       // 最终修正：手动排序的项目（orderIndex 非 null）在后，自动排序的项目（orderIndex 为 null）在前
       (t) => OrderingTerm(expression: t.orderIndex, mode: OrderingMode.asc, nulls: NullsOrder.first),
       // 自动排序的项目内部，按创建时间倒序，实现“新建的在最前”
       (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
      ]);
    return query.get();
  }

  // --- Import Chat ---
  Future<int> importChatFromDto(ChatExportDto chatDto, AppDatabase attachedDb, {int? parentFolderId}) async {
    final contextConfigDrift = DriftContextConfig(
        mode: drift_enums.ContextManagementMode.values.firstWhere(
                  (e) => e.name == chatDto.contextConfig.mode.name,
                  orElse:()=> drift_enums.ContextManagementMode.turns),
        maxTurns: chatDto.contextConfig.maxTurns,
        maxContextTokens: chatDto.contextConfig.maxContextTokens,
      );

    final xmlRulesDrift = chatDto.xmlRules.map((dto) =>
        DriftXmlRule(
          tagName: dto.tagName,
          action: drift_enums.XmlAction.values.firstWhere(
                      (e) => e.name == dto.action.name,
                      orElse: ()=> drift_enums.XmlAction.ignore)
        )
      ).toList();
    
    final now = DateTime.now();

    final chatCompanion = ChatsCompanion.insert(
      title: Value(chatDto.title),
      systemPrompt: Value(chatDto.systemPrompt),
      isFolder: Value(chatDto.isFolder),
      contextConfig: contextConfigDrift,
      xmlRules: xmlRulesDrift,
      // 优先使用 DTO 中的时间戳，否则使用当前时间作为备用
      createdAt: chatDto.createdAt ?? now,
      updatedAt: chatDto.updatedAt ?? now,
      apiConfigId: Value(chatDto.apiConfigId),
      parentFolderId: Value(parentFolderId),
      orderIndex: Value(chatDto.orderIndex),
      coverImageBase64: Value(chatDto.coverImageBase64),
      backgroundImagePath: const Value(null),
      // new fields
      enablePreprocessing: Value(chatDto.enablePreprocessing),
      preprocessingPrompt: Value(chatDto.preprocessingPrompt),
      preprocessingApiConfigId: Value(chatDto.preprocessingApiConfigId),
      enableSecondaryXml: Value(chatDto.enableSecondaryXml),
      secondaryXmlPrompt: Value(chatDto.secondaryXmlPrompt),
      secondaryXmlApiConfigId: Value(chatDto.secondaryXmlApiConfigId),
      contextSummary: Value(chatDto.contextSummary),
      continuePrompt: Value(chatDto.continuePrompt),
    );

    return attachedDb.transaction(() async {
      final newChatId = await attachedDb.into(attachedDb.chats).insert(chatCompanion);

      final List<MessagesCompanion> messageCompanions = [];
      for (final messageDto in chatDto.messages) {
        String partsJson;
        // Prioritize the new 'parts' field if it exists and is not empty
        if (messageDto.parts != null && messageDto.parts!.isNotEmpty) {
          partsJson = jsonEncode(messageDto.parts);
        } else {
          // Fallback to legacy 'rawText'
          final parts = [{'type': 'text', 'text': messageDto.rawText}];
          partsJson = jsonEncode(parts);
        }

        messageCompanions.add(
          MessagesCompanion.insert(
            chatId: newChatId,
            partsJson: partsJson,
            role: messageDto.role, // DTO now uses the same enum
            timestamp: DateTime.now(), // MessageExportDto does not have timestamp, generate new
          )
        );
      }

      if (messageCompanions.isNotEmpty) {
        await attachedDb.batch((batch) {
          batch.insertAll(attachedDb.messages, messageCompanions);
        });
      }
      return newChatId;
    });
    // return Future.value(0); // Remove dummy return
  }

  /// 通用方法，用于分叉或克隆聊天。
  ///
  /// [newChatCompanion] 是预设好的新聊天对象。
  /// [originalChatId] 是原始聊天的ID。
  /// [upToMessageId] (可选) 如果提供，则只复制到此消息ID为止（分叉行为）。
  /// 如果为 null，则复制所有消息（克隆行为）。
  Future<int> forkOrCloneChat(
    ChatsCompanion newChatCompanion,
    int originalChatId, {
    int? upToMessageId,
  }) async {
    return db.transaction(() async {
      // 1. 插入由 Repository 层准备好的新聊天记录
      final newChatId = await into(chats).insert(newChatCompanion);

      // 2. 构建消息查询
      final query = select(messages)
        ..where((t) => t.chatId.equals(originalChatId))
        ..orderBy([(t) => OrderingTerm(expression: t.timestamp)]);

      // 如果是分叉，则添加消息ID限制
      if (upToMessageId != null) {
        query.where((t) => t.id.isSmallerOrEqualValue(upToMessageId));
      }

      final messagesToCopy = await query.get();

      // 3. 为新聊天创建新的消息副本
      final List<MessagesCompanion> newMessages = [];
      for (final msg in messagesToCopy) {
        newMessages.add(msg.toCompanion(true).copyWith(
          id: const Value.absent(), // 新的自增ID
          chatId: Value(newChatId), // 关联到新的聊天ID
        ));
      }

      // 4. 批量插入复制的消息
      if (newMessages.isNotEmpty) {
        await batch((batch) {
          batch.insertAll(messages, newMessages);
        });
      }

      return newChatId;
    });
  }
}

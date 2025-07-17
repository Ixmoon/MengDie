import 'package:drift/drift.dart';

import '../../domain/models/chat.dart' as domain;
import '../../domain/enums.dart' as domain_enums;

import '../database/app_database.dart' as drift;


class ChatMapper {
  static domain.Chat fromData(drift.ChatData data) {
    return domain.Chat(
      id: data.id,
      title: data.title,
      systemPrompt: data.systemPrompt,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
      coverImageBase64: data.coverImageBase64,
      backgroundImagePath: data.backgroundImagePath,
      orderIndex: data.orderIndex,
      isFolder: data.isFolder ?? false,
      parentFolderId: data.parentFolderId,
      apiConfigId: data.apiConfigId,
      contextConfig: data.contextConfig, // Direct assignment
      xmlRules: data.xmlRules, // Direct assignment
      enablePreprocessing: data.enablePreprocessing ?? false,
      preprocessingPrompt: data.preprocessingPrompt,
      contextSummary: data.contextSummary,
      preprocessingApiConfigId: data.preprocessingApiConfigId,
      enableSecondaryXml: data.enableSecondaryXml ?? false,
      secondaryXmlPrompt: data.secondaryXmlPrompt,
      secondaryXmlApiConfigId: data.secondaryXmlApiConfigId,
      continuePrompt: data.continuePrompt,
      // 映射 "帮我回复" 功能字段
      enableHelpMeReply: data.enableHelpMeReply ?? false,
      helpMeReplyPrompt: data.helpMeReplyPrompt,
      helpMeReplyApiConfigId: data.helpMeReplyApiConfigId,
      helpMeReplyTriggerMode: data.helpMeReplyTriggerMode ?? domain_enums.HelpMeReplyTriggerMode.manual,
    );
  }

  static drift.ChatsCompanion toCompanion(domain.Chat chat, {bool forInsert = false}) {
    // The `updatedAt` field is now managed by the DAO layer.
    return drift.ChatsCompanion(
      id: forInsert ? const Value.absent() : Value(chat.id),
      title: Value(chat.title),
      systemPrompt: Value(chat.systemPrompt),
      createdAt: Value(chat.createdAt),
      // Do not set `updatedAt` here. The DAO will handle it.
      coverImageBase64: Value(chat.coverImageBase64),
      backgroundImagePath: Value(chat.backgroundImagePath),
      orderIndex: Value(chat.orderIndex),
      isFolder: Value(chat.isFolder),
      parentFolderId: Value(chat.parentFolderId),
      apiConfigId: Value(chat.apiConfigId),
      contextConfig: Value(chat.contextConfig), // Direct assignment
      xmlRules: Value(chat.xmlRules), // Direct assignment
      enablePreprocessing: Value(chat.enablePreprocessing),
      preprocessingPrompt: Value(chat.preprocessingPrompt),
      contextSummary: Value(chat.contextSummary),
      preprocessingApiConfigId: Value(chat.preprocessingApiConfigId),
      enableSecondaryXml: Value(chat.enableSecondaryXml),
      secondaryXmlPrompt: Value(chat.secondaryXmlPrompt),
      secondaryXmlApiConfigId: Value(chat.secondaryXmlApiConfigId),
      continuePrompt: Value(chat.continuePrompt),
      // 映射 "帮我回复" 功能字段
      enableHelpMeReply: Value(chat.enableHelpMeReply),
      helpMeReplyPrompt: Value(chat.helpMeReplyPrompt),
      helpMeReplyApiConfigId: Value(chat.helpMeReplyApiConfigId),
      helpMeReplyTriggerMode: Value(chat.helpMeReplyTriggerMode),
    );
  }
}
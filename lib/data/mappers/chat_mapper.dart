import 'package:drift/drift.dart';

import '../models/chat.dart' as domain;
import '../models/enums.dart' as domain_enums;
import '../models/context_config.dart' as domain_context;
import '../models/xml_rule.dart' as domain_xml;

import '../database/app_database.dart' as drift;
import '../database/common_enums.dart' as drift;
import '../database/models/drift_context_config.dart' as drift_context;
import '../database/models/drift_xml_rule.dart' as drift_xml;

class ContextConfigMapper {
  static domain_context.ContextConfig fromDrift(drift_context.DriftContextConfig driftConfig) {
    return domain_context.ContextConfig(
      mode: driftConfig.mode,
      maxTurns: driftConfig.maxTurns,
      maxContextTokens: driftConfig.maxContextTokens,
    );
  }

  static drift_context.DriftContextConfig toDrift(domain_context.ContextConfig domainConfig) {
    return drift_context.DriftContextConfig(
      mode: domainConfig.mode,
      maxTurns: domainConfig.maxTurns,
      maxContextTokens: domainConfig.maxContextTokens,
    );
  }
}

class XmlRuleMapper {
  static domain_xml.XmlRule fromDrift(drift_xml.DriftXmlRule driftRule) {
    return domain_xml.XmlRule(
      tagName: driftRule.tagName,
      action: driftRule.action,
    );
  }

  static drift_xml.DriftXmlRule toDrift(domain_xml.XmlRule domainRule) {
    return drift_xml.DriftXmlRule(
      tagName: domainRule.tagName,
      action: domainRule.action,
    );
  }
}

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
      contextConfig: ContextConfigMapper.fromDrift(data.contextConfig),
      xmlRules: data.xmlRules.map(XmlRuleMapper.fromDrift).toList(),
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
    return drift.ChatsCompanion(
      id: forInsert ? const Value.absent() : Value(chat.id),
      title: Value(chat.title),
      systemPrompt: Value(chat.systemPrompt),
      createdAt: Value(chat.createdAt),
      updatedAt: Value(chat.updatedAt),
      coverImageBase64: Value(chat.coverImageBase64),
      backgroundImagePath: Value(chat.backgroundImagePath),
      orderIndex: Value(chat.orderIndex),
      isFolder: Value(chat.isFolder),
      parentFolderId: Value(chat.parentFolderId),
      apiConfigId: Value(chat.apiConfigId),
      contextConfig: Value(ContextConfigMapper.toDrift(chat.contextConfig)),
      xmlRules: Value(chat.xmlRules.map(XmlRuleMapper.toDrift).toList()),
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
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ChatsTable extends Chats with TableInfo<$ChatsTable, ChatData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _systemPromptMeta =
      const VerificationMeta('systemPrompt');
  @override
  late final GeneratedColumn<String> systemPrompt = GeneratedColumn<String>(
      'system_prompt', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      clientDefault: () => DateTime.now());
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _coverImageBase64Meta =
      const VerificationMeta('coverImageBase64');
  @override
  late final GeneratedColumn<String> coverImageBase64 = GeneratedColumn<String>(
      'cover_image_base64', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _backgroundImagePathMeta =
      const VerificationMeta('backgroundImagePath');
  @override
  late final GeneratedColumn<String> backgroundImagePath =
      GeneratedColumn<String>('background_image_path', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _orderIndexMeta =
      const VerificationMeta('orderIndex');
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
      'order_index', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _isFolderMeta =
      const VerificationMeta('isFolder');
  @override
  late final GeneratedColumn<bool> isFolder = GeneratedColumn<bool>(
      'is_folder', aliasedName, true,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_folder" IN (0, 1))'));
  static const VerificationMeta _parentFolderIdMeta =
      const VerificationMeta('parentFolderId');
  @override
  late final GeneratedColumn<int> parentFolderId = GeneratedColumn<int>(
      'parent_folder_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  late final GeneratedColumnWithTypeConverter<DriftContextConfig, String>
      contextConfig = GeneratedColumn<String>(
              'context_config', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<DriftContextConfig>(
              $ChatsTable.$convertercontextConfig);
  @override
  late final GeneratedColumnWithTypeConverter<List<DriftXmlRule>, String>
      xmlRules = GeneratedColumn<String>('xml_rules', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<List<DriftXmlRule>>($ChatsTable.$converterxmlRules);
  static const VerificationMeta _apiConfigIdMeta =
      const VerificationMeta('apiConfigId');
  @override
  late final GeneratedColumn<String> apiConfigId = GeneratedColumn<String>(
      'api_config_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _enablePreprocessingMeta =
      const VerificationMeta('enablePreprocessing');
  @override
  late final GeneratedColumn<bool> enablePreprocessing = GeneratedColumn<bool>(
      'enable_preprocessing', aliasedName, true,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("enable_preprocessing" IN (0, 1))'));
  static const VerificationMeta _preprocessingPromptMeta =
      const VerificationMeta('preprocessingPrompt');
  @override
  late final GeneratedColumn<String> preprocessingPrompt =
      GeneratedColumn<String>('preprocessing_prompt', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _contextSummaryMeta =
      const VerificationMeta('contextSummary');
  @override
  late final GeneratedColumn<String> contextSummary = GeneratedColumn<String>(
      'context_summary', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _preprocessingApiConfigIdMeta =
      const VerificationMeta('preprocessingApiConfigId');
  @override
  late final GeneratedColumn<String> preprocessingApiConfigId =
      GeneratedColumn<String>('preprocessing_api_config_id', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _enableSecondaryXmlMeta =
      const VerificationMeta('enableSecondaryXml');
  @override
  late final GeneratedColumn<bool> enableSecondaryXml = GeneratedColumn<bool>(
      'enable_secondary_xml', aliasedName, true,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("enable_secondary_xml" IN (0, 1))'));
  static const VerificationMeta _secondaryXmlPromptMeta =
      const VerificationMeta('secondaryXmlPrompt');
  @override
  late final GeneratedColumn<String> secondaryXmlPrompt =
      GeneratedColumn<String>('secondary_xml_prompt', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _secondaryXmlApiConfigIdMeta =
      const VerificationMeta('secondaryXmlApiConfigId');
  @override
  late final GeneratedColumn<String> secondaryXmlApiConfigId =
      GeneratedColumn<String>('secondary_xml_api_config_id', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _continuePromptMeta =
      const VerificationMeta('continuePrompt');
  @override
  late final GeneratedColumn<String> continuePrompt = GeneratedColumn<String>(
      'continue_prompt', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _enableHelpMeReplyMeta =
      const VerificationMeta('enableHelpMeReply');
  @override
  late final GeneratedColumn<bool> enableHelpMeReply = GeneratedColumn<bool>(
      'enable_help_me_reply', aliasedName, true,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("enable_help_me_reply" IN (0, 1))'));
  static const VerificationMeta _helpMeReplyPromptMeta =
      const VerificationMeta('helpMeReplyPrompt');
  @override
  late final GeneratedColumn<String> helpMeReplyPrompt =
      GeneratedColumn<String>('help_me_reply_prompt', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _helpMeReplyApiConfigIdMeta =
      const VerificationMeta('helpMeReplyApiConfigId');
  @override
  late final GeneratedColumn<String> helpMeReplyApiConfigId =
      GeneratedColumn<String>('help_me_reply_api_config_id', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  late final GeneratedColumnWithTypeConverter<HelpMeReplyTriggerMode?, String>
      helpMeReplyTriggerMode = GeneratedColumn<String>(
              'help_me_reply_trigger_mode', aliasedName, true,
              type: DriftSqlType.string, requiredDuringInsert: false)
          .withConverter<HelpMeReplyTriggerMode?>(
              $ChatsTable.$converterhelpMeReplyTriggerMode);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        title,
        systemPrompt,
        createdAt,
        updatedAt,
        coverImageBase64,
        backgroundImagePath,
        orderIndex,
        isFolder,
        parentFolderId,
        contextConfig,
        xmlRules,
        apiConfigId,
        enablePreprocessing,
        preprocessingPrompt,
        contextSummary,
        preprocessingApiConfigId,
        enableSecondaryXml,
        secondaryXmlPrompt,
        secondaryXmlApiConfigId,
        continuePrompt,
        enableHelpMeReply,
        helpMeReplyPrompt,
        helpMeReplyApiConfigId,
        helpMeReplyTriggerMode
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chats';
  @override
  VerificationContext validateIntegrity(Insertable<ChatData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    }
    if (data.containsKey('system_prompt')) {
      context.handle(
          _systemPromptMeta,
          systemPrompt.isAcceptableOrUnknown(
              data['system_prompt']!, _systemPromptMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('cover_image_base64')) {
      context.handle(
          _coverImageBase64Meta,
          coverImageBase64.isAcceptableOrUnknown(
              data['cover_image_base64']!, _coverImageBase64Meta));
    }
    if (data.containsKey('background_image_path')) {
      context.handle(
          _backgroundImagePathMeta,
          backgroundImagePath.isAcceptableOrUnknown(
              data['background_image_path']!, _backgroundImagePathMeta));
    }
    if (data.containsKey('order_index')) {
      context.handle(
          _orderIndexMeta,
          orderIndex.isAcceptableOrUnknown(
              data['order_index']!, _orderIndexMeta));
    }
    if (data.containsKey('is_folder')) {
      context.handle(_isFolderMeta,
          isFolder.isAcceptableOrUnknown(data['is_folder']!, _isFolderMeta));
    }
    if (data.containsKey('parent_folder_id')) {
      context.handle(
          _parentFolderIdMeta,
          parentFolderId.isAcceptableOrUnknown(
              data['parent_folder_id']!, _parentFolderIdMeta));
    }
    if (data.containsKey('api_config_id')) {
      context.handle(
          _apiConfigIdMeta,
          apiConfigId.isAcceptableOrUnknown(
              data['api_config_id']!, _apiConfigIdMeta));
    }
    if (data.containsKey('enable_preprocessing')) {
      context.handle(
          _enablePreprocessingMeta,
          enablePreprocessing.isAcceptableOrUnknown(
              data['enable_preprocessing']!, _enablePreprocessingMeta));
    }
    if (data.containsKey('preprocessing_prompt')) {
      context.handle(
          _preprocessingPromptMeta,
          preprocessingPrompt.isAcceptableOrUnknown(
              data['preprocessing_prompt']!, _preprocessingPromptMeta));
    }
    if (data.containsKey('context_summary')) {
      context.handle(
          _contextSummaryMeta,
          contextSummary.isAcceptableOrUnknown(
              data['context_summary']!, _contextSummaryMeta));
    }
    if (data.containsKey('preprocessing_api_config_id')) {
      context.handle(
          _preprocessingApiConfigIdMeta,
          preprocessingApiConfigId.isAcceptableOrUnknown(
              data['preprocessing_api_config_id']!,
              _preprocessingApiConfigIdMeta));
    }
    if (data.containsKey('enable_secondary_xml')) {
      context.handle(
          _enableSecondaryXmlMeta,
          enableSecondaryXml.isAcceptableOrUnknown(
              data['enable_secondary_xml']!, _enableSecondaryXmlMeta));
    }
    if (data.containsKey('secondary_xml_prompt')) {
      context.handle(
          _secondaryXmlPromptMeta,
          secondaryXmlPrompt.isAcceptableOrUnknown(
              data['secondary_xml_prompt']!, _secondaryXmlPromptMeta));
    }
    if (data.containsKey('secondary_xml_api_config_id')) {
      context.handle(
          _secondaryXmlApiConfigIdMeta,
          secondaryXmlApiConfigId.isAcceptableOrUnknown(
              data['secondary_xml_api_config_id']!,
              _secondaryXmlApiConfigIdMeta));
    }
    if (data.containsKey('continue_prompt')) {
      context.handle(
          _continuePromptMeta,
          continuePrompt.isAcceptableOrUnknown(
              data['continue_prompt']!, _continuePromptMeta));
    }
    if (data.containsKey('enable_help_me_reply')) {
      context.handle(
          _enableHelpMeReplyMeta,
          enableHelpMeReply.isAcceptableOrUnknown(
              data['enable_help_me_reply']!, _enableHelpMeReplyMeta));
    }
    if (data.containsKey('help_me_reply_prompt')) {
      context.handle(
          _helpMeReplyPromptMeta,
          helpMeReplyPrompt.isAcceptableOrUnknown(
              data['help_me_reply_prompt']!, _helpMeReplyPromptMeta));
    }
    if (data.containsKey('help_me_reply_api_config_id')) {
      context.handle(
          _helpMeReplyApiConfigIdMeta,
          helpMeReplyApiConfigId.isAcceptableOrUnknown(
              data['help_me_reply_api_config_id']!,
              _helpMeReplyApiConfigIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChatData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title']),
      systemPrompt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}system_prompt']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      coverImageBase64: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}cover_image_base64']),
      backgroundImagePath: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}background_image_path']),
      orderIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}order_index']),
      isFolder: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_folder']),
      parentFolderId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}parent_folder_id']),
      contextConfig: $ChatsTable.$convertercontextConfig.fromSql(
          attachedDatabase.typeMapping.read(
              DriftSqlType.string, data['${effectivePrefix}context_config'])!),
      xmlRules: $ChatsTable.$converterxmlRules.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}xml_rules'])!),
      apiConfigId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}api_config_id']),
      enablePreprocessing: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}enable_preprocessing']),
      preprocessingPrompt: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}preprocessing_prompt']),
      contextSummary: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}context_summary']),
      preprocessingApiConfigId: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}preprocessing_api_config_id']),
      enableSecondaryXml: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}enable_secondary_xml']),
      secondaryXmlPrompt: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}secondary_xml_prompt']),
      secondaryXmlApiConfigId: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}secondary_xml_api_config_id']),
      continuePrompt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}continue_prompt']),
      enableHelpMeReply: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}enable_help_me_reply']),
      helpMeReplyPrompt: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}help_me_reply_prompt']),
      helpMeReplyApiConfigId: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}help_me_reply_api_config_id']),
      helpMeReplyTriggerMode: $ChatsTable.$converterhelpMeReplyTriggerMode
          .fromSql(attachedDatabase.typeMapping.read(DriftSqlType.string,
              data['${effectivePrefix}help_me_reply_trigger_mode'])),
    );
  }

  @override
  $ChatsTable createAlias(String alias) {
    return $ChatsTable(attachedDatabase, alias);
  }

  static TypeConverter<DriftContextConfig, String> $convertercontextConfig =
      const ContextConfigConverter();
  static TypeConverter<List<DriftXmlRule>, String> $converterxmlRules =
      const XmlRuleListConverter();
  static TypeConverter<HelpMeReplyTriggerMode?, String?>
      $converterhelpMeReplyTriggerMode =
      const HelpMeReplyTriggerModeConverter();
}

class ChatData extends DataClass implements Insertable<ChatData> {
  final int id;
  final String? title;
  final String? systemPrompt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? coverImageBase64;
  final String? backgroundImagePath;
  final int? orderIndex;
  final bool? isFolder;
  final int? parentFolderId;
  final DriftContextConfig contextConfig;
  final List<DriftXmlRule> xmlRules;
  final String? apiConfigId;
  final bool? enablePreprocessing;
  final String? preprocessingPrompt;
  final String? contextSummary;
  final String? preprocessingApiConfigId;
  final bool? enableSecondaryXml;
  final String? secondaryXmlPrompt;
  final String? secondaryXmlApiConfigId;
  final String? continuePrompt;
  final bool? enableHelpMeReply;
  final String? helpMeReplyPrompt;
  final String? helpMeReplyApiConfigId;
  final HelpMeReplyTriggerMode? helpMeReplyTriggerMode;
  const ChatData(
      {required this.id,
      this.title,
      this.systemPrompt,
      required this.createdAt,
      required this.updatedAt,
      this.coverImageBase64,
      this.backgroundImagePath,
      this.orderIndex,
      this.isFolder,
      this.parentFolderId,
      required this.contextConfig,
      required this.xmlRules,
      this.apiConfigId,
      this.enablePreprocessing,
      this.preprocessingPrompt,
      this.contextSummary,
      this.preprocessingApiConfigId,
      this.enableSecondaryXml,
      this.secondaryXmlPrompt,
      this.secondaryXmlApiConfigId,
      this.continuePrompt,
      this.enableHelpMeReply,
      this.helpMeReplyPrompt,
      this.helpMeReplyApiConfigId,
      this.helpMeReplyTriggerMode});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || systemPrompt != null) {
      map['system_prompt'] = Variable<String>(systemPrompt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || coverImageBase64 != null) {
      map['cover_image_base64'] = Variable<String>(coverImageBase64);
    }
    if (!nullToAbsent || backgroundImagePath != null) {
      map['background_image_path'] = Variable<String>(backgroundImagePath);
    }
    if (!nullToAbsent || orderIndex != null) {
      map['order_index'] = Variable<int>(orderIndex);
    }
    if (!nullToAbsent || isFolder != null) {
      map['is_folder'] = Variable<bool>(isFolder);
    }
    if (!nullToAbsent || parentFolderId != null) {
      map['parent_folder_id'] = Variable<int>(parentFolderId);
    }
    {
      map['context_config'] = Variable<String>(
          $ChatsTable.$convertercontextConfig.toSql(contextConfig));
    }
    {
      map['xml_rules'] =
          Variable<String>($ChatsTable.$converterxmlRules.toSql(xmlRules));
    }
    if (!nullToAbsent || apiConfigId != null) {
      map['api_config_id'] = Variable<String>(apiConfigId);
    }
    if (!nullToAbsent || enablePreprocessing != null) {
      map['enable_preprocessing'] = Variable<bool>(enablePreprocessing);
    }
    if (!nullToAbsent || preprocessingPrompt != null) {
      map['preprocessing_prompt'] = Variable<String>(preprocessingPrompt);
    }
    if (!nullToAbsent || contextSummary != null) {
      map['context_summary'] = Variable<String>(contextSummary);
    }
    if (!nullToAbsent || preprocessingApiConfigId != null) {
      map['preprocessing_api_config_id'] =
          Variable<String>(preprocessingApiConfigId);
    }
    if (!nullToAbsent || enableSecondaryXml != null) {
      map['enable_secondary_xml'] = Variable<bool>(enableSecondaryXml);
    }
    if (!nullToAbsent || secondaryXmlPrompt != null) {
      map['secondary_xml_prompt'] = Variable<String>(secondaryXmlPrompt);
    }
    if (!nullToAbsent || secondaryXmlApiConfigId != null) {
      map['secondary_xml_api_config_id'] =
          Variable<String>(secondaryXmlApiConfigId);
    }
    if (!nullToAbsent || continuePrompt != null) {
      map['continue_prompt'] = Variable<String>(continuePrompt);
    }
    if (!nullToAbsent || enableHelpMeReply != null) {
      map['enable_help_me_reply'] = Variable<bool>(enableHelpMeReply);
    }
    if (!nullToAbsent || helpMeReplyPrompt != null) {
      map['help_me_reply_prompt'] = Variable<String>(helpMeReplyPrompt);
    }
    if (!nullToAbsent || helpMeReplyApiConfigId != null) {
      map['help_me_reply_api_config_id'] =
          Variable<String>(helpMeReplyApiConfigId);
    }
    if (!nullToAbsent || helpMeReplyTriggerMode != null) {
      map['help_me_reply_trigger_mode'] = Variable<String>($ChatsTable
          .$converterhelpMeReplyTriggerMode
          .toSql(helpMeReplyTriggerMode));
    }
    return map;
  }

  ChatsCompanion toCompanion(bool nullToAbsent) {
    return ChatsCompanion(
      id: Value(id),
      title:
          title == null && nullToAbsent ? const Value.absent() : Value(title),
      systemPrompt: systemPrompt == null && nullToAbsent
          ? const Value.absent()
          : Value(systemPrompt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      coverImageBase64: coverImageBase64 == null && nullToAbsent
          ? const Value.absent()
          : Value(coverImageBase64),
      backgroundImagePath: backgroundImagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(backgroundImagePath),
      orderIndex: orderIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(orderIndex),
      isFolder: isFolder == null && nullToAbsent
          ? const Value.absent()
          : Value(isFolder),
      parentFolderId: parentFolderId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentFolderId),
      contextConfig: Value(contextConfig),
      xmlRules: Value(xmlRules),
      apiConfigId: apiConfigId == null && nullToAbsent
          ? const Value.absent()
          : Value(apiConfigId),
      enablePreprocessing: enablePreprocessing == null && nullToAbsent
          ? const Value.absent()
          : Value(enablePreprocessing),
      preprocessingPrompt: preprocessingPrompt == null && nullToAbsent
          ? const Value.absent()
          : Value(preprocessingPrompt),
      contextSummary: contextSummary == null && nullToAbsent
          ? const Value.absent()
          : Value(contextSummary),
      preprocessingApiConfigId: preprocessingApiConfigId == null && nullToAbsent
          ? const Value.absent()
          : Value(preprocessingApiConfigId),
      enableSecondaryXml: enableSecondaryXml == null && nullToAbsent
          ? const Value.absent()
          : Value(enableSecondaryXml),
      secondaryXmlPrompt: secondaryXmlPrompt == null && nullToAbsent
          ? const Value.absent()
          : Value(secondaryXmlPrompt),
      secondaryXmlApiConfigId: secondaryXmlApiConfigId == null && nullToAbsent
          ? const Value.absent()
          : Value(secondaryXmlApiConfigId),
      continuePrompt: continuePrompt == null && nullToAbsent
          ? const Value.absent()
          : Value(continuePrompt),
      enableHelpMeReply: enableHelpMeReply == null && nullToAbsent
          ? const Value.absent()
          : Value(enableHelpMeReply),
      helpMeReplyPrompt: helpMeReplyPrompt == null && nullToAbsent
          ? const Value.absent()
          : Value(helpMeReplyPrompt),
      helpMeReplyApiConfigId: helpMeReplyApiConfigId == null && nullToAbsent
          ? const Value.absent()
          : Value(helpMeReplyApiConfigId),
      helpMeReplyTriggerMode: helpMeReplyTriggerMode == null && nullToAbsent
          ? const Value.absent()
          : Value(helpMeReplyTriggerMode),
    );
  }

  factory ChatData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatData(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String?>(json['title']),
      systemPrompt: serializer.fromJson<String?>(json['systemPrompt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      coverImageBase64: serializer.fromJson<String?>(json['coverImageBase64']),
      backgroundImagePath:
          serializer.fromJson<String?>(json['backgroundImagePath']),
      orderIndex: serializer.fromJson<int?>(json['orderIndex']),
      isFolder: serializer.fromJson<bool?>(json['isFolder']),
      parentFolderId: serializer.fromJson<int?>(json['parentFolderId']),
      contextConfig:
          serializer.fromJson<DriftContextConfig>(json['contextConfig']),
      xmlRules: serializer.fromJson<List<DriftXmlRule>>(json['xmlRules']),
      apiConfigId: serializer.fromJson<String?>(json['apiConfigId']),
      enablePreprocessing:
          serializer.fromJson<bool?>(json['enablePreprocessing']),
      preprocessingPrompt:
          serializer.fromJson<String?>(json['preprocessingPrompt']),
      contextSummary: serializer.fromJson<String?>(json['contextSummary']),
      preprocessingApiConfigId:
          serializer.fromJson<String?>(json['preprocessingApiConfigId']),
      enableSecondaryXml:
          serializer.fromJson<bool?>(json['enableSecondaryXml']),
      secondaryXmlPrompt:
          serializer.fromJson<String?>(json['secondaryXmlPrompt']),
      secondaryXmlApiConfigId:
          serializer.fromJson<String?>(json['secondaryXmlApiConfigId']),
      continuePrompt: serializer.fromJson<String?>(json['continuePrompt']),
      enableHelpMeReply: serializer.fromJson<bool?>(json['enableHelpMeReply']),
      helpMeReplyPrompt:
          serializer.fromJson<String?>(json['helpMeReplyPrompt']),
      helpMeReplyApiConfigId:
          serializer.fromJson<String?>(json['helpMeReplyApiConfigId']),
      helpMeReplyTriggerMode: serializer
          .fromJson<HelpMeReplyTriggerMode?>(json['helpMeReplyTriggerMode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String?>(title),
      'systemPrompt': serializer.toJson<String?>(systemPrompt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'coverImageBase64': serializer.toJson<String?>(coverImageBase64),
      'backgroundImagePath': serializer.toJson<String?>(backgroundImagePath),
      'orderIndex': serializer.toJson<int?>(orderIndex),
      'isFolder': serializer.toJson<bool?>(isFolder),
      'parentFolderId': serializer.toJson<int?>(parentFolderId),
      'contextConfig': serializer.toJson<DriftContextConfig>(contextConfig),
      'xmlRules': serializer.toJson<List<DriftXmlRule>>(xmlRules),
      'apiConfigId': serializer.toJson<String?>(apiConfigId),
      'enablePreprocessing': serializer.toJson<bool?>(enablePreprocessing),
      'preprocessingPrompt': serializer.toJson<String?>(preprocessingPrompt),
      'contextSummary': serializer.toJson<String?>(contextSummary),
      'preprocessingApiConfigId':
          serializer.toJson<String?>(preprocessingApiConfigId),
      'enableSecondaryXml': serializer.toJson<bool?>(enableSecondaryXml),
      'secondaryXmlPrompt': serializer.toJson<String?>(secondaryXmlPrompt),
      'secondaryXmlApiConfigId':
          serializer.toJson<String?>(secondaryXmlApiConfigId),
      'continuePrompt': serializer.toJson<String?>(continuePrompt),
      'enableHelpMeReply': serializer.toJson<bool?>(enableHelpMeReply),
      'helpMeReplyPrompt': serializer.toJson<String?>(helpMeReplyPrompt),
      'helpMeReplyApiConfigId':
          serializer.toJson<String?>(helpMeReplyApiConfigId),
      'helpMeReplyTriggerMode':
          serializer.toJson<HelpMeReplyTriggerMode?>(helpMeReplyTriggerMode),
    };
  }

  ChatData copyWith(
          {int? id,
          Value<String?> title = const Value.absent(),
          Value<String?> systemPrompt = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<String?> coverImageBase64 = const Value.absent(),
          Value<String?> backgroundImagePath = const Value.absent(),
          Value<int?> orderIndex = const Value.absent(),
          Value<bool?> isFolder = const Value.absent(),
          Value<int?> parentFolderId = const Value.absent(),
          DriftContextConfig? contextConfig,
          List<DriftXmlRule>? xmlRules,
          Value<String?> apiConfigId = const Value.absent(),
          Value<bool?> enablePreprocessing = const Value.absent(),
          Value<String?> preprocessingPrompt = const Value.absent(),
          Value<String?> contextSummary = const Value.absent(),
          Value<String?> preprocessingApiConfigId = const Value.absent(),
          Value<bool?> enableSecondaryXml = const Value.absent(),
          Value<String?> secondaryXmlPrompt = const Value.absent(),
          Value<String?> secondaryXmlApiConfigId = const Value.absent(),
          Value<String?> continuePrompt = const Value.absent(),
          Value<bool?> enableHelpMeReply = const Value.absent(),
          Value<String?> helpMeReplyPrompt = const Value.absent(),
          Value<String?> helpMeReplyApiConfigId = const Value.absent(),
          Value<HelpMeReplyTriggerMode?> helpMeReplyTriggerMode =
              const Value.absent()}) =>
      ChatData(
        id: id ?? this.id,
        title: title.present ? title.value : this.title,
        systemPrompt:
            systemPrompt.present ? systemPrompt.value : this.systemPrompt,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        coverImageBase64: coverImageBase64.present
            ? coverImageBase64.value
            : this.coverImageBase64,
        backgroundImagePath: backgroundImagePath.present
            ? backgroundImagePath.value
            : this.backgroundImagePath,
        orderIndex: orderIndex.present ? orderIndex.value : this.orderIndex,
        isFolder: isFolder.present ? isFolder.value : this.isFolder,
        parentFolderId:
            parentFolderId.present ? parentFolderId.value : this.parentFolderId,
        contextConfig: contextConfig ?? this.contextConfig,
        xmlRules: xmlRules ?? this.xmlRules,
        apiConfigId: apiConfigId.present ? apiConfigId.value : this.apiConfigId,
        enablePreprocessing: enablePreprocessing.present
            ? enablePreprocessing.value
            : this.enablePreprocessing,
        preprocessingPrompt: preprocessingPrompt.present
            ? preprocessingPrompt.value
            : this.preprocessingPrompt,
        contextSummary:
            contextSummary.present ? contextSummary.value : this.contextSummary,
        preprocessingApiConfigId: preprocessingApiConfigId.present
            ? preprocessingApiConfigId.value
            : this.preprocessingApiConfigId,
        enableSecondaryXml: enableSecondaryXml.present
            ? enableSecondaryXml.value
            : this.enableSecondaryXml,
        secondaryXmlPrompt: secondaryXmlPrompt.present
            ? secondaryXmlPrompt.value
            : this.secondaryXmlPrompt,
        secondaryXmlApiConfigId: secondaryXmlApiConfigId.present
            ? secondaryXmlApiConfigId.value
            : this.secondaryXmlApiConfigId,
        continuePrompt:
            continuePrompt.present ? continuePrompt.value : this.continuePrompt,
        enableHelpMeReply: enableHelpMeReply.present
            ? enableHelpMeReply.value
            : this.enableHelpMeReply,
        helpMeReplyPrompt: helpMeReplyPrompt.present
            ? helpMeReplyPrompt.value
            : this.helpMeReplyPrompt,
        helpMeReplyApiConfigId: helpMeReplyApiConfigId.present
            ? helpMeReplyApiConfigId.value
            : this.helpMeReplyApiConfigId,
        helpMeReplyTriggerMode: helpMeReplyTriggerMode.present
            ? helpMeReplyTriggerMode.value
            : this.helpMeReplyTriggerMode,
      );
  ChatData copyWithCompanion(ChatsCompanion data) {
    return ChatData(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      systemPrompt: data.systemPrompt.present
          ? data.systemPrompt.value
          : this.systemPrompt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      coverImageBase64: data.coverImageBase64.present
          ? data.coverImageBase64.value
          : this.coverImageBase64,
      backgroundImagePath: data.backgroundImagePath.present
          ? data.backgroundImagePath.value
          : this.backgroundImagePath,
      orderIndex:
          data.orderIndex.present ? data.orderIndex.value : this.orderIndex,
      isFolder: data.isFolder.present ? data.isFolder.value : this.isFolder,
      parentFolderId: data.parentFolderId.present
          ? data.parentFolderId.value
          : this.parentFolderId,
      contextConfig: data.contextConfig.present
          ? data.contextConfig.value
          : this.contextConfig,
      xmlRules: data.xmlRules.present ? data.xmlRules.value : this.xmlRules,
      apiConfigId:
          data.apiConfigId.present ? data.apiConfigId.value : this.apiConfigId,
      enablePreprocessing: data.enablePreprocessing.present
          ? data.enablePreprocessing.value
          : this.enablePreprocessing,
      preprocessingPrompt: data.preprocessingPrompt.present
          ? data.preprocessingPrompt.value
          : this.preprocessingPrompt,
      contextSummary: data.contextSummary.present
          ? data.contextSummary.value
          : this.contextSummary,
      preprocessingApiConfigId: data.preprocessingApiConfigId.present
          ? data.preprocessingApiConfigId.value
          : this.preprocessingApiConfigId,
      enableSecondaryXml: data.enableSecondaryXml.present
          ? data.enableSecondaryXml.value
          : this.enableSecondaryXml,
      secondaryXmlPrompt: data.secondaryXmlPrompt.present
          ? data.secondaryXmlPrompt.value
          : this.secondaryXmlPrompt,
      secondaryXmlApiConfigId: data.secondaryXmlApiConfigId.present
          ? data.secondaryXmlApiConfigId.value
          : this.secondaryXmlApiConfigId,
      continuePrompt: data.continuePrompt.present
          ? data.continuePrompt.value
          : this.continuePrompt,
      enableHelpMeReply: data.enableHelpMeReply.present
          ? data.enableHelpMeReply.value
          : this.enableHelpMeReply,
      helpMeReplyPrompt: data.helpMeReplyPrompt.present
          ? data.helpMeReplyPrompt.value
          : this.helpMeReplyPrompt,
      helpMeReplyApiConfigId: data.helpMeReplyApiConfigId.present
          ? data.helpMeReplyApiConfigId.value
          : this.helpMeReplyApiConfigId,
      helpMeReplyTriggerMode: data.helpMeReplyTriggerMode.present
          ? data.helpMeReplyTriggerMode.value
          : this.helpMeReplyTriggerMode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatData(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('systemPrompt: $systemPrompt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('coverImageBase64: $coverImageBase64, ')
          ..write('backgroundImagePath: $backgroundImagePath, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('isFolder: $isFolder, ')
          ..write('parentFolderId: $parentFolderId, ')
          ..write('contextConfig: $contextConfig, ')
          ..write('xmlRules: $xmlRules, ')
          ..write('apiConfigId: $apiConfigId, ')
          ..write('enablePreprocessing: $enablePreprocessing, ')
          ..write('preprocessingPrompt: $preprocessingPrompt, ')
          ..write('contextSummary: $contextSummary, ')
          ..write('preprocessingApiConfigId: $preprocessingApiConfigId, ')
          ..write('enableSecondaryXml: $enableSecondaryXml, ')
          ..write('secondaryXmlPrompt: $secondaryXmlPrompt, ')
          ..write('secondaryXmlApiConfigId: $secondaryXmlApiConfigId, ')
          ..write('continuePrompt: $continuePrompt, ')
          ..write('enableHelpMeReply: $enableHelpMeReply, ')
          ..write('helpMeReplyPrompt: $helpMeReplyPrompt, ')
          ..write('helpMeReplyApiConfigId: $helpMeReplyApiConfigId, ')
          ..write('helpMeReplyTriggerMode: $helpMeReplyTriggerMode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        title,
        systemPrompt,
        createdAt,
        updatedAt,
        coverImageBase64,
        backgroundImagePath,
        orderIndex,
        isFolder,
        parentFolderId,
        contextConfig,
        xmlRules,
        apiConfigId,
        enablePreprocessing,
        preprocessingPrompt,
        contextSummary,
        preprocessingApiConfigId,
        enableSecondaryXml,
        secondaryXmlPrompt,
        secondaryXmlApiConfigId,
        continuePrompt,
        enableHelpMeReply,
        helpMeReplyPrompt,
        helpMeReplyApiConfigId,
        helpMeReplyTriggerMode
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatData &&
          other.id == this.id &&
          other.title == this.title &&
          other.systemPrompt == this.systemPrompt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.coverImageBase64 == this.coverImageBase64 &&
          other.backgroundImagePath == this.backgroundImagePath &&
          other.orderIndex == this.orderIndex &&
          other.isFolder == this.isFolder &&
          other.parentFolderId == this.parentFolderId &&
          other.contextConfig == this.contextConfig &&
          other.xmlRules == this.xmlRules &&
          other.apiConfigId == this.apiConfigId &&
          other.enablePreprocessing == this.enablePreprocessing &&
          other.preprocessingPrompt == this.preprocessingPrompt &&
          other.contextSummary == this.contextSummary &&
          other.preprocessingApiConfigId == this.preprocessingApiConfigId &&
          other.enableSecondaryXml == this.enableSecondaryXml &&
          other.secondaryXmlPrompt == this.secondaryXmlPrompt &&
          other.secondaryXmlApiConfigId == this.secondaryXmlApiConfigId &&
          other.continuePrompt == this.continuePrompt &&
          other.enableHelpMeReply == this.enableHelpMeReply &&
          other.helpMeReplyPrompt == this.helpMeReplyPrompt &&
          other.helpMeReplyApiConfigId == this.helpMeReplyApiConfigId &&
          other.helpMeReplyTriggerMode == this.helpMeReplyTriggerMode);
}

class ChatsCompanion extends UpdateCompanion<ChatData> {
  final Value<int> id;
  final Value<String?> title;
  final Value<String?> systemPrompt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String?> coverImageBase64;
  final Value<String?> backgroundImagePath;
  final Value<int?> orderIndex;
  final Value<bool?> isFolder;
  final Value<int?> parentFolderId;
  final Value<DriftContextConfig> contextConfig;
  final Value<List<DriftXmlRule>> xmlRules;
  final Value<String?> apiConfigId;
  final Value<bool?> enablePreprocessing;
  final Value<String?> preprocessingPrompt;
  final Value<String?> contextSummary;
  final Value<String?> preprocessingApiConfigId;
  final Value<bool?> enableSecondaryXml;
  final Value<String?> secondaryXmlPrompt;
  final Value<String?> secondaryXmlApiConfigId;
  final Value<String?> continuePrompt;
  final Value<bool?> enableHelpMeReply;
  final Value<String?> helpMeReplyPrompt;
  final Value<String?> helpMeReplyApiConfigId;
  final Value<HelpMeReplyTriggerMode?> helpMeReplyTriggerMode;
  const ChatsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.systemPrompt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.coverImageBase64 = const Value.absent(),
    this.backgroundImagePath = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.isFolder = const Value.absent(),
    this.parentFolderId = const Value.absent(),
    this.contextConfig = const Value.absent(),
    this.xmlRules = const Value.absent(),
    this.apiConfigId = const Value.absent(),
    this.enablePreprocessing = const Value.absent(),
    this.preprocessingPrompt = const Value.absent(),
    this.contextSummary = const Value.absent(),
    this.preprocessingApiConfigId = const Value.absent(),
    this.enableSecondaryXml = const Value.absent(),
    this.secondaryXmlPrompt = const Value.absent(),
    this.secondaryXmlApiConfigId = const Value.absent(),
    this.continuePrompt = const Value.absent(),
    this.enableHelpMeReply = const Value.absent(),
    this.helpMeReplyPrompt = const Value.absent(),
    this.helpMeReplyApiConfigId = const Value.absent(),
    this.helpMeReplyTriggerMode = const Value.absent(),
  });
  ChatsCompanion.insert({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.systemPrompt = const Value.absent(),
    this.createdAt = const Value.absent(),
    required DateTime updatedAt,
    this.coverImageBase64 = const Value.absent(),
    this.backgroundImagePath = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.isFolder = const Value.absent(),
    this.parentFolderId = const Value.absent(),
    required DriftContextConfig contextConfig,
    required List<DriftXmlRule> xmlRules,
    this.apiConfigId = const Value.absent(),
    this.enablePreprocessing = const Value.absent(),
    this.preprocessingPrompt = const Value.absent(),
    this.contextSummary = const Value.absent(),
    this.preprocessingApiConfigId = const Value.absent(),
    this.enableSecondaryXml = const Value.absent(),
    this.secondaryXmlPrompt = const Value.absent(),
    this.secondaryXmlApiConfigId = const Value.absent(),
    this.continuePrompt = const Value.absent(),
    this.enableHelpMeReply = const Value.absent(),
    this.helpMeReplyPrompt = const Value.absent(),
    this.helpMeReplyApiConfigId = const Value.absent(),
    this.helpMeReplyTriggerMode = const Value.absent(),
  })  : updatedAt = Value(updatedAt),
        contextConfig = Value(contextConfig),
        xmlRules = Value(xmlRules);
  static Insertable<ChatData> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? systemPrompt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? coverImageBase64,
    Expression<String>? backgroundImagePath,
    Expression<int>? orderIndex,
    Expression<bool>? isFolder,
    Expression<int>? parentFolderId,
    Expression<String>? contextConfig,
    Expression<String>? xmlRules,
    Expression<String>? apiConfigId,
    Expression<bool>? enablePreprocessing,
    Expression<String>? preprocessingPrompt,
    Expression<String>? contextSummary,
    Expression<String>? preprocessingApiConfigId,
    Expression<bool>? enableSecondaryXml,
    Expression<String>? secondaryXmlPrompt,
    Expression<String>? secondaryXmlApiConfigId,
    Expression<String>? continuePrompt,
    Expression<bool>? enableHelpMeReply,
    Expression<String>? helpMeReplyPrompt,
    Expression<String>? helpMeReplyApiConfigId,
    Expression<String>? helpMeReplyTriggerMode,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (systemPrompt != null) 'system_prompt': systemPrompt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (coverImageBase64 != null) 'cover_image_base64': coverImageBase64,
      if (backgroundImagePath != null)
        'background_image_path': backgroundImagePath,
      if (orderIndex != null) 'order_index': orderIndex,
      if (isFolder != null) 'is_folder': isFolder,
      if (parentFolderId != null) 'parent_folder_id': parentFolderId,
      if (contextConfig != null) 'context_config': contextConfig,
      if (xmlRules != null) 'xml_rules': xmlRules,
      if (apiConfigId != null) 'api_config_id': apiConfigId,
      if (enablePreprocessing != null)
        'enable_preprocessing': enablePreprocessing,
      if (preprocessingPrompt != null)
        'preprocessing_prompt': preprocessingPrompt,
      if (contextSummary != null) 'context_summary': contextSummary,
      if (preprocessingApiConfigId != null)
        'preprocessing_api_config_id': preprocessingApiConfigId,
      if (enableSecondaryXml != null)
        'enable_secondary_xml': enableSecondaryXml,
      if (secondaryXmlPrompt != null)
        'secondary_xml_prompt': secondaryXmlPrompt,
      if (secondaryXmlApiConfigId != null)
        'secondary_xml_api_config_id': secondaryXmlApiConfigId,
      if (continuePrompt != null) 'continue_prompt': continuePrompt,
      if (enableHelpMeReply != null) 'enable_help_me_reply': enableHelpMeReply,
      if (helpMeReplyPrompt != null) 'help_me_reply_prompt': helpMeReplyPrompt,
      if (helpMeReplyApiConfigId != null)
        'help_me_reply_api_config_id': helpMeReplyApiConfigId,
      if (helpMeReplyTriggerMode != null)
        'help_me_reply_trigger_mode': helpMeReplyTriggerMode,
    });
  }

  ChatsCompanion copyWith(
      {Value<int>? id,
      Value<String?>? title,
      Value<String?>? systemPrompt,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<String?>? coverImageBase64,
      Value<String?>? backgroundImagePath,
      Value<int?>? orderIndex,
      Value<bool?>? isFolder,
      Value<int?>? parentFolderId,
      Value<DriftContextConfig>? contextConfig,
      Value<List<DriftXmlRule>>? xmlRules,
      Value<String?>? apiConfigId,
      Value<bool?>? enablePreprocessing,
      Value<String?>? preprocessingPrompt,
      Value<String?>? contextSummary,
      Value<String?>? preprocessingApiConfigId,
      Value<bool?>? enableSecondaryXml,
      Value<String?>? secondaryXmlPrompt,
      Value<String?>? secondaryXmlApiConfigId,
      Value<String?>? continuePrompt,
      Value<bool?>? enableHelpMeReply,
      Value<String?>? helpMeReplyPrompt,
      Value<String?>? helpMeReplyApiConfigId,
      Value<HelpMeReplyTriggerMode?>? helpMeReplyTriggerMode}) {
    return ChatsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      coverImageBase64: coverImageBase64 ?? this.coverImageBase64,
      backgroundImagePath: backgroundImagePath ?? this.backgroundImagePath,
      orderIndex: orderIndex ?? this.orderIndex,
      isFolder: isFolder ?? this.isFolder,
      parentFolderId: parentFolderId ?? this.parentFolderId,
      contextConfig: contextConfig ?? this.contextConfig,
      xmlRules: xmlRules ?? this.xmlRules,
      apiConfigId: apiConfigId ?? this.apiConfigId,
      enablePreprocessing: enablePreprocessing ?? this.enablePreprocessing,
      preprocessingPrompt: preprocessingPrompt ?? this.preprocessingPrompt,
      contextSummary: contextSummary ?? this.contextSummary,
      preprocessingApiConfigId:
          preprocessingApiConfigId ?? this.preprocessingApiConfigId,
      enableSecondaryXml: enableSecondaryXml ?? this.enableSecondaryXml,
      secondaryXmlPrompt: secondaryXmlPrompt ?? this.secondaryXmlPrompt,
      secondaryXmlApiConfigId:
          secondaryXmlApiConfigId ?? this.secondaryXmlApiConfigId,
      continuePrompt: continuePrompt ?? this.continuePrompt,
      enableHelpMeReply: enableHelpMeReply ?? this.enableHelpMeReply,
      helpMeReplyPrompt: helpMeReplyPrompt ?? this.helpMeReplyPrompt,
      helpMeReplyApiConfigId:
          helpMeReplyApiConfigId ?? this.helpMeReplyApiConfigId,
      helpMeReplyTriggerMode:
          helpMeReplyTriggerMode ?? this.helpMeReplyTriggerMode,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (systemPrompt.present) {
      map['system_prompt'] = Variable<String>(systemPrompt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (coverImageBase64.present) {
      map['cover_image_base64'] = Variable<String>(coverImageBase64.value);
    }
    if (backgroundImagePath.present) {
      map['background_image_path'] =
          Variable<String>(backgroundImagePath.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (isFolder.present) {
      map['is_folder'] = Variable<bool>(isFolder.value);
    }
    if (parentFolderId.present) {
      map['parent_folder_id'] = Variable<int>(parentFolderId.value);
    }
    if (contextConfig.present) {
      map['context_config'] = Variable<String>(
          $ChatsTable.$convertercontextConfig.toSql(contextConfig.value));
    }
    if (xmlRules.present) {
      map['xml_rules'] = Variable<String>(
          $ChatsTable.$converterxmlRules.toSql(xmlRules.value));
    }
    if (apiConfigId.present) {
      map['api_config_id'] = Variable<String>(apiConfigId.value);
    }
    if (enablePreprocessing.present) {
      map['enable_preprocessing'] = Variable<bool>(enablePreprocessing.value);
    }
    if (preprocessingPrompt.present) {
      map['preprocessing_prompt'] = Variable<String>(preprocessingPrompt.value);
    }
    if (contextSummary.present) {
      map['context_summary'] = Variable<String>(contextSummary.value);
    }
    if (preprocessingApiConfigId.present) {
      map['preprocessing_api_config_id'] =
          Variable<String>(preprocessingApiConfigId.value);
    }
    if (enableSecondaryXml.present) {
      map['enable_secondary_xml'] = Variable<bool>(enableSecondaryXml.value);
    }
    if (secondaryXmlPrompt.present) {
      map['secondary_xml_prompt'] = Variable<String>(secondaryXmlPrompt.value);
    }
    if (secondaryXmlApiConfigId.present) {
      map['secondary_xml_api_config_id'] =
          Variable<String>(secondaryXmlApiConfigId.value);
    }
    if (continuePrompt.present) {
      map['continue_prompt'] = Variable<String>(continuePrompt.value);
    }
    if (enableHelpMeReply.present) {
      map['enable_help_me_reply'] = Variable<bool>(enableHelpMeReply.value);
    }
    if (helpMeReplyPrompt.present) {
      map['help_me_reply_prompt'] = Variable<String>(helpMeReplyPrompt.value);
    }
    if (helpMeReplyApiConfigId.present) {
      map['help_me_reply_api_config_id'] =
          Variable<String>(helpMeReplyApiConfigId.value);
    }
    if (helpMeReplyTriggerMode.present) {
      map['help_me_reply_trigger_mode'] = Variable<String>($ChatsTable
          .$converterhelpMeReplyTriggerMode
          .toSql(helpMeReplyTriggerMode.value));
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('systemPrompt: $systemPrompt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('coverImageBase64: $coverImageBase64, ')
          ..write('backgroundImagePath: $backgroundImagePath, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('isFolder: $isFolder, ')
          ..write('parentFolderId: $parentFolderId, ')
          ..write('contextConfig: $contextConfig, ')
          ..write('xmlRules: $xmlRules, ')
          ..write('apiConfigId: $apiConfigId, ')
          ..write('enablePreprocessing: $enablePreprocessing, ')
          ..write('preprocessingPrompt: $preprocessingPrompt, ')
          ..write('contextSummary: $contextSummary, ')
          ..write('preprocessingApiConfigId: $preprocessingApiConfigId, ')
          ..write('enableSecondaryXml: $enableSecondaryXml, ')
          ..write('secondaryXmlPrompt: $secondaryXmlPrompt, ')
          ..write('secondaryXmlApiConfigId: $secondaryXmlApiConfigId, ')
          ..write('continuePrompt: $continuePrompt, ')
          ..write('enableHelpMeReply: $enableHelpMeReply, ')
          ..write('helpMeReplyPrompt: $helpMeReplyPrompt, ')
          ..write('helpMeReplyApiConfigId: $helpMeReplyApiConfigId, ')
          ..write('helpMeReplyTriggerMode: $helpMeReplyTriggerMode')
          ..write(')'))
        .toString();
  }
}

class $MessagesTable extends Messages
    with TableInfo<$MessagesTable, MessageData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _chatIdMeta = const VerificationMeta('chatId');
  @override
  late final GeneratedColumn<int> chatId = GeneratedColumn<int>(
      'chat_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES chats (id)'));
  static const VerificationMeta _rawTextMeta =
      const VerificationMeta('rawText');
  @override
  late final GeneratedColumn<String> rawText = GeneratedColumn<String>(
      'raw_text', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<MessageRole, String> role =
      GeneratedColumn<String>('role', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<MessageRole>($MessagesTable.$converterrole);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _originalXmlContentMeta =
      const VerificationMeta('originalXmlContent');
  @override
  late final GeneratedColumn<String> originalXmlContent =
      GeneratedColumn<String>('original_xml_content', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _secondaryXmlContentMeta =
      const VerificationMeta('secondaryXmlContent');
  @override
  late final GeneratedColumn<String> secondaryXmlContent =
      GeneratedColumn<String>('secondary_xml_content', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        chatId,
        rawText,
        role,
        timestamp,
        originalXmlContent,
        secondaryXmlContent
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(Insertable<MessageData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('chat_id')) {
      context.handle(_chatIdMeta,
          chatId.isAcceptableOrUnknown(data['chat_id']!, _chatIdMeta));
    } else if (isInserting) {
      context.missing(_chatIdMeta);
    }
    if (data.containsKey('raw_text')) {
      context.handle(_rawTextMeta,
          rawText.isAcceptableOrUnknown(data['raw_text']!, _rawTextMeta));
    } else if (isInserting) {
      context.missing(_rawTextMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('original_xml_content')) {
      context.handle(
          _originalXmlContentMeta,
          originalXmlContent.isAcceptableOrUnknown(
              data['original_xml_content']!, _originalXmlContentMeta));
    }
    if (data.containsKey('secondary_xml_content')) {
      context.handle(
          _secondaryXmlContentMeta,
          secondaryXmlContent.isAcceptableOrUnknown(
              data['secondary_xml_content']!, _secondaryXmlContentMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MessageData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      chatId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}chat_id'])!,
      rawText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}raw_text'])!,
      role: $MessagesTable.$converterrole.fromSql(attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}role'])!),
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
      originalXmlContent: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}original_xml_content']),
      secondaryXmlContent: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}secondary_xml_content']),
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }

  static TypeConverter<MessageRole, String> $converterrole =
      const MessageRoleConverter();
}

class MessageData extends DataClass implements Insertable<MessageData> {
  final int id;
  final int chatId;
  final String rawText;
  final MessageRole role;
  final DateTime timestamp;
  final String? originalXmlContent;
  final String? secondaryXmlContent;
  const MessageData(
      {required this.id,
      required this.chatId,
      required this.rawText,
      required this.role,
      required this.timestamp,
      this.originalXmlContent,
      this.secondaryXmlContent});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['chat_id'] = Variable<int>(chatId);
    map['raw_text'] = Variable<String>(rawText);
    {
      map['role'] = Variable<String>($MessagesTable.$converterrole.toSql(role));
    }
    map['timestamp'] = Variable<DateTime>(timestamp);
    if (!nullToAbsent || originalXmlContent != null) {
      map['original_xml_content'] = Variable<String>(originalXmlContent);
    }
    if (!nullToAbsent || secondaryXmlContent != null) {
      map['secondary_xml_content'] = Variable<String>(secondaryXmlContent);
    }
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
      chatId: Value(chatId),
      rawText: Value(rawText),
      role: Value(role),
      timestamp: Value(timestamp),
      originalXmlContent: originalXmlContent == null && nullToAbsent
          ? const Value.absent()
          : Value(originalXmlContent),
      secondaryXmlContent: secondaryXmlContent == null && nullToAbsent
          ? const Value.absent()
          : Value(secondaryXmlContent),
    );
  }

  factory MessageData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageData(
      id: serializer.fromJson<int>(json['id']),
      chatId: serializer.fromJson<int>(json['chatId']),
      rawText: serializer.fromJson<String>(json['rawText']),
      role: serializer.fromJson<MessageRole>(json['role']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      originalXmlContent:
          serializer.fromJson<String?>(json['originalXmlContent']),
      secondaryXmlContent:
          serializer.fromJson<String?>(json['secondaryXmlContent']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'chatId': serializer.toJson<int>(chatId),
      'rawText': serializer.toJson<String>(rawText),
      'role': serializer.toJson<MessageRole>(role),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'originalXmlContent': serializer.toJson<String?>(originalXmlContent),
      'secondaryXmlContent': serializer.toJson<String?>(secondaryXmlContent),
    };
  }

  MessageData copyWith(
          {int? id,
          int? chatId,
          String? rawText,
          MessageRole? role,
          DateTime? timestamp,
          Value<String?> originalXmlContent = const Value.absent(),
          Value<String?> secondaryXmlContent = const Value.absent()}) =>
      MessageData(
        id: id ?? this.id,
        chatId: chatId ?? this.chatId,
        rawText: rawText ?? this.rawText,
        role: role ?? this.role,
        timestamp: timestamp ?? this.timestamp,
        originalXmlContent: originalXmlContent.present
            ? originalXmlContent.value
            : this.originalXmlContent,
        secondaryXmlContent: secondaryXmlContent.present
            ? secondaryXmlContent.value
            : this.secondaryXmlContent,
      );
  MessageData copyWithCompanion(MessagesCompanion data) {
    return MessageData(
      id: data.id.present ? data.id.value : this.id,
      chatId: data.chatId.present ? data.chatId.value : this.chatId,
      rawText: data.rawText.present ? data.rawText.value : this.rawText,
      role: data.role.present ? data.role.value : this.role,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      originalXmlContent: data.originalXmlContent.present
          ? data.originalXmlContent.value
          : this.originalXmlContent,
      secondaryXmlContent: data.secondaryXmlContent.present
          ? data.secondaryXmlContent.value
          : this.secondaryXmlContent,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageData(')
          ..write('id: $id, ')
          ..write('chatId: $chatId, ')
          ..write('rawText: $rawText, ')
          ..write('role: $role, ')
          ..write('timestamp: $timestamp, ')
          ..write('originalXmlContent: $originalXmlContent, ')
          ..write('secondaryXmlContent: $secondaryXmlContent')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, chatId, rawText, role, timestamp,
      originalXmlContent, secondaryXmlContent);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageData &&
          other.id == this.id &&
          other.chatId == this.chatId &&
          other.rawText == this.rawText &&
          other.role == this.role &&
          other.timestamp == this.timestamp &&
          other.originalXmlContent == this.originalXmlContent &&
          other.secondaryXmlContent == this.secondaryXmlContent);
}

class MessagesCompanion extends UpdateCompanion<MessageData> {
  final Value<int> id;
  final Value<int> chatId;
  final Value<String> rawText;
  final Value<MessageRole> role;
  final Value<DateTime> timestamp;
  final Value<String?> originalXmlContent;
  final Value<String?> secondaryXmlContent;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.chatId = const Value.absent(),
    this.rawText = const Value.absent(),
    this.role = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.originalXmlContent = const Value.absent(),
    this.secondaryXmlContent = const Value.absent(),
  });
  MessagesCompanion.insert({
    this.id = const Value.absent(),
    required int chatId,
    required String rawText,
    required MessageRole role,
    required DateTime timestamp,
    this.originalXmlContent = const Value.absent(),
    this.secondaryXmlContent = const Value.absent(),
  })  : chatId = Value(chatId),
        rawText = Value(rawText),
        role = Value(role),
        timestamp = Value(timestamp);
  static Insertable<MessageData> custom({
    Expression<int>? id,
    Expression<int>? chatId,
    Expression<String>? rawText,
    Expression<String>? role,
    Expression<DateTime>? timestamp,
    Expression<String>? originalXmlContent,
    Expression<String>? secondaryXmlContent,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (chatId != null) 'chat_id': chatId,
      if (rawText != null) 'raw_text': rawText,
      if (role != null) 'role': role,
      if (timestamp != null) 'timestamp': timestamp,
      if (originalXmlContent != null)
        'original_xml_content': originalXmlContent,
      if (secondaryXmlContent != null)
        'secondary_xml_content': secondaryXmlContent,
    });
  }

  MessagesCompanion copyWith(
      {Value<int>? id,
      Value<int>? chatId,
      Value<String>? rawText,
      Value<MessageRole>? role,
      Value<DateTime>? timestamp,
      Value<String?>? originalXmlContent,
      Value<String?>? secondaryXmlContent}) {
    return MessagesCompanion(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      rawText: rawText ?? this.rawText,
      role: role ?? this.role,
      timestamp: timestamp ?? this.timestamp,
      originalXmlContent: originalXmlContent ?? this.originalXmlContent,
      secondaryXmlContent: secondaryXmlContent ?? this.secondaryXmlContent,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (chatId.present) {
      map['chat_id'] = Variable<int>(chatId.value);
    }
    if (rawText.present) {
      map['raw_text'] = Variable<String>(rawText.value);
    }
    if (role.present) {
      map['role'] =
          Variable<String>($MessagesTable.$converterrole.toSql(role.value));
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (originalXmlContent.present) {
      map['original_xml_content'] = Variable<String>(originalXmlContent.value);
    }
    if (secondaryXmlContent.present) {
      map['secondary_xml_content'] =
          Variable<String>(secondaryXmlContent.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('chatId: $chatId, ')
          ..write('rawText: $rawText, ')
          ..write('role: $role, ')
          ..write('timestamp: $timestamp, ')
          ..write('originalXmlContent: $originalXmlContent, ')
          ..write('secondaryXmlContent: $secondaryXmlContent')
          ..write(')'))
        .toString();
  }
}

class $ApiConfigsTable extends ApiConfigs
    with TableInfo<$ApiConfigsTable, ApiConfig> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ApiConfigsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
      'user_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      clientDefault: () => 'temp_id');
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<LlmType, String> apiType =
      GeneratedColumn<String>('api_type', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<LlmType>($ApiConfigsTable.$converterapiType);
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
      'model', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _apiKeyMeta = const VerificationMeta('apiKey');
  @override
  late final GeneratedColumn<String> apiKey = GeneratedColumn<String>(
      'api_key', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _baseUrlMeta =
      const VerificationMeta('baseUrl');
  @override
  late final GeneratedColumn<String> baseUrl = GeneratedColumn<String>(
      'base_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _useCustomTemperatureMeta =
      const VerificationMeta('useCustomTemperature');
  @override
  late final GeneratedColumn<bool> useCustomTemperature = GeneratedColumn<bool>(
      'use_custom_temperature', aliasedName, true,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("use_custom_temperature" IN (0, 1))'));
  static const VerificationMeta _temperatureMeta =
      const VerificationMeta('temperature');
  @override
  late final GeneratedColumn<double> temperature = GeneratedColumn<double>(
      'temperature', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _useCustomTopPMeta =
      const VerificationMeta('useCustomTopP');
  @override
  late final GeneratedColumn<bool> useCustomTopP = GeneratedColumn<bool>(
      'use_custom_top_p', aliasedName, true,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("use_custom_top_p" IN (0, 1))'));
  static const VerificationMeta _topPMeta = const VerificationMeta('topP');
  @override
  late final GeneratedColumn<double> topP = GeneratedColumn<double>(
      'top_p', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _useCustomTopKMeta =
      const VerificationMeta('useCustomTopK');
  @override
  late final GeneratedColumn<bool> useCustomTopK = GeneratedColumn<bool>(
      'use_custom_top_k', aliasedName, true,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("use_custom_top_k" IN (0, 1))'));
  static const VerificationMeta _topKMeta = const VerificationMeta('topK');
  @override
  late final GeneratedColumn<int> topK = GeneratedColumn<int>(
      'top_k', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _maxOutputTokensMeta =
      const VerificationMeta('maxOutputTokens');
  @override
  late final GeneratedColumn<int> maxOutputTokens = GeneratedColumn<int>(
      'max_output_tokens', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>?, String>
      stopSequences = GeneratedColumn<String>(
              'stop_sequences', aliasedName, true,
              type: DriftSqlType.string, requiredDuringInsert: false)
          .withConverter<List<String>?>(
              $ApiConfigsTable.$converterstopSequencesn);
  static const VerificationMeta _enableReasoningEffortMeta =
      const VerificationMeta('enableReasoningEffort');
  @override
  late final GeneratedColumn<bool> enableReasoningEffort =
      GeneratedColumn<bool>('enable_reasoning_effort', aliasedName, true,
          type: DriftSqlType.bool,
          requiredDuringInsert: false,
          defaultConstraints: GeneratedColumn.constraintIsAlways(
              'CHECK ("enable_reasoning_effort" IN (0, 1))'));
  @override
  late final GeneratedColumnWithTypeConverter<OpenAIReasoningEffort?, String>
      reasoningEffort = GeneratedColumn<String>(
              'reasoning_effort', aliasedName, true,
              type: DriftSqlType.string, requiredDuringInsert: false)
          .withConverter<OpenAIReasoningEffort?>(
              $ApiConfigsTable.$converterreasoningEffort);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      clientDefault: () => DateTime.now());
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        userId,
        id,
        name,
        apiType,
        model,
        apiKey,
        baseUrl,
        useCustomTemperature,
        temperature,
        useCustomTopP,
        topP,
        useCustomTopK,
        topK,
        maxOutputTokens,
        stopSequences,
        enableReasoningEffort,
        reasoningEffort,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'api_configs';
  @override
  VerificationContext validateIntegrity(Insertable<ApiConfig> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
          _modelMeta, model.isAcceptableOrUnknown(data['model']!, _modelMeta));
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('api_key')) {
      context.handle(_apiKeyMeta,
          apiKey.isAcceptableOrUnknown(data['api_key']!, _apiKeyMeta));
    }
    if (data.containsKey('base_url')) {
      context.handle(_baseUrlMeta,
          baseUrl.isAcceptableOrUnknown(data['base_url']!, _baseUrlMeta));
    }
    if (data.containsKey('use_custom_temperature')) {
      context.handle(
          _useCustomTemperatureMeta,
          useCustomTemperature.isAcceptableOrUnknown(
              data['use_custom_temperature']!, _useCustomTemperatureMeta));
    }
    if (data.containsKey('temperature')) {
      context.handle(
          _temperatureMeta,
          temperature.isAcceptableOrUnknown(
              data['temperature']!, _temperatureMeta));
    }
    if (data.containsKey('use_custom_top_p')) {
      context.handle(
          _useCustomTopPMeta,
          useCustomTopP.isAcceptableOrUnknown(
              data['use_custom_top_p']!, _useCustomTopPMeta));
    }
    if (data.containsKey('top_p')) {
      context.handle(
          _topPMeta, topP.isAcceptableOrUnknown(data['top_p']!, _topPMeta));
    }
    if (data.containsKey('use_custom_top_k')) {
      context.handle(
          _useCustomTopKMeta,
          useCustomTopK.isAcceptableOrUnknown(
              data['use_custom_top_k']!, _useCustomTopKMeta));
    }
    if (data.containsKey('top_k')) {
      context.handle(
          _topKMeta, topK.isAcceptableOrUnknown(data['top_k']!, _topKMeta));
    }
    if (data.containsKey('max_output_tokens')) {
      context.handle(
          _maxOutputTokensMeta,
          maxOutputTokens.isAcceptableOrUnknown(
              data['max_output_tokens']!, _maxOutputTokensMeta));
    }
    if (data.containsKey('enable_reasoning_effort')) {
      context.handle(
          _enableReasoningEffortMeta,
          enableReasoningEffort.isAcceptableOrUnknown(
              data['enable_reasoning_effort']!, _enableReasoningEffortMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ApiConfig map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ApiConfig(
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}user_id']),
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      apiType: $ApiConfigsTable.$converterapiType.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}api_type'])!),
      model: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}model'])!,
      apiKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}api_key']),
      baseUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}base_url']),
      useCustomTemperature: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}use_custom_temperature']),
      temperature: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}temperature']),
      useCustomTopP: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}use_custom_top_p']),
      topP: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}top_p']),
      useCustomTopK: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}use_custom_top_k']),
      topK: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}top_k']),
      maxOutputTokens: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}max_output_tokens']),
      stopSequences: $ApiConfigsTable.$converterstopSequencesn.fromSql(
          attachedDatabase.typeMapping.read(
              DriftSqlType.string, data['${effectivePrefix}stop_sequences'])),
      enableReasoningEffort: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}enable_reasoning_effort']),
      reasoningEffort: $ApiConfigsTable.$converterreasoningEffort.fromSql(
          attachedDatabase.typeMapping.read(
              DriftSqlType.string, data['${effectivePrefix}reasoning_effort'])),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $ApiConfigsTable createAlias(String alias) {
    return $ApiConfigsTable(attachedDatabase, alias);
  }

  static TypeConverter<LlmType, String> $converterapiType =
      const LlmTypeConverter();
  static TypeConverter<List<String>, String> $converterstopSequences =
      const StringListConverter();
  static TypeConverter<List<String>?, String?> $converterstopSequencesn =
      NullAwareTypeConverter.wrap($converterstopSequences);
  static TypeConverter<OpenAIReasoningEffort?, String?>
      $converterreasoningEffort = const OpenAIReasoningEffortConverter();
}

class ApiConfig extends DataClass implements Insertable<ApiConfig> {
  final int? userId;
  final String id;
  final String name;
  final LlmType apiType;
  final String model;
  final String? apiKey;
  final String? baseUrl;
  final bool? useCustomTemperature;
  final double? temperature;
  final bool? useCustomTopP;
  final double? topP;
  final bool? useCustomTopK;
  final int? topK;
  final int? maxOutputTokens;
  final List<String>? stopSequences;
  final bool? enableReasoningEffort;
  final OpenAIReasoningEffort? reasoningEffort;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ApiConfig(
      {this.userId,
      required this.id,
      required this.name,
      required this.apiType,
      required this.model,
      this.apiKey,
      this.baseUrl,
      this.useCustomTemperature,
      this.temperature,
      this.useCustomTopP,
      this.topP,
      this.useCustomTopK,
      this.topK,
      this.maxOutputTokens,
      this.stopSequences,
      this.enableReasoningEffort,
      this.reasoningEffort,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<int>(userId);
    }
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    {
      map['api_type'] =
          Variable<String>($ApiConfigsTable.$converterapiType.toSql(apiType));
    }
    map['model'] = Variable<String>(model);
    if (!nullToAbsent || apiKey != null) {
      map['api_key'] = Variable<String>(apiKey);
    }
    if (!nullToAbsent || baseUrl != null) {
      map['base_url'] = Variable<String>(baseUrl);
    }
    if (!nullToAbsent || useCustomTemperature != null) {
      map['use_custom_temperature'] = Variable<bool>(useCustomTemperature);
    }
    if (!nullToAbsent || temperature != null) {
      map['temperature'] = Variable<double>(temperature);
    }
    if (!nullToAbsent || useCustomTopP != null) {
      map['use_custom_top_p'] = Variable<bool>(useCustomTopP);
    }
    if (!nullToAbsent || topP != null) {
      map['top_p'] = Variable<double>(topP);
    }
    if (!nullToAbsent || useCustomTopK != null) {
      map['use_custom_top_k'] = Variable<bool>(useCustomTopK);
    }
    if (!nullToAbsent || topK != null) {
      map['top_k'] = Variable<int>(topK);
    }
    if (!nullToAbsent || maxOutputTokens != null) {
      map['max_output_tokens'] = Variable<int>(maxOutputTokens);
    }
    if (!nullToAbsent || stopSequences != null) {
      map['stop_sequences'] = Variable<String>(
          $ApiConfigsTable.$converterstopSequencesn.toSql(stopSequences));
    }
    if (!nullToAbsent || enableReasoningEffort != null) {
      map['enable_reasoning_effort'] = Variable<bool>(enableReasoningEffort);
    }
    if (!nullToAbsent || reasoningEffort != null) {
      map['reasoning_effort'] = Variable<String>(
          $ApiConfigsTable.$converterreasoningEffort.toSql(reasoningEffort));
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ApiConfigsCompanion toCompanion(bool nullToAbsent) {
    return ApiConfigsCompanion(
      userId:
          userId == null && nullToAbsent ? const Value.absent() : Value(userId),
      id: Value(id),
      name: Value(name),
      apiType: Value(apiType),
      model: Value(model),
      apiKey:
          apiKey == null && nullToAbsent ? const Value.absent() : Value(apiKey),
      baseUrl: baseUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(baseUrl),
      useCustomTemperature: useCustomTemperature == null && nullToAbsent
          ? const Value.absent()
          : Value(useCustomTemperature),
      temperature: temperature == null && nullToAbsent
          ? const Value.absent()
          : Value(temperature),
      useCustomTopP: useCustomTopP == null && nullToAbsent
          ? const Value.absent()
          : Value(useCustomTopP),
      topP: topP == null && nullToAbsent ? const Value.absent() : Value(topP),
      useCustomTopK: useCustomTopK == null && nullToAbsent
          ? const Value.absent()
          : Value(useCustomTopK),
      topK: topK == null && nullToAbsent ? const Value.absent() : Value(topK),
      maxOutputTokens: maxOutputTokens == null && nullToAbsent
          ? const Value.absent()
          : Value(maxOutputTokens),
      stopSequences: stopSequences == null && nullToAbsent
          ? const Value.absent()
          : Value(stopSequences),
      enableReasoningEffort: enableReasoningEffort == null && nullToAbsent
          ? const Value.absent()
          : Value(enableReasoningEffort),
      reasoningEffort: reasoningEffort == null && nullToAbsent
          ? const Value.absent()
          : Value(reasoningEffort),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ApiConfig.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ApiConfig(
      userId: serializer.fromJson<int?>(json['userId']),
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      apiType: serializer.fromJson<LlmType>(json['apiType']),
      model: serializer.fromJson<String>(json['model']),
      apiKey: serializer.fromJson<String?>(json['apiKey']),
      baseUrl: serializer.fromJson<String?>(json['baseUrl']),
      useCustomTemperature:
          serializer.fromJson<bool?>(json['useCustomTemperature']),
      temperature: serializer.fromJson<double?>(json['temperature']),
      useCustomTopP: serializer.fromJson<bool?>(json['useCustomTopP']),
      topP: serializer.fromJson<double?>(json['topP']),
      useCustomTopK: serializer.fromJson<bool?>(json['useCustomTopK']),
      topK: serializer.fromJson<int?>(json['topK']),
      maxOutputTokens: serializer.fromJson<int?>(json['maxOutputTokens']),
      stopSequences: serializer.fromJson<List<String>?>(json['stopSequences']),
      enableReasoningEffort:
          serializer.fromJson<bool?>(json['enableReasoningEffort']),
      reasoningEffort:
          serializer.fromJson<OpenAIReasoningEffort?>(json['reasoningEffort']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<int?>(userId),
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'apiType': serializer.toJson<LlmType>(apiType),
      'model': serializer.toJson<String>(model),
      'apiKey': serializer.toJson<String?>(apiKey),
      'baseUrl': serializer.toJson<String?>(baseUrl),
      'useCustomTemperature': serializer.toJson<bool?>(useCustomTemperature),
      'temperature': serializer.toJson<double?>(temperature),
      'useCustomTopP': serializer.toJson<bool?>(useCustomTopP),
      'topP': serializer.toJson<double?>(topP),
      'useCustomTopK': serializer.toJson<bool?>(useCustomTopK),
      'topK': serializer.toJson<int?>(topK),
      'maxOutputTokens': serializer.toJson<int?>(maxOutputTokens),
      'stopSequences': serializer.toJson<List<String>?>(stopSequences),
      'enableReasoningEffort': serializer.toJson<bool?>(enableReasoningEffort),
      'reasoningEffort':
          serializer.toJson<OpenAIReasoningEffort?>(reasoningEffort),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ApiConfig copyWith(
          {Value<int?> userId = const Value.absent(),
          String? id,
          String? name,
          LlmType? apiType,
          String? model,
          Value<String?> apiKey = const Value.absent(),
          Value<String?> baseUrl = const Value.absent(),
          Value<bool?> useCustomTemperature = const Value.absent(),
          Value<double?> temperature = const Value.absent(),
          Value<bool?> useCustomTopP = const Value.absent(),
          Value<double?> topP = const Value.absent(),
          Value<bool?> useCustomTopK = const Value.absent(),
          Value<int?> topK = const Value.absent(),
          Value<int?> maxOutputTokens = const Value.absent(),
          Value<List<String>?> stopSequences = const Value.absent(),
          Value<bool?> enableReasoningEffort = const Value.absent(),
          Value<OpenAIReasoningEffort?> reasoningEffort = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      ApiConfig(
        userId: userId.present ? userId.value : this.userId,
        id: id ?? this.id,
        name: name ?? this.name,
        apiType: apiType ?? this.apiType,
        model: model ?? this.model,
        apiKey: apiKey.present ? apiKey.value : this.apiKey,
        baseUrl: baseUrl.present ? baseUrl.value : this.baseUrl,
        useCustomTemperature: useCustomTemperature.present
            ? useCustomTemperature.value
            : this.useCustomTemperature,
        temperature: temperature.present ? temperature.value : this.temperature,
        useCustomTopP:
            useCustomTopP.present ? useCustomTopP.value : this.useCustomTopP,
        topP: topP.present ? topP.value : this.topP,
        useCustomTopK:
            useCustomTopK.present ? useCustomTopK.value : this.useCustomTopK,
        topK: topK.present ? topK.value : this.topK,
        maxOutputTokens: maxOutputTokens.present
            ? maxOutputTokens.value
            : this.maxOutputTokens,
        stopSequences:
            stopSequences.present ? stopSequences.value : this.stopSequences,
        enableReasoningEffort: enableReasoningEffort.present
            ? enableReasoningEffort.value
            : this.enableReasoningEffort,
        reasoningEffort: reasoningEffort.present
            ? reasoningEffort.value
            : this.reasoningEffort,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  ApiConfig copyWithCompanion(ApiConfigsCompanion data) {
    return ApiConfig(
      userId: data.userId.present ? data.userId.value : this.userId,
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      apiType: data.apiType.present ? data.apiType.value : this.apiType,
      model: data.model.present ? data.model.value : this.model,
      apiKey: data.apiKey.present ? data.apiKey.value : this.apiKey,
      baseUrl: data.baseUrl.present ? data.baseUrl.value : this.baseUrl,
      useCustomTemperature: data.useCustomTemperature.present
          ? data.useCustomTemperature.value
          : this.useCustomTemperature,
      temperature:
          data.temperature.present ? data.temperature.value : this.temperature,
      useCustomTopP: data.useCustomTopP.present
          ? data.useCustomTopP.value
          : this.useCustomTopP,
      topP: data.topP.present ? data.topP.value : this.topP,
      useCustomTopK: data.useCustomTopK.present
          ? data.useCustomTopK.value
          : this.useCustomTopK,
      topK: data.topK.present ? data.topK.value : this.topK,
      maxOutputTokens: data.maxOutputTokens.present
          ? data.maxOutputTokens.value
          : this.maxOutputTokens,
      stopSequences: data.stopSequences.present
          ? data.stopSequences.value
          : this.stopSequences,
      enableReasoningEffort: data.enableReasoningEffort.present
          ? data.enableReasoningEffort.value
          : this.enableReasoningEffort,
      reasoningEffort: data.reasoningEffort.present
          ? data.reasoningEffort.value
          : this.reasoningEffort,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ApiConfig(')
          ..write('userId: $userId, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('apiType: $apiType, ')
          ..write('model: $model, ')
          ..write('apiKey: $apiKey, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('useCustomTemperature: $useCustomTemperature, ')
          ..write('temperature: $temperature, ')
          ..write('useCustomTopP: $useCustomTopP, ')
          ..write('topP: $topP, ')
          ..write('useCustomTopK: $useCustomTopK, ')
          ..write('topK: $topK, ')
          ..write('maxOutputTokens: $maxOutputTokens, ')
          ..write('stopSequences: $stopSequences, ')
          ..write('enableReasoningEffort: $enableReasoningEffort, ')
          ..write('reasoningEffort: $reasoningEffort, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      userId,
      id,
      name,
      apiType,
      model,
      apiKey,
      baseUrl,
      useCustomTemperature,
      temperature,
      useCustomTopP,
      topP,
      useCustomTopK,
      topK,
      maxOutputTokens,
      stopSequences,
      enableReasoningEffort,
      reasoningEffort,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ApiConfig &&
          other.userId == this.userId &&
          other.id == this.id &&
          other.name == this.name &&
          other.apiType == this.apiType &&
          other.model == this.model &&
          other.apiKey == this.apiKey &&
          other.baseUrl == this.baseUrl &&
          other.useCustomTemperature == this.useCustomTemperature &&
          other.temperature == this.temperature &&
          other.useCustomTopP == this.useCustomTopP &&
          other.topP == this.topP &&
          other.useCustomTopK == this.useCustomTopK &&
          other.topK == this.topK &&
          other.maxOutputTokens == this.maxOutputTokens &&
          other.stopSequences == this.stopSequences &&
          other.enableReasoningEffort == this.enableReasoningEffort &&
          other.reasoningEffort == this.reasoningEffort &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ApiConfigsCompanion extends UpdateCompanion<ApiConfig> {
  final Value<int?> userId;
  final Value<String> id;
  final Value<String> name;
  final Value<LlmType> apiType;
  final Value<String> model;
  final Value<String?> apiKey;
  final Value<String?> baseUrl;
  final Value<bool?> useCustomTemperature;
  final Value<double?> temperature;
  final Value<bool?> useCustomTopP;
  final Value<double?> topP;
  final Value<bool?> useCustomTopK;
  final Value<int?> topK;
  final Value<int?> maxOutputTokens;
  final Value<List<String>?> stopSequences;
  final Value<bool?> enableReasoningEffort;
  final Value<OpenAIReasoningEffort?> reasoningEffort;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ApiConfigsCompanion({
    this.userId = const Value.absent(),
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.apiType = const Value.absent(),
    this.model = const Value.absent(),
    this.apiKey = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.useCustomTemperature = const Value.absent(),
    this.temperature = const Value.absent(),
    this.useCustomTopP = const Value.absent(),
    this.topP = const Value.absent(),
    this.useCustomTopK = const Value.absent(),
    this.topK = const Value.absent(),
    this.maxOutputTokens = const Value.absent(),
    this.stopSequences = const Value.absent(),
    this.enableReasoningEffort = const Value.absent(),
    this.reasoningEffort = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ApiConfigsCompanion.insert({
    this.userId = const Value.absent(),
    this.id = const Value.absent(),
    required String name,
    required LlmType apiType,
    required String model,
    this.apiKey = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.useCustomTemperature = const Value.absent(),
    this.temperature = const Value.absent(),
    this.useCustomTopP = const Value.absent(),
    this.topP = const Value.absent(),
    this.useCustomTopK = const Value.absent(),
    this.topK = const Value.absent(),
    this.maxOutputTokens = const Value.absent(),
    this.stopSequences = const Value.absent(),
    this.enableReasoningEffort = const Value.absent(),
    this.reasoningEffort = const Value.absent(),
    this.createdAt = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : name = Value(name),
        apiType = Value(apiType),
        model = Value(model),
        updatedAt = Value(updatedAt);
  static Insertable<ApiConfig> custom({
    Expression<int>? userId,
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? apiType,
    Expression<String>? model,
    Expression<String>? apiKey,
    Expression<String>? baseUrl,
    Expression<bool>? useCustomTemperature,
    Expression<double>? temperature,
    Expression<bool>? useCustomTopP,
    Expression<double>? topP,
    Expression<bool>? useCustomTopK,
    Expression<int>? topK,
    Expression<int>? maxOutputTokens,
    Expression<String>? stopSequences,
    Expression<bool>? enableReasoningEffort,
    Expression<String>? reasoningEffort,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (apiType != null) 'api_type': apiType,
      if (model != null) 'model': model,
      if (apiKey != null) 'api_key': apiKey,
      if (baseUrl != null) 'base_url': baseUrl,
      if (useCustomTemperature != null)
        'use_custom_temperature': useCustomTemperature,
      if (temperature != null) 'temperature': temperature,
      if (useCustomTopP != null) 'use_custom_top_p': useCustomTopP,
      if (topP != null) 'top_p': topP,
      if (useCustomTopK != null) 'use_custom_top_k': useCustomTopK,
      if (topK != null) 'top_k': topK,
      if (maxOutputTokens != null) 'max_output_tokens': maxOutputTokens,
      if (stopSequences != null) 'stop_sequences': stopSequences,
      if (enableReasoningEffort != null)
        'enable_reasoning_effort': enableReasoningEffort,
      if (reasoningEffort != null) 'reasoning_effort': reasoningEffort,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ApiConfigsCompanion copyWith(
      {Value<int?>? userId,
      Value<String>? id,
      Value<String>? name,
      Value<LlmType>? apiType,
      Value<String>? model,
      Value<String?>? apiKey,
      Value<String?>? baseUrl,
      Value<bool?>? useCustomTemperature,
      Value<double?>? temperature,
      Value<bool?>? useCustomTopP,
      Value<double?>? topP,
      Value<bool?>? useCustomTopK,
      Value<int?>? topK,
      Value<int?>? maxOutputTokens,
      Value<List<String>?>? stopSequences,
      Value<bool?>? enableReasoningEffort,
      Value<OpenAIReasoningEffort?>? reasoningEffort,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return ApiConfigsCompanion(
      userId: userId ?? this.userId,
      id: id ?? this.id,
      name: name ?? this.name,
      apiType: apiType ?? this.apiType,
      model: model ?? this.model,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      useCustomTemperature: useCustomTemperature ?? this.useCustomTemperature,
      temperature: temperature ?? this.temperature,
      useCustomTopP: useCustomTopP ?? this.useCustomTopP,
      topP: topP ?? this.topP,
      useCustomTopK: useCustomTopK ?? this.useCustomTopK,
      topK: topK ?? this.topK,
      maxOutputTokens: maxOutputTokens ?? this.maxOutputTokens,
      stopSequences: stopSequences ?? this.stopSequences,
      enableReasoningEffort:
          enableReasoningEffort ?? this.enableReasoningEffort,
      reasoningEffort: reasoningEffort ?? this.reasoningEffort,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<int>(userId.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (apiType.present) {
      map['api_type'] = Variable<String>(
          $ApiConfigsTable.$converterapiType.toSql(apiType.value));
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (apiKey.present) {
      map['api_key'] = Variable<String>(apiKey.value);
    }
    if (baseUrl.present) {
      map['base_url'] = Variable<String>(baseUrl.value);
    }
    if (useCustomTemperature.present) {
      map['use_custom_temperature'] =
          Variable<bool>(useCustomTemperature.value);
    }
    if (temperature.present) {
      map['temperature'] = Variable<double>(temperature.value);
    }
    if (useCustomTopP.present) {
      map['use_custom_top_p'] = Variable<bool>(useCustomTopP.value);
    }
    if (topP.present) {
      map['top_p'] = Variable<double>(topP.value);
    }
    if (useCustomTopK.present) {
      map['use_custom_top_k'] = Variable<bool>(useCustomTopK.value);
    }
    if (topK.present) {
      map['top_k'] = Variable<int>(topK.value);
    }
    if (maxOutputTokens.present) {
      map['max_output_tokens'] = Variable<int>(maxOutputTokens.value);
    }
    if (stopSequences.present) {
      map['stop_sequences'] = Variable<String>(
          $ApiConfigsTable.$converterstopSequencesn.toSql(stopSequences.value));
    }
    if (enableReasoningEffort.present) {
      map['enable_reasoning_effort'] =
          Variable<bool>(enableReasoningEffort.value);
    }
    if (reasoningEffort.present) {
      map['reasoning_effort'] = Variable<String>($ApiConfigsTable
          .$converterreasoningEffort
          .toSql(reasoningEffort.value));
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ApiConfigsCompanion(')
          ..write('userId: $userId, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('apiType: $apiType, ')
          ..write('model: $model, ')
          ..write('apiKey: $apiKey, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('useCustomTemperature: $useCustomTemperature, ')
          ..write('temperature: $temperature, ')
          ..write('useCustomTopP: $useCustomTopP, ')
          ..write('topP: $topP, ')
          ..write('useCustomTopK: $useCustomTopK, ')
          ..write('topK: $topK, ')
          ..write('maxOutputTokens: $maxOutputTokens, ')
          ..write('stopSequences: $stopSequences, ')
          ..write('enableReasoningEffort: $enableReasoningEffort, ')
          ..write('reasoningEffort: $reasoningEffort, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UsersTable extends Users with TableInfo<$UsersTable, DriftUser> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
      'uuid', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      clientDefault: () => const Uuid().v4());
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      clientDefault: () => DateTime.now());
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _usernameMeta =
      const VerificationMeta('username');
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
      'username', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _passwordHashMeta =
      const VerificationMeta('passwordHash');
  @override
  late final GeneratedColumn<String> passwordHash = GeneratedColumn<String>(
      'password_hash', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<List<int>?, String> chatIds =
      GeneratedColumn<String>('chat_ids', aliasedName, true,
              type: DriftSqlType.string, requiredDuringInsert: false)
          .withConverter<List<int>?>($UsersTable.$converterchatIdsn);
  static const VerificationMeta _enableAutoTitleGenerationMeta =
      const VerificationMeta('enableAutoTitleGeneration');
  @override
  late final GeneratedColumn<bool> enableAutoTitleGeneration =
      GeneratedColumn<bool>('enable_auto_title_generation', aliasedName, true,
          type: DriftSqlType.bool,
          requiredDuringInsert: false,
          defaultConstraints: GeneratedColumn.constraintIsAlways(
              'CHECK ("enable_auto_title_generation" IN (0, 1))'));
  static const VerificationMeta _titleGenerationPromptMeta =
      const VerificationMeta('titleGenerationPrompt');
  @override
  late final GeneratedColumn<String> titleGenerationPrompt =
      GeneratedColumn<String>('title_generation_prompt', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _titleGenerationApiConfigIdMeta =
      const VerificationMeta('titleGenerationApiConfigId');
  @override
  late final GeneratedColumn<String> titleGenerationApiConfigId =
      GeneratedColumn<String>(
          'title_generation_api_config_id', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _enableResumeMeta =
      const VerificationMeta('enableResume');
  @override
  late final GeneratedColumn<bool> enableResume = GeneratedColumn<bool>(
      'enable_resume', aliasedName, true,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("enable_resume" IN (0, 1))'));
  static const VerificationMeta _resumePromptMeta =
      const VerificationMeta('resumePrompt');
  @override
  late final GeneratedColumn<String> resumePrompt = GeneratedColumn<String>(
      'resume_prompt', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _resumeApiConfigIdMeta =
      const VerificationMeta('resumeApiConfigId');
  @override
  late final GeneratedColumn<String> resumeApiConfigId =
      GeneratedColumn<String>('resume_api_config_id', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>?, String>
      geminiApiKeys = GeneratedColumn<String>(
              'gemini_api_keys', aliasedName, true,
              type: DriftSqlType.string, requiredDuringInsert: false)
          .withConverter<List<String>?>($UsersTable.$convertergeminiApiKeysn);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        uuid,
        createdAt,
        updatedAt,
        username,
        passwordHash,
        chatIds,
        enableAutoTitleGeneration,
        titleGenerationPrompt,
        titleGenerationApiConfigId,
        enableResume,
        resumePrompt,
        resumeApiConfigId,
        geminiApiKeys
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'users';
  @override
  VerificationContext validateIntegrity(Insertable<DriftUser> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
          _uuidMeta, uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('username')) {
      context.handle(_usernameMeta,
          username.isAcceptableOrUnknown(data['username']!, _usernameMeta));
    } else if (isInserting) {
      context.missing(_usernameMeta);
    }
    if (data.containsKey('password_hash')) {
      context.handle(
          _passwordHashMeta,
          passwordHash.isAcceptableOrUnknown(
              data['password_hash']!, _passwordHashMeta));
    } else if (isInserting) {
      context.missing(_passwordHashMeta);
    }
    if (data.containsKey('enable_auto_title_generation')) {
      context.handle(
          _enableAutoTitleGenerationMeta,
          enableAutoTitleGeneration.isAcceptableOrUnknown(
              data['enable_auto_title_generation']!,
              _enableAutoTitleGenerationMeta));
    }
    if (data.containsKey('title_generation_prompt')) {
      context.handle(
          _titleGenerationPromptMeta,
          titleGenerationPrompt.isAcceptableOrUnknown(
              data['title_generation_prompt']!, _titleGenerationPromptMeta));
    }
    if (data.containsKey('title_generation_api_config_id')) {
      context.handle(
          _titleGenerationApiConfigIdMeta,
          titleGenerationApiConfigId.isAcceptableOrUnknown(
              data['title_generation_api_config_id']!,
              _titleGenerationApiConfigIdMeta));
    }
    if (data.containsKey('enable_resume')) {
      context.handle(
          _enableResumeMeta,
          enableResume.isAcceptableOrUnknown(
              data['enable_resume']!, _enableResumeMeta));
    }
    if (data.containsKey('resume_prompt')) {
      context.handle(
          _resumePromptMeta,
          resumePrompt.isAcceptableOrUnknown(
              data['resume_prompt']!, _resumePromptMeta));
    }
    if (data.containsKey('resume_api_config_id')) {
      context.handle(
          _resumeApiConfigIdMeta,
          resumeApiConfigId.isAcceptableOrUnknown(
              data['resume_api_config_id']!, _resumeApiConfigIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DriftUser map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DriftUser(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      uuid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uuid'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      username: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}username'])!,
      passwordHash: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}password_hash'])!,
      chatIds: $UsersTable.$converterchatIdsn.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}chat_ids'])),
      enableAutoTitleGeneration: attachedDatabase.typeMapping.read(
          DriftSqlType.bool,
          data['${effectivePrefix}enable_auto_title_generation']),
      titleGenerationPrompt: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}title_generation_prompt']),
      titleGenerationApiConfigId: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}title_generation_api_config_id']),
      enableResume: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}enable_resume']),
      resumePrompt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}resume_prompt']),
      resumeApiConfigId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}resume_api_config_id']),
      geminiApiKeys: $UsersTable.$convertergeminiApiKeysn.fromSql(
          attachedDatabase.typeMapping.read(
              DriftSqlType.string, data['${effectivePrefix}gemini_api_keys'])),
    );
  }

  @override
  $UsersTable createAlias(String alias) {
    return $UsersTable(attachedDatabase, alias);
  }

  static TypeConverter<List<int>, String> $converterchatIds =
      const IntListConverter();
  static TypeConverter<List<int>?, String?> $converterchatIdsn =
      NullAwareTypeConverter.wrap($converterchatIds);
  static TypeConverter<List<String>, String> $convertergeminiApiKeys =
      const StringListConverter();
  static TypeConverter<List<String>?, String?> $convertergeminiApiKeysn =
      NullAwareTypeConverter.wrap($convertergeminiApiKeys);
}

class DriftUser extends DataClass implements Insertable<DriftUser> {
  /// 用户的唯一ID，自增主键。
  final int id;

  /// 用于数据同步的全局唯一标识符。
  final String uuid;

  /// 记录创建时间的时间戳。
  final DateTime createdAt;

  /// 记录最后更新时间的时间戳。
  final DateTime updatedAt;

  /// 用户名，必须是唯一的。
  final String username;

  /// 存储密码的哈希值。
  final String passwordHash;

  /// 存储用户拥有的聊天ID列表。
  /// 使用自定义的 TypeConverter 将 List<int> 转换为 String 进行存储。
  final List<int>? chatIds;

  /// 是否启用自动生成聊天标题。
  final bool? enableAutoTitleGeneration;

  /// 自动生成标题时使用的提示词。
  final String? titleGenerationPrompt;

  /// 自动生成标题时使用的 API 配置 ID。
  final String? titleGenerationApiConfigId;

  /// 是否启用中断恢复功能。
  final bool? enableResume;

  /// 中断恢复时使用的提示词。
  final String? resumePrompt;

  /// 中断恢复时使用的 API 配置 ID。
  final String? resumeApiConfigId;

  /// Gemini API 密钥列表
  final List<String>? geminiApiKeys;
  const DriftUser(
      {required this.id,
      required this.uuid,
      required this.createdAt,
      required this.updatedAt,
      required this.username,
      required this.passwordHash,
      this.chatIds,
      this.enableAutoTitleGeneration,
      this.titleGenerationPrompt,
      this.titleGenerationApiConfigId,
      this.enableResume,
      this.resumePrompt,
      this.resumeApiConfigId,
      this.geminiApiKeys});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['username'] = Variable<String>(username);
    map['password_hash'] = Variable<String>(passwordHash);
    if (!nullToAbsent || chatIds != null) {
      map['chat_ids'] =
          Variable<String>($UsersTable.$converterchatIdsn.toSql(chatIds));
    }
    if (!nullToAbsent || enableAutoTitleGeneration != null) {
      map['enable_auto_title_generation'] =
          Variable<bool>(enableAutoTitleGeneration);
    }
    if (!nullToAbsent || titleGenerationPrompt != null) {
      map['title_generation_prompt'] = Variable<String>(titleGenerationPrompt);
    }
    if (!nullToAbsent || titleGenerationApiConfigId != null) {
      map['title_generation_api_config_id'] =
          Variable<String>(titleGenerationApiConfigId);
    }
    if (!nullToAbsent || enableResume != null) {
      map['enable_resume'] = Variable<bool>(enableResume);
    }
    if (!nullToAbsent || resumePrompt != null) {
      map['resume_prompt'] = Variable<String>(resumePrompt);
    }
    if (!nullToAbsent || resumeApiConfigId != null) {
      map['resume_api_config_id'] = Variable<String>(resumeApiConfigId);
    }
    if (!nullToAbsent || geminiApiKeys != null) {
      map['gemini_api_keys'] = Variable<String>(
          $UsersTable.$convertergeminiApiKeysn.toSql(geminiApiKeys));
    }
    return map;
  }

  UsersCompanion toCompanion(bool nullToAbsent) {
    return UsersCompanion(
      id: Value(id),
      uuid: Value(uuid),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      username: Value(username),
      passwordHash: Value(passwordHash),
      chatIds: chatIds == null && nullToAbsent
          ? const Value.absent()
          : Value(chatIds),
      enableAutoTitleGeneration:
          enableAutoTitleGeneration == null && nullToAbsent
              ? const Value.absent()
              : Value(enableAutoTitleGeneration),
      titleGenerationPrompt: titleGenerationPrompt == null && nullToAbsent
          ? const Value.absent()
          : Value(titleGenerationPrompt),
      titleGenerationApiConfigId:
          titleGenerationApiConfigId == null && nullToAbsent
              ? const Value.absent()
              : Value(titleGenerationApiConfigId),
      enableResume: enableResume == null && nullToAbsent
          ? const Value.absent()
          : Value(enableResume),
      resumePrompt: resumePrompt == null && nullToAbsent
          ? const Value.absent()
          : Value(resumePrompt),
      resumeApiConfigId: resumeApiConfigId == null && nullToAbsent
          ? const Value.absent()
          : Value(resumeApiConfigId),
      geminiApiKeys: geminiApiKeys == null && nullToAbsent
          ? const Value.absent()
          : Value(geminiApiKeys),
    );
  }

  factory DriftUser.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DriftUser(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      username: serializer.fromJson<String>(json['username']),
      passwordHash: serializer.fromJson<String>(json['passwordHash']),
      chatIds: serializer.fromJson<List<int>?>(json['chatIds']),
      enableAutoTitleGeneration:
          serializer.fromJson<bool?>(json['enableAutoTitleGeneration']),
      titleGenerationPrompt:
          serializer.fromJson<String?>(json['titleGenerationPrompt']),
      titleGenerationApiConfigId:
          serializer.fromJson<String?>(json['titleGenerationApiConfigId']),
      enableResume: serializer.fromJson<bool?>(json['enableResume']),
      resumePrompt: serializer.fromJson<String?>(json['resumePrompt']),
      resumeApiConfigId:
          serializer.fromJson<String?>(json['resumeApiConfigId']),
      geminiApiKeys: serializer.fromJson<List<String>?>(json['geminiApiKeys']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'username': serializer.toJson<String>(username),
      'passwordHash': serializer.toJson<String>(passwordHash),
      'chatIds': serializer.toJson<List<int>?>(chatIds),
      'enableAutoTitleGeneration':
          serializer.toJson<bool?>(enableAutoTitleGeneration),
      'titleGenerationPrompt':
          serializer.toJson<String?>(titleGenerationPrompt),
      'titleGenerationApiConfigId':
          serializer.toJson<String?>(titleGenerationApiConfigId),
      'enableResume': serializer.toJson<bool?>(enableResume),
      'resumePrompt': serializer.toJson<String?>(resumePrompt),
      'resumeApiConfigId': serializer.toJson<String?>(resumeApiConfigId),
      'geminiApiKeys': serializer.toJson<List<String>?>(geminiApiKeys),
    };
  }

  DriftUser copyWith(
          {int? id,
          String? uuid,
          DateTime? createdAt,
          DateTime? updatedAt,
          String? username,
          String? passwordHash,
          Value<List<int>?> chatIds = const Value.absent(),
          Value<bool?> enableAutoTitleGeneration = const Value.absent(),
          Value<String?> titleGenerationPrompt = const Value.absent(),
          Value<String?> titleGenerationApiConfigId = const Value.absent(),
          Value<bool?> enableResume = const Value.absent(),
          Value<String?> resumePrompt = const Value.absent(),
          Value<String?> resumeApiConfigId = const Value.absent(),
          Value<List<String>?> geminiApiKeys = const Value.absent()}) =>
      DriftUser(
        id: id ?? this.id,
        uuid: uuid ?? this.uuid,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        username: username ?? this.username,
        passwordHash: passwordHash ?? this.passwordHash,
        chatIds: chatIds.present ? chatIds.value : this.chatIds,
        enableAutoTitleGeneration: enableAutoTitleGeneration.present
            ? enableAutoTitleGeneration.value
            : this.enableAutoTitleGeneration,
        titleGenerationPrompt: titleGenerationPrompt.present
            ? titleGenerationPrompt.value
            : this.titleGenerationPrompt,
        titleGenerationApiConfigId: titleGenerationApiConfigId.present
            ? titleGenerationApiConfigId.value
            : this.titleGenerationApiConfigId,
        enableResume:
            enableResume.present ? enableResume.value : this.enableResume,
        resumePrompt:
            resumePrompt.present ? resumePrompt.value : this.resumePrompt,
        resumeApiConfigId: resumeApiConfigId.present
            ? resumeApiConfigId.value
            : this.resumeApiConfigId,
        geminiApiKeys:
            geminiApiKeys.present ? geminiApiKeys.value : this.geminiApiKeys,
      );
  DriftUser copyWithCompanion(UsersCompanion data) {
    return DriftUser(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      username: data.username.present ? data.username.value : this.username,
      passwordHash: data.passwordHash.present
          ? data.passwordHash.value
          : this.passwordHash,
      chatIds: data.chatIds.present ? data.chatIds.value : this.chatIds,
      enableAutoTitleGeneration: data.enableAutoTitleGeneration.present
          ? data.enableAutoTitleGeneration.value
          : this.enableAutoTitleGeneration,
      titleGenerationPrompt: data.titleGenerationPrompt.present
          ? data.titleGenerationPrompt.value
          : this.titleGenerationPrompt,
      titleGenerationApiConfigId: data.titleGenerationApiConfigId.present
          ? data.titleGenerationApiConfigId.value
          : this.titleGenerationApiConfigId,
      enableResume: data.enableResume.present
          ? data.enableResume.value
          : this.enableResume,
      resumePrompt: data.resumePrompt.present
          ? data.resumePrompt.value
          : this.resumePrompt,
      resumeApiConfigId: data.resumeApiConfigId.present
          ? data.resumeApiConfigId.value
          : this.resumeApiConfigId,
      geminiApiKeys: data.geminiApiKeys.present
          ? data.geminiApiKeys.value
          : this.geminiApiKeys,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DriftUser(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('username: $username, ')
          ..write('passwordHash: $passwordHash, ')
          ..write('chatIds: $chatIds, ')
          ..write('enableAutoTitleGeneration: $enableAutoTitleGeneration, ')
          ..write('titleGenerationPrompt: $titleGenerationPrompt, ')
          ..write('titleGenerationApiConfigId: $titleGenerationApiConfigId, ')
          ..write('enableResume: $enableResume, ')
          ..write('resumePrompt: $resumePrompt, ')
          ..write('resumeApiConfigId: $resumeApiConfigId, ')
          ..write('geminiApiKeys: $geminiApiKeys')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      uuid,
      createdAt,
      updatedAt,
      username,
      passwordHash,
      chatIds,
      enableAutoTitleGeneration,
      titleGenerationPrompt,
      titleGenerationApiConfigId,
      enableResume,
      resumePrompt,
      resumeApiConfigId,
      geminiApiKeys);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DriftUser &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.username == this.username &&
          other.passwordHash == this.passwordHash &&
          other.chatIds == this.chatIds &&
          other.enableAutoTitleGeneration == this.enableAutoTitleGeneration &&
          other.titleGenerationPrompt == this.titleGenerationPrompt &&
          other.titleGenerationApiConfigId == this.titleGenerationApiConfigId &&
          other.enableResume == this.enableResume &&
          other.resumePrompt == this.resumePrompt &&
          other.resumeApiConfigId == this.resumeApiConfigId &&
          other.geminiApiKeys == this.geminiApiKeys);
}

class UsersCompanion extends UpdateCompanion<DriftUser> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String> username;
  final Value<String> passwordHash;
  final Value<List<int>?> chatIds;
  final Value<bool?> enableAutoTitleGeneration;
  final Value<String?> titleGenerationPrompt;
  final Value<String?> titleGenerationApiConfigId;
  final Value<bool?> enableResume;
  final Value<String?> resumePrompt;
  final Value<String?> resumeApiConfigId;
  final Value<List<String>?> geminiApiKeys;
  const UsersCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.username = const Value.absent(),
    this.passwordHash = const Value.absent(),
    this.chatIds = const Value.absent(),
    this.enableAutoTitleGeneration = const Value.absent(),
    this.titleGenerationPrompt = const Value.absent(),
    this.titleGenerationApiConfigId = const Value.absent(),
    this.enableResume = const Value.absent(),
    this.resumePrompt = const Value.absent(),
    this.resumeApiConfigId = const Value.absent(),
    this.geminiApiKeys = const Value.absent(),
  });
  UsersCompanion.insert({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.createdAt = const Value.absent(),
    required DateTime updatedAt,
    required String username,
    required String passwordHash,
    this.chatIds = const Value.absent(),
    this.enableAutoTitleGeneration = const Value.absent(),
    this.titleGenerationPrompt = const Value.absent(),
    this.titleGenerationApiConfigId = const Value.absent(),
    this.enableResume = const Value.absent(),
    this.resumePrompt = const Value.absent(),
    this.resumeApiConfigId = const Value.absent(),
    this.geminiApiKeys = const Value.absent(),
  })  : updatedAt = Value(updatedAt),
        username = Value(username),
        passwordHash = Value(passwordHash);
  static Insertable<DriftUser> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? username,
    Expression<String>? passwordHash,
    Expression<String>? chatIds,
    Expression<bool>? enableAutoTitleGeneration,
    Expression<String>? titleGenerationPrompt,
    Expression<String>? titleGenerationApiConfigId,
    Expression<bool>? enableResume,
    Expression<String>? resumePrompt,
    Expression<String>? resumeApiConfigId,
    Expression<String>? geminiApiKeys,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (username != null) 'username': username,
      if (passwordHash != null) 'password_hash': passwordHash,
      if (chatIds != null) 'chat_ids': chatIds,
      if (enableAutoTitleGeneration != null)
        'enable_auto_title_generation': enableAutoTitleGeneration,
      if (titleGenerationPrompt != null)
        'title_generation_prompt': titleGenerationPrompt,
      if (titleGenerationApiConfigId != null)
        'title_generation_api_config_id': titleGenerationApiConfigId,
      if (enableResume != null) 'enable_resume': enableResume,
      if (resumePrompt != null) 'resume_prompt': resumePrompt,
      if (resumeApiConfigId != null) 'resume_api_config_id': resumeApiConfigId,
      if (geminiApiKeys != null) 'gemini_api_keys': geminiApiKeys,
    });
  }

  UsersCompanion copyWith(
      {Value<int>? id,
      Value<String>? uuid,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<String>? username,
      Value<String>? passwordHash,
      Value<List<int>?>? chatIds,
      Value<bool?>? enableAutoTitleGeneration,
      Value<String?>? titleGenerationPrompt,
      Value<String?>? titleGenerationApiConfigId,
      Value<bool?>? enableResume,
      Value<String?>? resumePrompt,
      Value<String?>? resumeApiConfigId,
      Value<List<String>?>? geminiApiKeys}) {
    return UsersCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      chatIds: chatIds ?? this.chatIds,
      enableAutoTitleGeneration:
          enableAutoTitleGeneration ?? this.enableAutoTitleGeneration,
      titleGenerationPrompt:
          titleGenerationPrompt ?? this.titleGenerationPrompt,
      titleGenerationApiConfigId:
          titleGenerationApiConfigId ?? this.titleGenerationApiConfigId,
      enableResume: enableResume ?? this.enableResume,
      resumePrompt: resumePrompt ?? this.resumePrompt,
      resumeApiConfigId: resumeApiConfigId ?? this.resumeApiConfigId,
      geminiApiKeys: geminiApiKeys ?? this.geminiApiKeys,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (passwordHash.present) {
      map['password_hash'] = Variable<String>(passwordHash.value);
    }
    if (chatIds.present) {
      map['chat_ids'] =
          Variable<String>($UsersTable.$converterchatIdsn.toSql(chatIds.value));
    }
    if (enableAutoTitleGeneration.present) {
      map['enable_auto_title_generation'] =
          Variable<bool>(enableAutoTitleGeneration.value);
    }
    if (titleGenerationPrompt.present) {
      map['title_generation_prompt'] =
          Variable<String>(titleGenerationPrompt.value);
    }
    if (titleGenerationApiConfigId.present) {
      map['title_generation_api_config_id'] =
          Variable<String>(titleGenerationApiConfigId.value);
    }
    if (enableResume.present) {
      map['enable_resume'] = Variable<bool>(enableResume.value);
    }
    if (resumePrompt.present) {
      map['resume_prompt'] = Variable<String>(resumePrompt.value);
    }
    if (resumeApiConfigId.present) {
      map['resume_api_config_id'] = Variable<String>(resumeApiConfigId.value);
    }
    if (geminiApiKeys.present) {
      map['gemini_api_keys'] = Variable<String>(
          $UsersTable.$convertergeminiApiKeysn.toSql(geminiApiKeys.value));
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsersCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('username: $username, ')
          ..write('passwordHash: $passwordHash, ')
          ..write('chatIds: $chatIds, ')
          ..write('enableAutoTitleGeneration: $enableAutoTitleGeneration, ')
          ..write('titleGenerationPrompt: $titleGenerationPrompt, ')
          ..write('titleGenerationApiConfigId: $titleGenerationApiConfigId, ')
          ..write('enableResume: $enableResume, ')
          ..write('resumePrompt: $resumePrompt, ')
          ..write('resumeApiConfigId: $resumeApiConfigId, ')
          ..write('geminiApiKeys: $geminiApiKeys')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ChatsTable chats = $ChatsTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $ApiConfigsTable apiConfigs = $ApiConfigsTable(this);
  late final $UsersTable users = $UsersTable(this);
  late final ChatDao chatDao = ChatDao(this as AppDatabase);
  late final MessageDao messageDao = MessageDao(this as AppDatabase);
  late final ApiConfigDao apiConfigDao = ApiConfigDao(this as AppDatabase);
  late final UserDao userDao = UserDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [chats, messages, apiConfigs, users];
}

typedef $$ChatsTableCreateCompanionBuilder = ChatsCompanion Function({
  Value<int> id,
  Value<String?> title,
  Value<String?> systemPrompt,
  Value<DateTime> createdAt,
  required DateTime updatedAt,
  Value<String?> coverImageBase64,
  Value<String?> backgroundImagePath,
  Value<int?> orderIndex,
  Value<bool?> isFolder,
  Value<int?> parentFolderId,
  required DriftContextConfig contextConfig,
  required List<DriftXmlRule> xmlRules,
  Value<String?> apiConfigId,
  Value<bool?> enablePreprocessing,
  Value<String?> preprocessingPrompt,
  Value<String?> contextSummary,
  Value<String?> preprocessingApiConfigId,
  Value<bool?> enableSecondaryXml,
  Value<String?> secondaryXmlPrompt,
  Value<String?> secondaryXmlApiConfigId,
  Value<String?> continuePrompt,
  Value<bool?> enableHelpMeReply,
  Value<String?> helpMeReplyPrompt,
  Value<String?> helpMeReplyApiConfigId,
  Value<HelpMeReplyTriggerMode?> helpMeReplyTriggerMode,
});
typedef $$ChatsTableUpdateCompanionBuilder = ChatsCompanion Function({
  Value<int> id,
  Value<String?> title,
  Value<String?> systemPrompt,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<String?> coverImageBase64,
  Value<String?> backgroundImagePath,
  Value<int?> orderIndex,
  Value<bool?> isFolder,
  Value<int?> parentFolderId,
  Value<DriftContextConfig> contextConfig,
  Value<List<DriftXmlRule>> xmlRules,
  Value<String?> apiConfigId,
  Value<bool?> enablePreprocessing,
  Value<String?> preprocessingPrompt,
  Value<String?> contextSummary,
  Value<String?> preprocessingApiConfigId,
  Value<bool?> enableSecondaryXml,
  Value<String?> secondaryXmlPrompt,
  Value<String?> secondaryXmlApiConfigId,
  Value<String?> continuePrompt,
  Value<bool?> enableHelpMeReply,
  Value<String?> helpMeReplyPrompt,
  Value<String?> helpMeReplyApiConfigId,
  Value<HelpMeReplyTriggerMode?> helpMeReplyTriggerMode,
});

final class $$ChatsTableReferences
    extends BaseReferences<_$AppDatabase, $ChatsTable, ChatData> {
  $$ChatsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MessagesTable, List<MessageData>>
      _messagesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.messages,
              aliasName: $_aliasNameGenerator(db.chats.id, db.messages.chatId));

  $$MessagesTableProcessedTableManager get messagesRefs {
    final manager = $$MessagesTableTableManager($_db, $_db.messages)
        .filter((f) => f.chatId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_messagesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$ChatsTableFilterComposer extends Composer<_$AppDatabase, $ChatsTable> {
  $$ChatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get systemPrompt => $composableBuilder(
      column: $table.systemPrompt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get coverImageBase64 => $composableBuilder(
      column: $table.coverImageBase64,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get backgroundImagePath => $composableBuilder(
      column: $table.backgroundImagePath,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get orderIndex => $composableBuilder(
      column: $table.orderIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isFolder => $composableBuilder(
      column: $table.isFolder, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get parentFolderId => $composableBuilder(
      column: $table.parentFolderId,
      builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<DriftContextConfig, DriftContextConfig, String>
      get contextConfig => $composableBuilder(
          column: $table.contextConfig,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnWithTypeConverterFilters<List<DriftXmlRule>, List<DriftXmlRule>, String>
      get xmlRules => $composableBuilder(
          column: $table.xmlRules,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get apiConfigId => $composableBuilder(
      column: $table.apiConfigId, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get enablePreprocessing => $composableBuilder(
      column: $table.enablePreprocessing,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get preprocessingPrompt => $composableBuilder(
      column: $table.preprocessingPrompt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contextSummary => $composableBuilder(
      column: $table.contextSummary,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get preprocessingApiConfigId => $composableBuilder(
      column: $table.preprocessingApiConfigId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get enableSecondaryXml => $composableBuilder(
      column: $table.enableSecondaryXml,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get secondaryXmlPrompt => $composableBuilder(
      column: $table.secondaryXmlPrompt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get secondaryXmlApiConfigId => $composableBuilder(
      column: $table.secondaryXmlApiConfigId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get continuePrompt => $composableBuilder(
      column: $table.continuePrompt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get enableHelpMeReply => $composableBuilder(
      column: $table.enableHelpMeReply,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get helpMeReplyPrompt => $composableBuilder(
      column: $table.helpMeReplyPrompt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get helpMeReplyApiConfigId => $composableBuilder(
      column: $table.helpMeReplyApiConfigId,
      builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<HelpMeReplyTriggerMode?,
          HelpMeReplyTriggerMode, String>
      get helpMeReplyTriggerMode => $composableBuilder(
          column: $table.helpMeReplyTriggerMode,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  Expression<bool> messagesRefs(
      Expression<bool> Function($$MessagesTableFilterComposer f) f) {
    final $$MessagesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.messages,
        getReferencedColumn: (t) => t.chatId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MessagesTableFilterComposer(
              $db: $db,
              $table: $db.messages,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ChatsTableOrderingComposer
    extends Composer<_$AppDatabase, $ChatsTable> {
  $$ChatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get systemPrompt => $composableBuilder(
      column: $table.systemPrompt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get coverImageBase64 => $composableBuilder(
      column: $table.coverImageBase64,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get backgroundImagePath => $composableBuilder(
      column: $table.backgroundImagePath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get orderIndex => $composableBuilder(
      column: $table.orderIndex, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isFolder => $composableBuilder(
      column: $table.isFolder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get parentFolderId => $composableBuilder(
      column: $table.parentFolderId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contextConfig => $composableBuilder(
      column: $table.contextConfig,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get xmlRules => $composableBuilder(
      column: $table.xmlRules, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get apiConfigId => $composableBuilder(
      column: $table.apiConfigId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get enablePreprocessing => $composableBuilder(
      column: $table.enablePreprocessing,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get preprocessingPrompt => $composableBuilder(
      column: $table.preprocessingPrompt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contextSummary => $composableBuilder(
      column: $table.contextSummary,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get preprocessingApiConfigId => $composableBuilder(
      column: $table.preprocessingApiConfigId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get enableSecondaryXml => $composableBuilder(
      column: $table.enableSecondaryXml,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get secondaryXmlPrompt => $composableBuilder(
      column: $table.secondaryXmlPrompt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get secondaryXmlApiConfigId => $composableBuilder(
      column: $table.secondaryXmlApiConfigId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get continuePrompt => $composableBuilder(
      column: $table.continuePrompt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get enableHelpMeReply => $composableBuilder(
      column: $table.enableHelpMeReply,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get helpMeReplyPrompt => $composableBuilder(
      column: $table.helpMeReplyPrompt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get helpMeReplyApiConfigId => $composableBuilder(
      column: $table.helpMeReplyApiConfigId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get helpMeReplyTriggerMode => $composableBuilder(
      column: $table.helpMeReplyTriggerMode,
      builder: (column) => ColumnOrderings(column));
}

class $$ChatsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChatsTable> {
  $$ChatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get systemPrompt => $composableBuilder(
      column: $table.systemPrompt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get coverImageBase64 => $composableBuilder(
      column: $table.coverImageBase64, builder: (column) => column);

  GeneratedColumn<String> get backgroundImagePath => $composableBuilder(
      column: $table.backgroundImagePath, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
      column: $table.orderIndex, builder: (column) => column);

  GeneratedColumn<bool> get isFolder =>
      $composableBuilder(column: $table.isFolder, builder: (column) => column);

  GeneratedColumn<int> get parentFolderId => $composableBuilder(
      column: $table.parentFolderId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DriftContextConfig, String>
      get contextConfig => $composableBuilder(
          column: $table.contextConfig, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<DriftXmlRule>, String> get xmlRules =>
      $composableBuilder(column: $table.xmlRules, builder: (column) => column);

  GeneratedColumn<String> get apiConfigId => $composableBuilder(
      column: $table.apiConfigId, builder: (column) => column);

  GeneratedColumn<bool> get enablePreprocessing => $composableBuilder(
      column: $table.enablePreprocessing, builder: (column) => column);

  GeneratedColumn<String> get preprocessingPrompt => $composableBuilder(
      column: $table.preprocessingPrompt, builder: (column) => column);

  GeneratedColumn<String> get contextSummary => $composableBuilder(
      column: $table.contextSummary, builder: (column) => column);

  GeneratedColumn<String> get preprocessingApiConfigId => $composableBuilder(
      column: $table.preprocessingApiConfigId, builder: (column) => column);

  GeneratedColumn<bool> get enableSecondaryXml => $composableBuilder(
      column: $table.enableSecondaryXml, builder: (column) => column);

  GeneratedColumn<String> get secondaryXmlPrompt => $composableBuilder(
      column: $table.secondaryXmlPrompt, builder: (column) => column);

  GeneratedColumn<String> get secondaryXmlApiConfigId => $composableBuilder(
      column: $table.secondaryXmlApiConfigId, builder: (column) => column);

  GeneratedColumn<String> get continuePrompt => $composableBuilder(
      column: $table.continuePrompt, builder: (column) => column);

  GeneratedColumn<bool> get enableHelpMeReply => $composableBuilder(
      column: $table.enableHelpMeReply, builder: (column) => column);

  GeneratedColumn<String> get helpMeReplyPrompt => $composableBuilder(
      column: $table.helpMeReplyPrompt, builder: (column) => column);

  GeneratedColumn<String> get helpMeReplyApiConfigId => $composableBuilder(
      column: $table.helpMeReplyApiConfigId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<HelpMeReplyTriggerMode?, String>
      get helpMeReplyTriggerMode => $composableBuilder(
          column: $table.helpMeReplyTriggerMode, builder: (column) => column);

  Expression<T> messagesRefs<T extends Object>(
      Expression<T> Function($$MessagesTableAnnotationComposer a) f) {
    final $$MessagesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.messages,
        getReferencedColumn: (t) => t.chatId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MessagesTableAnnotationComposer(
              $db: $db,
              $table: $db.messages,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ChatsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ChatsTable,
    ChatData,
    $$ChatsTableFilterComposer,
    $$ChatsTableOrderingComposer,
    $$ChatsTableAnnotationComposer,
    $$ChatsTableCreateCompanionBuilder,
    $$ChatsTableUpdateCompanionBuilder,
    (ChatData, $$ChatsTableReferences),
    ChatData,
    PrefetchHooks Function({bool messagesRefs})> {
  $$ChatsTableTableManager(_$AppDatabase db, $ChatsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> title = const Value.absent(),
            Value<String?> systemPrompt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<String?> coverImageBase64 = const Value.absent(),
            Value<String?> backgroundImagePath = const Value.absent(),
            Value<int?> orderIndex = const Value.absent(),
            Value<bool?> isFolder = const Value.absent(),
            Value<int?> parentFolderId = const Value.absent(),
            Value<DriftContextConfig> contextConfig = const Value.absent(),
            Value<List<DriftXmlRule>> xmlRules = const Value.absent(),
            Value<String?> apiConfigId = const Value.absent(),
            Value<bool?> enablePreprocessing = const Value.absent(),
            Value<String?> preprocessingPrompt = const Value.absent(),
            Value<String?> contextSummary = const Value.absent(),
            Value<String?> preprocessingApiConfigId = const Value.absent(),
            Value<bool?> enableSecondaryXml = const Value.absent(),
            Value<String?> secondaryXmlPrompt = const Value.absent(),
            Value<String?> secondaryXmlApiConfigId = const Value.absent(),
            Value<String?> continuePrompt = const Value.absent(),
            Value<bool?> enableHelpMeReply = const Value.absent(),
            Value<String?> helpMeReplyPrompt = const Value.absent(),
            Value<String?> helpMeReplyApiConfigId = const Value.absent(),
            Value<HelpMeReplyTriggerMode?> helpMeReplyTriggerMode =
                const Value.absent(),
          }) =>
              ChatsCompanion(
            id: id,
            title: title,
            systemPrompt: systemPrompt,
            createdAt: createdAt,
            updatedAt: updatedAt,
            coverImageBase64: coverImageBase64,
            backgroundImagePath: backgroundImagePath,
            orderIndex: orderIndex,
            isFolder: isFolder,
            parentFolderId: parentFolderId,
            contextConfig: contextConfig,
            xmlRules: xmlRules,
            apiConfigId: apiConfigId,
            enablePreprocessing: enablePreprocessing,
            preprocessingPrompt: preprocessingPrompt,
            contextSummary: contextSummary,
            preprocessingApiConfigId: preprocessingApiConfigId,
            enableSecondaryXml: enableSecondaryXml,
            secondaryXmlPrompt: secondaryXmlPrompt,
            secondaryXmlApiConfigId: secondaryXmlApiConfigId,
            continuePrompt: continuePrompt,
            enableHelpMeReply: enableHelpMeReply,
            helpMeReplyPrompt: helpMeReplyPrompt,
            helpMeReplyApiConfigId: helpMeReplyApiConfigId,
            helpMeReplyTriggerMode: helpMeReplyTriggerMode,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> title = const Value.absent(),
            Value<String?> systemPrompt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            required DateTime updatedAt,
            Value<String?> coverImageBase64 = const Value.absent(),
            Value<String?> backgroundImagePath = const Value.absent(),
            Value<int?> orderIndex = const Value.absent(),
            Value<bool?> isFolder = const Value.absent(),
            Value<int?> parentFolderId = const Value.absent(),
            required DriftContextConfig contextConfig,
            required List<DriftXmlRule> xmlRules,
            Value<String?> apiConfigId = const Value.absent(),
            Value<bool?> enablePreprocessing = const Value.absent(),
            Value<String?> preprocessingPrompt = const Value.absent(),
            Value<String?> contextSummary = const Value.absent(),
            Value<String?> preprocessingApiConfigId = const Value.absent(),
            Value<bool?> enableSecondaryXml = const Value.absent(),
            Value<String?> secondaryXmlPrompt = const Value.absent(),
            Value<String?> secondaryXmlApiConfigId = const Value.absent(),
            Value<String?> continuePrompt = const Value.absent(),
            Value<bool?> enableHelpMeReply = const Value.absent(),
            Value<String?> helpMeReplyPrompt = const Value.absent(),
            Value<String?> helpMeReplyApiConfigId = const Value.absent(),
            Value<HelpMeReplyTriggerMode?> helpMeReplyTriggerMode =
                const Value.absent(),
          }) =>
              ChatsCompanion.insert(
            id: id,
            title: title,
            systemPrompt: systemPrompt,
            createdAt: createdAt,
            updatedAt: updatedAt,
            coverImageBase64: coverImageBase64,
            backgroundImagePath: backgroundImagePath,
            orderIndex: orderIndex,
            isFolder: isFolder,
            parentFolderId: parentFolderId,
            contextConfig: contextConfig,
            xmlRules: xmlRules,
            apiConfigId: apiConfigId,
            enablePreprocessing: enablePreprocessing,
            preprocessingPrompt: preprocessingPrompt,
            contextSummary: contextSummary,
            preprocessingApiConfigId: preprocessingApiConfigId,
            enableSecondaryXml: enableSecondaryXml,
            secondaryXmlPrompt: secondaryXmlPrompt,
            secondaryXmlApiConfigId: secondaryXmlApiConfigId,
            continuePrompt: continuePrompt,
            enableHelpMeReply: enableHelpMeReply,
            helpMeReplyPrompt: helpMeReplyPrompt,
            helpMeReplyApiConfigId: helpMeReplyApiConfigId,
            helpMeReplyTriggerMode: helpMeReplyTriggerMode,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$ChatsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({messagesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (messagesRefs) db.messages],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (messagesRefs)
                    await $_getPrefetchedData<ChatData, $ChatsTable,
                            MessageData>(
                        currentTable: table,
                        referencedTable:
                            $$ChatsTableReferences._messagesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ChatsTableReferences(db, table, p0).messagesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.chatId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$ChatsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ChatsTable,
    ChatData,
    $$ChatsTableFilterComposer,
    $$ChatsTableOrderingComposer,
    $$ChatsTableAnnotationComposer,
    $$ChatsTableCreateCompanionBuilder,
    $$ChatsTableUpdateCompanionBuilder,
    (ChatData, $$ChatsTableReferences),
    ChatData,
    PrefetchHooks Function({bool messagesRefs})>;
typedef $$MessagesTableCreateCompanionBuilder = MessagesCompanion Function({
  Value<int> id,
  required int chatId,
  required String rawText,
  required MessageRole role,
  required DateTime timestamp,
  Value<String?> originalXmlContent,
  Value<String?> secondaryXmlContent,
});
typedef $$MessagesTableUpdateCompanionBuilder = MessagesCompanion Function({
  Value<int> id,
  Value<int> chatId,
  Value<String> rawText,
  Value<MessageRole> role,
  Value<DateTime> timestamp,
  Value<String?> originalXmlContent,
  Value<String?> secondaryXmlContent,
});

final class $$MessagesTableReferences
    extends BaseReferences<_$AppDatabase, $MessagesTable, MessageData> {
  $$MessagesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ChatsTable _chatIdTable(_$AppDatabase db) => db.chats
      .createAlias($_aliasNameGenerator(db.messages.chatId, db.chats.id));

  $$ChatsTableProcessedTableManager get chatId {
    final $_column = $_itemColumn<int>('chat_id')!;

    final manager = $$ChatsTableTableManager($_db, $_db.chats)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_chatIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$MessagesTableFilterComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rawText => $composableBuilder(
      column: $table.rawText, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<MessageRole, MessageRole, String> get role =>
      $composableBuilder(
          column: $table.role,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get originalXmlContent => $composableBuilder(
      column: $table.originalXmlContent,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get secondaryXmlContent => $composableBuilder(
      column: $table.secondaryXmlContent,
      builder: (column) => ColumnFilters(column));

  $$ChatsTableFilterComposer get chatId {
    final $$ChatsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.chatId,
        referencedTable: $db.chats,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ChatsTableFilterComposer(
              $db: $db,
              $table: $db.chats,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$MessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rawText => $composableBuilder(
      column: $table.rawText, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get role => $composableBuilder(
      column: $table.role, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get originalXmlContent => $composableBuilder(
      column: $table.originalXmlContent,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get secondaryXmlContent => $composableBuilder(
      column: $table.secondaryXmlContent,
      builder: (column) => ColumnOrderings(column));

  $$ChatsTableOrderingComposer get chatId {
    final $$ChatsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.chatId,
        referencedTable: $db.chats,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ChatsTableOrderingComposer(
              $db: $db,
              $table: $db.chats,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get rawText =>
      $composableBuilder(column: $table.rawText, builder: (column) => column);

  GeneratedColumnWithTypeConverter<MessageRole, String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get originalXmlContent => $composableBuilder(
      column: $table.originalXmlContent, builder: (column) => column);

  GeneratedColumn<String> get secondaryXmlContent => $composableBuilder(
      column: $table.secondaryXmlContent, builder: (column) => column);

  $$ChatsTableAnnotationComposer get chatId {
    final $$ChatsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.chatId,
        referencedTable: $db.chats,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ChatsTableAnnotationComposer(
              $db: $db,
              $table: $db.chats,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$MessagesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MessagesTable,
    MessageData,
    $$MessagesTableFilterComposer,
    $$MessagesTableOrderingComposer,
    $$MessagesTableAnnotationComposer,
    $$MessagesTableCreateCompanionBuilder,
    $$MessagesTableUpdateCompanionBuilder,
    (MessageData, $$MessagesTableReferences),
    MessageData,
    PrefetchHooks Function({bool chatId})> {
  $$MessagesTableTableManager(_$AppDatabase db, $MessagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> chatId = const Value.absent(),
            Value<String> rawText = const Value.absent(),
            Value<MessageRole> role = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<String?> originalXmlContent = const Value.absent(),
            Value<String?> secondaryXmlContent = const Value.absent(),
          }) =>
              MessagesCompanion(
            id: id,
            chatId: chatId,
            rawText: rawText,
            role: role,
            timestamp: timestamp,
            originalXmlContent: originalXmlContent,
            secondaryXmlContent: secondaryXmlContent,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int chatId,
            required String rawText,
            required MessageRole role,
            required DateTime timestamp,
            Value<String?> originalXmlContent = const Value.absent(),
            Value<String?> secondaryXmlContent = const Value.absent(),
          }) =>
              MessagesCompanion.insert(
            id: id,
            chatId: chatId,
            rawText: rawText,
            role: role,
            timestamp: timestamp,
            originalXmlContent: originalXmlContent,
            secondaryXmlContent: secondaryXmlContent,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$MessagesTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({chatId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (chatId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.chatId,
                    referencedTable: $$MessagesTableReferences._chatIdTable(db),
                    referencedColumn:
                        $$MessagesTableReferences._chatIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$MessagesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MessagesTable,
    MessageData,
    $$MessagesTableFilterComposer,
    $$MessagesTableOrderingComposer,
    $$MessagesTableAnnotationComposer,
    $$MessagesTableCreateCompanionBuilder,
    $$MessagesTableUpdateCompanionBuilder,
    (MessageData, $$MessagesTableReferences),
    MessageData,
    PrefetchHooks Function({bool chatId})>;
typedef $$ApiConfigsTableCreateCompanionBuilder = ApiConfigsCompanion Function({
  Value<int?> userId,
  Value<String> id,
  required String name,
  required LlmType apiType,
  required String model,
  Value<String?> apiKey,
  Value<String?> baseUrl,
  Value<bool?> useCustomTemperature,
  Value<double?> temperature,
  Value<bool?> useCustomTopP,
  Value<double?> topP,
  Value<bool?> useCustomTopK,
  Value<int?> topK,
  Value<int?> maxOutputTokens,
  Value<List<String>?> stopSequences,
  Value<bool?> enableReasoningEffort,
  Value<OpenAIReasoningEffort?> reasoningEffort,
  Value<DateTime> createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$ApiConfigsTableUpdateCompanionBuilder = ApiConfigsCompanion Function({
  Value<int?> userId,
  Value<String> id,
  Value<String> name,
  Value<LlmType> apiType,
  Value<String> model,
  Value<String?> apiKey,
  Value<String?> baseUrl,
  Value<bool?> useCustomTemperature,
  Value<double?> temperature,
  Value<bool?> useCustomTopP,
  Value<double?> topP,
  Value<bool?> useCustomTopK,
  Value<int?> topK,
  Value<int?> maxOutputTokens,
  Value<List<String>?> stopSequences,
  Value<bool?> enableReasoningEffort,
  Value<OpenAIReasoningEffort?> reasoningEffort,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$ApiConfigsTableFilterComposer
    extends Composer<_$AppDatabase, $ApiConfigsTable> {
  $$ApiConfigsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<LlmType, LlmType, String> get apiType =>
      $composableBuilder(
          column: $table.apiType,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get model => $composableBuilder(
      column: $table.model, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get apiKey => $composableBuilder(
      column: $table.apiKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get baseUrl => $composableBuilder(
      column: $table.baseUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get useCustomTemperature => $composableBuilder(
      column: $table.useCustomTemperature,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get temperature => $composableBuilder(
      column: $table.temperature, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get useCustomTopP => $composableBuilder(
      column: $table.useCustomTopP, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get topP => $composableBuilder(
      column: $table.topP, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get useCustomTopK => $composableBuilder(
      column: $table.useCustomTopK, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get topK => $composableBuilder(
      column: $table.topK, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get maxOutputTokens => $composableBuilder(
      column: $table.maxOutputTokens,
      builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<List<String>?, List<String>, String>
      get stopSequences => $composableBuilder(
          column: $table.stopSequences,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<bool> get enableReasoningEffort => $composableBuilder(
      column: $table.enableReasoningEffort,
      builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<OpenAIReasoningEffort?, OpenAIReasoningEffort,
          String>
      get reasoningEffort => $composableBuilder(
          column: $table.reasoningEffort,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$ApiConfigsTableOrderingComposer
    extends Composer<_$AppDatabase, $ApiConfigsTable> {
  $$ApiConfigsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get apiType => $composableBuilder(
      column: $table.apiType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get model => $composableBuilder(
      column: $table.model, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get apiKey => $composableBuilder(
      column: $table.apiKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get baseUrl => $composableBuilder(
      column: $table.baseUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get useCustomTemperature => $composableBuilder(
      column: $table.useCustomTemperature,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get temperature => $composableBuilder(
      column: $table.temperature, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get useCustomTopP => $composableBuilder(
      column: $table.useCustomTopP,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get topP => $composableBuilder(
      column: $table.topP, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get useCustomTopK => $composableBuilder(
      column: $table.useCustomTopK,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get topK => $composableBuilder(
      column: $table.topK, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get maxOutputTokens => $composableBuilder(
      column: $table.maxOutputTokens,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get stopSequences => $composableBuilder(
      column: $table.stopSequences,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get enableReasoningEffort => $composableBuilder(
      column: $table.enableReasoningEffort,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reasoningEffort => $composableBuilder(
      column: $table.reasoningEffort,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$ApiConfigsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ApiConfigsTable> {
  $$ApiConfigsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LlmType, String> get apiType =>
      $composableBuilder(column: $table.apiType, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<String> get apiKey =>
      $composableBuilder(column: $table.apiKey, builder: (column) => column);

  GeneratedColumn<String> get baseUrl =>
      $composableBuilder(column: $table.baseUrl, builder: (column) => column);

  GeneratedColumn<bool> get useCustomTemperature => $composableBuilder(
      column: $table.useCustomTemperature, builder: (column) => column);

  GeneratedColumn<double> get temperature => $composableBuilder(
      column: $table.temperature, builder: (column) => column);

  GeneratedColumn<bool> get useCustomTopP => $composableBuilder(
      column: $table.useCustomTopP, builder: (column) => column);

  GeneratedColumn<double> get topP =>
      $composableBuilder(column: $table.topP, builder: (column) => column);

  GeneratedColumn<bool> get useCustomTopK => $composableBuilder(
      column: $table.useCustomTopK, builder: (column) => column);

  GeneratedColumn<int> get topK =>
      $composableBuilder(column: $table.topK, builder: (column) => column);

  GeneratedColumn<int> get maxOutputTokens => $composableBuilder(
      column: $table.maxOutputTokens, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>?, String> get stopSequences =>
      $composableBuilder(
          column: $table.stopSequences, builder: (column) => column);

  GeneratedColumn<bool> get enableReasoningEffort => $composableBuilder(
      column: $table.enableReasoningEffort, builder: (column) => column);

  GeneratedColumnWithTypeConverter<OpenAIReasoningEffort?, String>
      get reasoningEffort => $composableBuilder(
          column: $table.reasoningEffort, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ApiConfigsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ApiConfigsTable,
    ApiConfig,
    $$ApiConfigsTableFilterComposer,
    $$ApiConfigsTableOrderingComposer,
    $$ApiConfigsTableAnnotationComposer,
    $$ApiConfigsTableCreateCompanionBuilder,
    $$ApiConfigsTableUpdateCompanionBuilder,
    (ApiConfig, BaseReferences<_$AppDatabase, $ApiConfigsTable, ApiConfig>),
    ApiConfig,
    PrefetchHooks Function()> {
  $$ApiConfigsTableTableManager(_$AppDatabase db, $ApiConfigsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ApiConfigsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ApiConfigsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ApiConfigsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int?> userId = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<LlmType> apiType = const Value.absent(),
            Value<String> model = const Value.absent(),
            Value<String?> apiKey = const Value.absent(),
            Value<String?> baseUrl = const Value.absent(),
            Value<bool?> useCustomTemperature = const Value.absent(),
            Value<double?> temperature = const Value.absent(),
            Value<bool?> useCustomTopP = const Value.absent(),
            Value<double?> topP = const Value.absent(),
            Value<bool?> useCustomTopK = const Value.absent(),
            Value<int?> topK = const Value.absent(),
            Value<int?> maxOutputTokens = const Value.absent(),
            Value<List<String>?> stopSequences = const Value.absent(),
            Value<bool?> enableReasoningEffort = const Value.absent(),
            Value<OpenAIReasoningEffort?> reasoningEffort =
                const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ApiConfigsCompanion(
            userId: userId,
            id: id,
            name: name,
            apiType: apiType,
            model: model,
            apiKey: apiKey,
            baseUrl: baseUrl,
            useCustomTemperature: useCustomTemperature,
            temperature: temperature,
            useCustomTopP: useCustomTopP,
            topP: topP,
            useCustomTopK: useCustomTopK,
            topK: topK,
            maxOutputTokens: maxOutputTokens,
            stopSequences: stopSequences,
            enableReasoningEffort: enableReasoningEffort,
            reasoningEffort: reasoningEffort,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<int?> userId = const Value.absent(),
            Value<String> id = const Value.absent(),
            required String name,
            required LlmType apiType,
            required String model,
            Value<String?> apiKey = const Value.absent(),
            Value<String?> baseUrl = const Value.absent(),
            Value<bool?> useCustomTemperature = const Value.absent(),
            Value<double?> temperature = const Value.absent(),
            Value<bool?> useCustomTopP = const Value.absent(),
            Value<double?> topP = const Value.absent(),
            Value<bool?> useCustomTopK = const Value.absent(),
            Value<int?> topK = const Value.absent(),
            Value<int?> maxOutputTokens = const Value.absent(),
            Value<List<String>?> stopSequences = const Value.absent(),
            Value<bool?> enableReasoningEffort = const Value.absent(),
            Value<OpenAIReasoningEffort?> reasoningEffort =
                const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              ApiConfigsCompanion.insert(
            userId: userId,
            id: id,
            name: name,
            apiType: apiType,
            model: model,
            apiKey: apiKey,
            baseUrl: baseUrl,
            useCustomTemperature: useCustomTemperature,
            temperature: temperature,
            useCustomTopP: useCustomTopP,
            topP: topP,
            useCustomTopK: useCustomTopK,
            topK: topK,
            maxOutputTokens: maxOutputTokens,
            stopSequences: stopSequences,
            enableReasoningEffort: enableReasoningEffort,
            reasoningEffort: reasoningEffort,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ApiConfigsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ApiConfigsTable,
    ApiConfig,
    $$ApiConfigsTableFilterComposer,
    $$ApiConfigsTableOrderingComposer,
    $$ApiConfigsTableAnnotationComposer,
    $$ApiConfigsTableCreateCompanionBuilder,
    $$ApiConfigsTableUpdateCompanionBuilder,
    (ApiConfig, BaseReferences<_$AppDatabase, $ApiConfigsTable, ApiConfig>),
    ApiConfig,
    PrefetchHooks Function()>;
typedef $$UsersTableCreateCompanionBuilder = UsersCompanion Function({
  Value<int> id,
  Value<String> uuid,
  Value<DateTime> createdAt,
  required DateTime updatedAt,
  required String username,
  required String passwordHash,
  Value<List<int>?> chatIds,
  Value<bool?> enableAutoTitleGeneration,
  Value<String?> titleGenerationPrompt,
  Value<String?> titleGenerationApiConfigId,
  Value<bool?> enableResume,
  Value<String?> resumePrompt,
  Value<String?> resumeApiConfigId,
  Value<List<String>?> geminiApiKeys,
});
typedef $$UsersTableUpdateCompanionBuilder = UsersCompanion Function({
  Value<int> id,
  Value<String> uuid,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<String> username,
  Value<String> passwordHash,
  Value<List<int>?> chatIds,
  Value<bool?> enableAutoTitleGeneration,
  Value<String?> titleGenerationPrompt,
  Value<String?> titleGenerationApiConfigId,
  Value<bool?> enableResume,
  Value<String?> resumePrompt,
  Value<String?> resumeApiConfigId,
  Value<List<String>?> geminiApiKeys,
});

class $$UsersTableFilterComposer extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get uuid => $composableBuilder(
      column: $table.uuid, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get username => $composableBuilder(
      column: $table.username, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get passwordHash => $composableBuilder(
      column: $table.passwordHash, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<List<int>?, List<int>, String> get chatIds =>
      $composableBuilder(
          column: $table.chatIds,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<bool> get enableAutoTitleGeneration => $composableBuilder(
      column: $table.enableAutoTitleGeneration,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get titleGenerationPrompt => $composableBuilder(
      column: $table.titleGenerationPrompt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get titleGenerationApiConfigId => $composableBuilder(
      column: $table.titleGenerationApiConfigId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get enableResume => $composableBuilder(
      column: $table.enableResume, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get resumePrompt => $composableBuilder(
      column: $table.resumePrompt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get resumeApiConfigId => $composableBuilder(
      column: $table.resumeApiConfigId,
      builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<List<String>?, List<String>, String>
      get geminiApiKeys => $composableBuilder(
          column: $table.geminiApiKeys,
          builder: (column) => ColumnWithTypeConverterFilters(column));
}

class $$UsersTableOrderingComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get uuid => $composableBuilder(
      column: $table.uuid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get username => $composableBuilder(
      column: $table.username, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get passwordHash => $composableBuilder(
      column: $table.passwordHash,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get chatIds => $composableBuilder(
      column: $table.chatIds, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get enableAutoTitleGeneration => $composableBuilder(
      column: $table.enableAutoTitleGeneration,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get titleGenerationPrompt => $composableBuilder(
      column: $table.titleGenerationPrompt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get titleGenerationApiConfigId => $composableBuilder(
      column: $table.titleGenerationApiConfigId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get enableResume => $composableBuilder(
      column: $table.enableResume,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get resumePrompt => $composableBuilder(
      column: $table.resumePrompt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get resumeApiConfigId => $composableBuilder(
      column: $table.resumeApiConfigId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get geminiApiKeys => $composableBuilder(
      column: $table.geminiApiKeys,
      builder: (column) => ColumnOrderings(column));
}

class $$UsersTableAnnotationComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get passwordHash => $composableBuilder(
      column: $table.passwordHash, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<int>?, String> get chatIds =>
      $composableBuilder(column: $table.chatIds, builder: (column) => column);

  GeneratedColumn<bool> get enableAutoTitleGeneration => $composableBuilder(
      column: $table.enableAutoTitleGeneration, builder: (column) => column);

  GeneratedColumn<String> get titleGenerationPrompt => $composableBuilder(
      column: $table.titleGenerationPrompt, builder: (column) => column);

  GeneratedColumn<String> get titleGenerationApiConfigId => $composableBuilder(
      column: $table.titleGenerationApiConfigId, builder: (column) => column);

  GeneratedColumn<bool> get enableResume => $composableBuilder(
      column: $table.enableResume, builder: (column) => column);

  GeneratedColumn<String> get resumePrompt => $composableBuilder(
      column: $table.resumePrompt, builder: (column) => column);

  GeneratedColumn<String> get resumeApiConfigId => $composableBuilder(
      column: $table.resumeApiConfigId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>?, String> get geminiApiKeys =>
      $composableBuilder(
          column: $table.geminiApiKeys, builder: (column) => column);
}

class $$UsersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $UsersTable,
    DriftUser,
    $$UsersTableFilterComposer,
    $$UsersTableOrderingComposer,
    $$UsersTableAnnotationComposer,
    $$UsersTableCreateCompanionBuilder,
    $$UsersTableUpdateCompanionBuilder,
    (DriftUser, BaseReferences<_$AppDatabase, $UsersTable, DriftUser>),
    DriftUser,
    PrefetchHooks Function()> {
  $$UsersTableTableManager(_$AppDatabase db, $UsersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> uuid = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<String> username = const Value.absent(),
            Value<String> passwordHash = const Value.absent(),
            Value<List<int>?> chatIds = const Value.absent(),
            Value<bool?> enableAutoTitleGeneration = const Value.absent(),
            Value<String?> titleGenerationPrompt = const Value.absent(),
            Value<String?> titleGenerationApiConfigId = const Value.absent(),
            Value<bool?> enableResume = const Value.absent(),
            Value<String?> resumePrompt = const Value.absent(),
            Value<String?> resumeApiConfigId = const Value.absent(),
            Value<List<String>?> geminiApiKeys = const Value.absent(),
          }) =>
              UsersCompanion(
            id: id,
            uuid: uuid,
            createdAt: createdAt,
            updatedAt: updatedAt,
            username: username,
            passwordHash: passwordHash,
            chatIds: chatIds,
            enableAutoTitleGeneration: enableAutoTitleGeneration,
            titleGenerationPrompt: titleGenerationPrompt,
            titleGenerationApiConfigId: titleGenerationApiConfigId,
            enableResume: enableResume,
            resumePrompt: resumePrompt,
            resumeApiConfigId: resumeApiConfigId,
            geminiApiKeys: geminiApiKeys,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> uuid = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            required DateTime updatedAt,
            required String username,
            required String passwordHash,
            Value<List<int>?> chatIds = const Value.absent(),
            Value<bool?> enableAutoTitleGeneration = const Value.absent(),
            Value<String?> titleGenerationPrompt = const Value.absent(),
            Value<String?> titleGenerationApiConfigId = const Value.absent(),
            Value<bool?> enableResume = const Value.absent(),
            Value<String?> resumePrompt = const Value.absent(),
            Value<String?> resumeApiConfigId = const Value.absent(),
            Value<List<String>?> geminiApiKeys = const Value.absent(),
          }) =>
              UsersCompanion.insert(
            id: id,
            uuid: uuid,
            createdAt: createdAt,
            updatedAt: updatedAt,
            username: username,
            passwordHash: passwordHash,
            chatIds: chatIds,
            enableAutoTitleGeneration: enableAutoTitleGeneration,
            titleGenerationPrompt: titleGenerationPrompt,
            titleGenerationApiConfigId: titleGenerationApiConfigId,
            enableResume: enableResume,
            resumePrompt: resumePrompt,
            resumeApiConfigId: resumeApiConfigId,
            geminiApiKeys: geminiApiKeys,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$UsersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $UsersTable,
    DriftUser,
    $$UsersTableFilterComposer,
    $$UsersTableOrderingComposer,
    $$UsersTableAnnotationComposer,
    $$UsersTableCreateCompanionBuilder,
    $$UsersTableUpdateCompanionBuilder,
    (DriftUser, BaseReferences<_$AppDatabase, $UsersTable, DriftUser>),
    DriftUser,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ChatsTableTableManager get chats =>
      $$ChatsTableTableManager(_db, _db.chats);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$ApiConfigsTableTableManager get apiConfigs =>
      $$ApiConfigsTableTableManager(_db, _db.apiConfigs);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db, _db.users);
}

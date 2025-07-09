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
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
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
      'is_folder', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_folder" IN (0, 1))'),
      defaultValue: const Constant(false));
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
        continuePrompt
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
    } else if (isInserting) {
      context.missing(_createdAtMeta);
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
          .read(DriftSqlType.bool, data['${effectivePrefix}is_folder'])!,
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
  final bool isFolder;
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
  const ChatData(
      {required this.id,
      this.title,
      this.systemPrompt,
      required this.createdAt,
      required this.updatedAt,
      this.coverImageBase64,
      this.backgroundImagePath,
      this.orderIndex,
      required this.isFolder,
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
      this.continuePrompt});
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
    map['is_folder'] = Variable<bool>(isFolder);
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
      isFolder: Value(isFolder),
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
      isFolder: serializer.fromJson<bool>(json['isFolder']),
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
      'isFolder': serializer.toJson<bool>(isFolder),
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
          bool? isFolder,
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
          Value<String?> continuePrompt = const Value.absent()}) =>
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
        isFolder: isFolder ?? this.isFolder,
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
          ..write('continuePrompt: $continuePrompt')
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
        continuePrompt
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
          other.continuePrompt == this.continuePrompt);
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
  final Value<bool> isFolder;
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
  });
  ChatsCompanion.insert({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.systemPrompt = const Value.absent(),
    required DateTime createdAt,
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
  })  : createdAt = Value(createdAt),
        updatedAt = Value(updatedAt),
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
      Value<bool>? isFolder,
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
      Value<String?>? continuePrompt}) {
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
          ..write('continuePrompt: $continuePrompt')
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
  static const VerificationMeta _partsJsonMeta =
      const VerificationMeta('partsJson');
  @override
  late final GeneratedColumn<String> partsJson = GeneratedColumn<String>(
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
        partsJson,
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
      context.handle(_partsJsonMeta,
          partsJson.isAcceptableOrUnknown(data['raw_text']!, _partsJsonMeta));
    } else if (isInserting) {
      context.missing(_partsJsonMeta);
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
      partsJson: attachedDatabase.typeMapping
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
  final String partsJson;
  final MessageRole role;
  final DateTime timestamp;
  final String? originalXmlContent;
  final String? secondaryXmlContent;
  const MessageData(
      {required this.id,
      required this.chatId,
      required this.partsJson,
      required this.role,
      required this.timestamp,
      this.originalXmlContent,
      this.secondaryXmlContent});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['chat_id'] = Variable<int>(chatId);
    map['raw_text'] = Variable<String>(partsJson);
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
      partsJson: Value(partsJson),
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
      partsJson: serializer.fromJson<String>(json['partsJson']),
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
      'partsJson': serializer.toJson<String>(partsJson),
      'role': serializer.toJson<MessageRole>(role),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'originalXmlContent': serializer.toJson<String?>(originalXmlContent),
      'secondaryXmlContent': serializer.toJson<String?>(secondaryXmlContent),
    };
  }

  MessageData copyWith(
          {int? id,
          int? chatId,
          String? partsJson,
          MessageRole? role,
          DateTime? timestamp,
          Value<String?> originalXmlContent = const Value.absent(),
          Value<String?> secondaryXmlContent = const Value.absent()}) =>
      MessageData(
        id: id ?? this.id,
        chatId: chatId ?? this.chatId,
        partsJson: partsJson ?? this.partsJson,
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
      partsJson: data.partsJson.present ? data.partsJson.value : this.partsJson,
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
          ..write('partsJson: $partsJson, ')
          ..write('role: $role, ')
          ..write('timestamp: $timestamp, ')
          ..write('originalXmlContent: $originalXmlContent, ')
          ..write('secondaryXmlContent: $secondaryXmlContent')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, chatId, partsJson, role, timestamp,
      originalXmlContent, secondaryXmlContent);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageData &&
          other.id == this.id &&
          other.chatId == this.chatId &&
          other.partsJson == this.partsJson &&
          other.role == this.role &&
          other.timestamp == this.timestamp &&
          other.originalXmlContent == this.originalXmlContent &&
          other.secondaryXmlContent == this.secondaryXmlContent);
}

class MessagesCompanion extends UpdateCompanion<MessageData> {
  final Value<int> id;
  final Value<int> chatId;
  final Value<String> partsJson;
  final Value<MessageRole> role;
  final Value<DateTime> timestamp;
  final Value<String?> originalXmlContent;
  final Value<String?> secondaryXmlContent;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.chatId = const Value.absent(),
    this.partsJson = const Value.absent(),
    this.role = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.originalXmlContent = const Value.absent(),
    this.secondaryXmlContent = const Value.absent(),
  });
  MessagesCompanion.insert({
    this.id = const Value.absent(),
    required int chatId,
    required String partsJson,
    required MessageRole role,
    required DateTime timestamp,
    this.originalXmlContent = const Value.absent(),
    this.secondaryXmlContent = const Value.absent(),
  })  : chatId = Value(chatId),
        partsJson = Value(partsJson),
        role = Value(role),
        timestamp = Value(timestamp);
  static Insertable<MessageData> custom({
    Expression<int>? id,
    Expression<int>? chatId,
    Expression<String>? partsJson,
    Expression<String>? role,
    Expression<DateTime>? timestamp,
    Expression<String>? originalXmlContent,
    Expression<String>? secondaryXmlContent,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (chatId != null) 'chat_id': chatId,
      if (partsJson != null) 'raw_text': partsJson,
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
      Value<String>? partsJson,
      Value<MessageRole>? role,
      Value<DateTime>? timestamp,
      Value<String?>? originalXmlContent,
      Value<String?>? secondaryXmlContent}) {
    return MessagesCompanion(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      partsJson: partsJson ?? this.partsJson,
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
    if (partsJson.present) {
      map['raw_text'] = Variable<String>(partsJson.value);
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
          ..write('partsJson: $partsJson, ')
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
      'use_custom_temperature', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("use_custom_temperature" IN (0, 1))'),
      defaultValue: const Constant(false));
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
      'use_custom_top_p', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("use_custom_top_p" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _topPMeta = const VerificationMeta('topP');
  @override
  late final GeneratedColumn<double> topP = GeneratedColumn<double>(
      'top_p', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _useCustomTopKMeta =
      const VerificationMeta('useCustomTopK');
  @override
  late final GeneratedColumn<bool> useCustomTopK = GeneratedColumn<bool>(
      'use_custom_top_k', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("use_custom_top_k" IN (0, 1))'),
      defaultValue: const Constant(false));
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
              $ApiConfigsTable.$converterstopSequences);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
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
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ApiConfig map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ApiConfig(
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
          DriftSqlType.bool, data['${effectivePrefix}use_custom_temperature'])!,
      temperature: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}temperature']),
      useCustomTopP: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}use_custom_top_p'])!,
      topP: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}top_p']),
      useCustomTopK: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}use_custom_top_k'])!,
      topK: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}top_k']),
      maxOutputTokens: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}max_output_tokens']),
      stopSequences: $ApiConfigsTable.$converterstopSequences.fromSql(
          attachedDatabase.typeMapping.read(
              DriftSqlType.string, data['${effectivePrefix}stop_sequences'])),
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
  static TypeConverter<List<String>?, String?> $converterstopSequences =
      const StringListConverter();
}

class ApiConfig extends DataClass implements Insertable<ApiConfig> {
  final String id;
  final String name;
  final LlmType apiType;
  final String model;
  final String? apiKey;
  final String? baseUrl;
  final bool useCustomTemperature;
  final double? temperature;
  final bool useCustomTopP;
  final double? topP;
  final bool useCustomTopK;
  final int? topK;
  final int? maxOutputTokens;
  final List<String>? stopSequences;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ApiConfig(
      {required this.id,
      required this.name,
      required this.apiType,
      required this.model,
      this.apiKey,
      this.baseUrl,
      required this.useCustomTemperature,
      this.temperature,
      required this.useCustomTopP,
      this.topP,
      required this.useCustomTopK,
      this.topK,
      this.maxOutputTokens,
      this.stopSequences,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
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
    map['use_custom_temperature'] = Variable<bool>(useCustomTemperature);
    if (!nullToAbsent || temperature != null) {
      map['temperature'] = Variable<double>(temperature);
    }
    map['use_custom_top_p'] = Variable<bool>(useCustomTopP);
    if (!nullToAbsent || topP != null) {
      map['top_p'] = Variable<double>(topP);
    }
    map['use_custom_top_k'] = Variable<bool>(useCustomTopK);
    if (!nullToAbsent || topK != null) {
      map['top_k'] = Variable<int>(topK);
    }
    if (!nullToAbsent || maxOutputTokens != null) {
      map['max_output_tokens'] = Variable<int>(maxOutputTokens);
    }
    if (!nullToAbsent || stopSequences != null) {
      map['stop_sequences'] = Variable<String>(
          $ApiConfigsTable.$converterstopSequences.toSql(stopSequences));
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ApiConfigsCompanion toCompanion(bool nullToAbsent) {
    return ApiConfigsCompanion(
      id: Value(id),
      name: Value(name),
      apiType: Value(apiType),
      model: Value(model),
      apiKey:
          apiKey == null && nullToAbsent ? const Value.absent() : Value(apiKey),
      baseUrl: baseUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(baseUrl),
      useCustomTemperature: Value(useCustomTemperature),
      temperature: temperature == null && nullToAbsent
          ? const Value.absent()
          : Value(temperature),
      useCustomTopP: Value(useCustomTopP),
      topP: topP == null && nullToAbsent ? const Value.absent() : Value(topP),
      useCustomTopK: Value(useCustomTopK),
      topK: topK == null && nullToAbsent ? const Value.absent() : Value(topK),
      maxOutputTokens: maxOutputTokens == null && nullToAbsent
          ? const Value.absent()
          : Value(maxOutputTokens),
      stopSequences: stopSequences == null && nullToAbsent
          ? const Value.absent()
          : Value(stopSequences),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ApiConfig.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ApiConfig(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      apiType: serializer.fromJson<LlmType>(json['apiType']),
      model: serializer.fromJson<String>(json['model']),
      apiKey: serializer.fromJson<String?>(json['apiKey']),
      baseUrl: serializer.fromJson<String?>(json['baseUrl']),
      useCustomTemperature:
          serializer.fromJson<bool>(json['useCustomTemperature']),
      temperature: serializer.fromJson<double?>(json['temperature']),
      useCustomTopP: serializer.fromJson<bool>(json['useCustomTopP']),
      topP: serializer.fromJson<double?>(json['topP']),
      useCustomTopK: serializer.fromJson<bool>(json['useCustomTopK']),
      topK: serializer.fromJson<int?>(json['topK']),
      maxOutputTokens: serializer.fromJson<int?>(json['maxOutputTokens']),
      stopSequences: serializer.fromJson<List<String>?>(json['stopSequences']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'apiType': serializer.toJson<LlmType>(apiType),
      'model': serializer.toJson<String>(model),
      'apiKey': serializer.toJson<String?>(apiKey),
      'baseUrl': serializer.toJson<String?>(baseUrl),
      'useCustomTemperature': serializer.toJson<bool>(useCustomTemperature),
      'temperature': serializer.toJson<double?>(temperature),
      'useCustomTopP': serializer.toJson<bool>(useCustomTopP),
      'topP': serializer.toJson<double?>(topP),
      'useCustomTopK': serializer.toJson<bool>(useCustomTopK),
      'topK': serializer.toJson<int?>(topK),
      'maxOutputTokens': serializer.toJson<int?>(maxOutputTokens),
      'stopSequences': serializer.toJson<List<String>?>(stopSequences),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ApiConfig copyWith(
          {String? id,
          String? name,
          LlmType? apiType,
          String? model,
          Value<String?> apiKey = const Value.absent(),
          Value<String?> baseUrl = const Value.absent(),
          bool? useCustomTemperature,
          Value<double?> temperature = const Value.absent(),
          bool? useCustomTopP,
          Value<double?> topP = const Value.absent(),
          bool? useCustomTopK,
          Value<int?> topK = const Value.absent(),
          Value<int?> maxOutputTokens = const Value.absent(),
          Value<List<String>?> stopSequences = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      ApiConfig(
        id: id ?? this.id,
        name: name ?? this.name,
        apiType: apiType ?? this.apiType,
        model: model ?? this.model,
        apiKey: apiKey.present ? apiKey.value : this.apiKey,
        baseUrl: baseUrl.present ? baseUrl.value : this.baseUrl,
        useCustomTemperature: useCustomTemperature ?? this.useCustomTemperature,
        temperature: temperature.present ? temperature.value : this.temperature,
        useCustomTopP: useCustomTopP ?? this.useCustomTopP,
        topP: topP.present ? topP.value : this.topP,
        useCustomTopK: useCustomTopK ?? this.useCustomTopK,
        topK: topK.present ? topK.value : this.topK,
        maxOutputTokens: maxOutputTokens.present
            ? maxOutputTokens.value
            : this.maxOutputTokens,
        stopSequences:
            stopSequences.present ? stopSequences.value : this.stopSequences,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  ApiConfig copyWithCompanion(ApiConfigsCompanion data) {
    return ApiConfig(
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
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ApiConfig(')
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
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
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
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ApiConfig &&
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
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ApiConfigsCompanion extends UpdateCompanion<ApiConfig> {
  final Value<String> id;
  final Value<String> name;
  final Value<LlmType> apiType;
  final Value<String> model;
  final Value<String?> apiKey;
  final Value<String?> baseUrl;
  final Value<bool> useCustomTemperature;
  final Value<double?> temperature;
  final Value<bool> useCustomTopP;
  final Value<double?> topP;
  final Value<bool> useCustomTopK;
  final Value<int?> topK;
  final Value<int?> maxOutputTokens;
  final Value<List<String>?> stopSequences;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ApiConfigsCompanion({
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
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ApiConfigsCompanion.insert({
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
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : name = Value(name),
        apiType = Value(apiType),
        model = Value(model);
  static Insertable<ApiConfig> custom({
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
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
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
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ApiConfigsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<LlmType>? apiType,
      Value<String>? model,
      Value<String?>? apiKey,
      Value<String?>? baseUrl,
      Value<bool>? useCustomTemperature,
      Value<double?>? temperature,
      Value<bool>? useCustomTopP,
      Value<double?>? topP,
      Value<bool>? useCustomTopK,
      Value<int?>? topK,
      Value<int?>? maxOutputTokens,
      Value<List<String>?>? stopSequences,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return ApiConfigsCompanion(
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
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
          $ApiConfigsTable.$converterstopSequences.toSql(stopSequences.value));
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
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
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
  late final ChatDao chatDao = ChatDao(this as AppDatabase);
  late final MessageDao messageDao = MessageDao(this as AppDatabase);
  late final ApiConfigDao apiConfigDao = ApiConfigDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [chats, messages, apiConfigs];
}

typedef $$ChatsTableCreateCompanionBuilder = ChatsCompanion Function({
  Value<int> id,
  Value<String?> title,
  Value<String?> systemPrompt,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<String?> coverImageBase64,
  Value<String?> backgroundImagePath,
  Value<int?> orderIndex,
  Value<bool> isFolder,
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
  Value<bool> isFolder,
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
            Value<bool> isFolder = const Value.absent(),
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
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> title = const Value.absent(),
            Value<String?> systemPrompt = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<String?> coverImageBase64 = const Value.absent(),
            Value<String?> backgroundImagePath = const Value.absent(),
            Value<int?> orderIndex = const Value.absent(),
            Value<bool> isFolder = const Value.absent(),
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
  required String partsJson,
  required MessageRole role,
  required DateTime timestamp,
  Value<String?> originalXmlContent,
  Value<String?> secondaryXmlContent,
});
typedef $$MessagesTableUpdateCompanionBuilder = MessagesCompanion Function({
  Value<int> id,
  Value<int> chatId,
  Value<String> partsJson,
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

  ColumnFilters<String> get partsJson => $composableBuilder(
      column: $table.partsJson, builder: (column) => ColumnFilters(column));

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

  ColumnOrderings<String> get partsJson => $composableBuilder(
      column: $table.partsJson, builder: (column) => ColumnOrderings(column));

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

  GeneratedColumn<String> get partsJson =>
      $composableBuilder(column: $table.partsJson, builder: (column) => column);

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
            Value<String> partsJson = const Value.absent(),
            Value<MessageRole> role = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<String?> originalXmlContent = const Value.absent(),
            Value<String?> secondaryXmlContent = const Value.absent(),
          }) =>
              MessagesCompanion(
            id: id,
            chatId: chatId,
            partsJson: partsJson,
            role: role,
            timestamp: timestamp,
            originalXmlContent: originalXmlContent,
            secondaryXmlContent: secondaryXmlContent,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int chatId,
            required String partsJson,
            required MessageRole role,
            required DateTime timestamp,
            Value<String?> originalXmlContent = const Value.absent(),
            Value<String?> secondaryXmlContent = const Value.absent(),
          }) =>
              MessagesCompanion.insert(
            id: id,
            chatId: chatId,
            partsJson: partsJson,
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
  Value<String> id,
  required String name,
  required LlmType apiType,
  required String model,
  Value<String?> apiKey,
  Value<String?> baseUrl,
  Value<bool> useCustomTemperature,
  Value<double?> temperature,
  Value<bool> useCustomTopP,
  Value<double?> topP,
  Value<bool> useCustomTopK,
  Value<int?> topK,
  Value<int?> maxOutputTokens,
  Value<List<String>?> stopSequences,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$ApiConfigsTableUpdateCompanionBuilder = ApiConfigsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<LlmType> apiType,
  Value<String> model,
  Value<String?> apiKey,
  Value<String?> baseUrl,
  Value<bool> useCustomTemperature,
  Value<double?> temperature,
  Value<bool> useCustomTopP,
  Value<double?> topP,
  Value<bool> useCustomTopK,
  Value<int?> topK,
  Value<int?> maxOutputTokens,
  Value<List<String>?> stopSequences,
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
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<LlmType> apiType = const Value.absent(),
            Value<String> model = const Value.absent(),
            Value<String?> apiKey = const Value.absent(),
            Value<String?> baseUrl = const Value.absent(),
            Value<bool> useCustomTemperature = const Value.absent(),
            Value<double?> temperature = const Value.absent(),
            Value<bool> useCustomTopP = const Value.absent(),
            Value<double?> topP = const Value.absent(),
            Value<bool> useCustomTopK = const Value.absent(),
            Value<int?> topK = const Value.absent(),
            Value<int?> maxOutputTokens = const Value.absent(),
            Value<List<String>?> stopSequences = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ApiConfigsCompanion(
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
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<String> id = const Value.absent(),
            required String name,
            required LlmType apiType,
            required String model,
            Value<String?> apiKey = const Value.absent(),
            Value<String?> baseUrl = const Value.absent(),
            Value<bool> useCustomTemperature = const Value.absent(),
            Value<double?> temperature = const Value.absent(),
            Value<bool> useCustomTopP = const Value.absent(),
            Value<double?> topP = const Value.absent(),
            Value<bool> useCustomTopK = const Value.absent(),
            Value<int?> topK = const Value.absent(),
            Value<int?> maxOutputTokens = const Value.absent(),
            Value<List<String>?> stopSequences = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ApiConfigsCompanion.insert(
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ChatsTableTableManager get chats =>
      $$ChatsTableTableManager(_db, _db.chats);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$ApiConfigsTableTableManager get apiConfigs =>
      $$ApiConfigsTableTableManager(_db, _db.apiConfigs);
}

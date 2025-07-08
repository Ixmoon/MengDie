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
  late final GeneratedColumnWithTypeConverter<DriftGenerationConfig, String>
      generationConfig = GeneratedColumn<String>(
              'generation_config', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<DriftGenerationConfig>(
              $ChatsTable.$convertergenerationConfig);
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
  @override
  late final GeneratedColumnWithTypeConverter<LlmType, String> apiType =
      GeneratedColumn<String>('api_type', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<LlmType>($ChatsTable.$converterapiType);
  static const VerificationMeta _selectedOpenAIConfigIdMeta =
      const VerificationMeta('selectedOpenAIConfigId');
  @override
  late final GeneratedColumn<String> selectedOpenAIConfigId =
      GeneratedColumn<String>('selected_open_a_i_config_id', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _enablePreprocessingMeta =
      const VerificationMeta('enablePreprocessing');
  @override
  late final GeneratedColumn<bool> enablePreprocessing = GeneratedColumn<bool>(
      'enable_preprocessing', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("enable_preprocessing" IN (0, 1))'),
      defaultValue: const Constant(false));
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
  static const VerificationMeta _enablePostprocessingMeta =
      const VerificationMeta('enablePostprocessing');
  @override
  late final GeneratedColumn<bool> enablePostprocessing = GeneratedColumn<bool>(
      'enable_postprocessing', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("enable_postprocessing" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _postprocessingPromptMeta =
      const VerificationMeta('postprocessingPrompt');
  @override
  late final GeneratedColumn<String> postprocessingPrompt =
      GeneratedColumn<String>('postprocessing_prompt', aliasedName, true,
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
        generationConfig,
        contextConfig,
        xmlRules,
        apiType,
        selectedOpenAIConfigId,
        enablePreprocessing,
        preprocessingPrompt,
        contextSummary,
        enablePostprocessing,
        postprocessingPrompt
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
    if (data.containsKey('selected_open_a_i_config_id')) {
      context.handle(
          _selectedOpenAIConfigIdMeta,
          selectedOpenAIConfigId.isAcceptableOrUnknown(
              data['selected_open_a_i_config_id']!,
              _selectedOpenAIConfigIdMeta));
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
    if (data.containsKey('enable_postprocessing')) {
      context.handle(
          _enablePostprocessingMeta,
          enablePostprocessing.isAcceptableOrUnknown(
              data['enable_postprocessing']!, _enablePostprocessingMeta));
    }
    if (data.containsKey('postprocessing_prompt')) {
      context.handle(
          _postprocessingPromptMeta,
          postprocessingPrompt.isAcceptableOrUnknown(
              data['postprocessing_prompt']!, _postprocessingPromptMeta));
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
      generationConfig: $ChatsTable.$convertergenerationConfig.fromSql(
          attachedDatabase.typeMapping.read(DriftSqlType.string,
              data['${effectivePrefix}generation_config'])!),
      contextConfig: $ChatsTable.$convertercontextConfig.fromSql(
          attachedDatabase.typeMapping.read(
              DriftSqlType.string, data['${effectivePrefix}context_config'])!),
      xmlRules: $ChatsTable.$converterxmlRules.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}xml_rules'])!),
      apiType: $ChatsTable.$converterapiType.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}api_type'])!),
      selectedOpenAIConfigId: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}selected_open_a_i_config_id']),
      enablePreprocessing: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}enable_preprocessing'])!,
      preprocessingPrompt: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}preprocessing_prompt']),
      contextSummary: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}context_summary']),
      enablePostprocessing: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}enable_postprocessing'])!,
      postprocessingPrompt: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}postprocessing_prompt']),
    );
  }

  @override
  $ChatsTable createAlias(String alias) {
    return $ChatsTable(attachedDatabase, alias);
  }

  static TypeConverter<DriftGenerationConfig, String>
      $convertergenerationConfig = const GenerationConfigConverter();
  static TypeConverter<DriftContextConfig, String> $convertercontextConfig =
      const ContextConfigConverter();
  static TypeConverter<List<DriftXmlRule>, String> $converterxmlRules =
      const XmlRuleListConverter();
  static TypeConverter<LlmType, String> $converterapiType =
      const LlmTypeConverter();
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
  final DriftGenerationConfig generationConfig;
  final DriftContextConfig contextConfig;
  final List<DriftXmlRule> xmlRules;
  final LlmType apiType;
  final String? selectedOpenAIConfigId;
  final bool enablePreprocessing;
  final String? preprocessingPrompt;
  final String? contextSummary;
  final bool enablePostprocessing;
  final String? postprocessingPrompt;
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
      required this.generationConfig,
      required this.contextConfig,
      required this.xmlRules,
      required this.apiType,
      this.selectedOpenAIConfigId,
      required this.enablePreprocessing,
      this.preprocessingPrompt,
      this.contextSummary,
      required this.enablePostprocessing,
      this.postprocessingPrompt});
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
      map['generation_config'] = Variable<String>(
          $ChatsTable.$convertergenerationConfig.toSql(generationConfig));
    }
    {
      map['context_config'] = Variable<String>(
          $ChatsTable.$convertercontextConfig.toSql(contextConfig));
    }
    {
      map['xml_rules'] =
          Variable<String>($ChatsTable.$converterxmlRules.toSql(xmlRules));
    }
    {
      map['api_type'] =
          Variable<String>($ChatsTable.$converterapiType.toSql(apiType));
    }
    if (!nullToAbsent || selectedOpenAIConfigId != null) {
      map['selected_open_a_i_config_id'] =
          Variable<String>(selectedOpenAIConfigId);
    }
    map['enable_preprocessing'] = Variable<bool>(enablePreprocessing);
    if (!nullToAbsent || preprocessingPrompt != null) {
      map['preprocessing_prompt'] = Variable<String>(preprocessingPrompt);
    }
    if (!nullToAbsent || contextSummary != null) {
      map['context_summary'] = Variable<String>(contextSummary);
    }
    map['enable_postprocessing'] = Variable<bool>(enablePostprocessing);
    if (!nullToAbsent || postprocessingPrompt != null) {
      map['postprocessing_prompt'] = Variable<String>(postprocessingPrompt);
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
      generationConfig: Value(generationConfig),
      contextConfig: Value(contextConfig),
      xmlRules: Value(xmlRules),
      apiType: Value(apiType),
      selectedOpenAIConfigId: selectedOpenAIConfigId == null && nullToAbsent
          ? const Value.absent()
          : Value(selectedOpenAIConfigId),
      enablePreprocessing: Value(enablePreprocessing),
      preprocessingPrompt: preprocessingPrompt == null && nullToAbsent
          ? const Value.absent()
          : Value(preprocessingPrompt),
      contextSummary: contextSummary == null && nullToAbsent
          ? const Value.absent()
          : Value(contextSummary),
      enablePostprocessing: Value(enablePostprocessing),
      postprocessingPrompt: postprocessingPrompt == null && nullToAbsent
          ? const Value.absent()
          : Value(postprocessingPrompt),
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
      generationConfig:
          serializer.fromJson<DriftGenerationConfig>(json['generationConfig']),
      contextConfig:
          serializer.fromJson<DriftContextConfig>(json['contextConfig']),
      xmlRules: serializer.fromJson<List<DriftXmlRule>>(json['xmlRules']),
      apiType: serializer.fromJson<LlmType>(json['apiType']),
      selectedOpenAIConfigId:
          serializer.fromJson<String?>(json['selectedOpenAIConfigId']),
      enablePreprocessing:
          serializer.fromJson<bool>(json['enablePreprocessing']),
      preprocessingPrompt:
          serializer.fromJson<String?>(json['preprocessingPrompt']),
      contextSummary: serializer.fromJson<String?>(json['contextSummary']),
      enablePostprocessing:
          serializer.fromJson<bool>(json['enablePostprocessing']),
      postprocessingPrompt:
          serializer.fromJson<String?>(json['postprocessingPrompt']),
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
      'generationConfig':
          serializer.toJson<DriftGenerationConfig>(generationConfig),
      'contextConfig': serializer.toJson<DriftContextConfig>(contextConfig),
      'xmlRules': serializer.toJson<List<DriftXmlRule>>(xmlRules),
      'apiType': serializer.toJson<LlmType>(apiType),
      'selectedOpenAIConfigId':
          serializer.toJson<String?>(selectedOpenAIConfigId),
      'enablePreprocessing': serializer.toJson<bool>(enablePreprocessing),
      'preprocessingPrompt': serializer.toJson<String?>(preprocessingPrompt),
      'contextSummary': serializer.toJson<String?>(contextSummary),
      'enablePostprocessing': serializer.toJson<bool>(enablePostprocessing),
      'postprocessingPrompt': serializer.toJson<String?>(postprocessingPrompt),
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
          DriftGenerationConfig? generationConfig,
          DriftContextConfig? contextConfig,
          List<DriftXmlRule>? xmlRules,
          LlmType? apiType,
          Value<String?> selectedOpenAIConfigId = const Value.absent(),
          bool? enablePreprocessing,
          Value<String?> preprocessingPrompt = const Value.absent(),
          Value<String?> contextSummary = const Value.absent(),
          bool? enablePostprocessing,
          Value<String?> postprocessingPrompt = const Value.absent()}) =>
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
        generationConfig: generationConfig ?? this.generationConfig,
        contextConfig: contextConfig ?? this.contextConfig,
        xmlRules: xmlRules ?? this.xmlRules,
        apiType: apiType ?? this.apiType,
        selectedOpenAIConfigId: selectedOpenAIConfigId.present
            ? selectedOpenAIConfigId.value
            : this.selectedOpenAIConfigId,
        enablePreprocessing: enablePreprocessing ?? this.enablePreprocessing,
        preprocessingPrompt: preprocessingPrompt.present
            ? preprocessingPrompt.value
            : this.preprocessingPrompt,
        contextSummary:
            contextSummary.present ? contextSummary.value : this.contextSummary,
        enablePostprocessing: enablePostprocessing ?? this.enablePostprocessing,
        postprocessingPrompt: postprocessingPrompt.present
            ? postprocessingPrompt.value
            : this.postprocessingPrompt,
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
      generationConfig: data.generationConfig.present
          ? data.generationConfig.value
          : this.generationConfig,
      contextConfig: data.contextConfig.present
          ? data.contextConfig.value
          : this.contextConfig,
      xmlRules: data.xmlRules.present ? data.xmlRules.value : this.xmlRules,
      apiType: data.apiType.present ? data.apiType.value : this.apiType,
      selectedOpenAIConfigId: data.selectedOpenAIConfigId.present
          ? data.selectedOpenAIConfigId.value
          : this.selectedOpenAIConfigId,
      enablePreprocessing: data.enablePreprocessing.present
          ? data.enablePreprocessing.value
          : this.enablePreprocessing,
      preprocessingPrompt: data.preprocessingPrompt.present
          ? data.preprocessingPrompt.value
          : this.preprocessingPrompt,
      contextSummary: data.contextSummary.present
          ? data.contextSummary.value
          : this.contextSummary,
      enablePostprocessing: data.enablePostprocessing.present
          ? data.enablePostprocessing.value
          : this.enablePostprocessing,
      postprocessingPrompt: data.postprocessingPrompt.present
          ? data.postprocessingPrompt.value
          : this.postprocessingPrompt,
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
          ..write('generationConfig: $generationConfig, ')
          ..write('contextConfig: $contextConfig, ')
          ..write('xmlRules: $xmlRules, ')
          ..write('apiType: $apiType, ')
          ..write('selectedOpenAIConfigId: $selectedOpenAIConfigId, ')
          ..write('enablePreprocessing: $enablePreprocessing, ')
          ..write('preprocessingPrompt: $preprocessingPrompt, ')
          ..write('contextSummary: $contextSummary, ')
          ..write('enablePostprocessing: $enablePostprocessing, ')
          ..write('postprocessingPrompt: $postprocessingPrompt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
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
      generationConfig,
      contextConfig,
      xmlRules,
      apiType,
      selectedOpenAIConfigId,
      enablePreprocessing,
      preprocessingPrompt,
      contextSummary,
      enablePostprocessing,
      postprocessingPrompt);
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
          other.generationConfig == this.generationConfig &&
          other.contextConfig == this.contextConfig &&
          other.xmlRules == this.xmlRules &&
          other.apiType == this.apiType &&
          other.selectedOpenAIConfigId == this.selectedOpenAIConfigId &&
          other.enablePreprocessing == this.enablePreprocessing &&
          other.preprocessingPrompt == this.preprocessingPrompt &&
          other.contextSummary == this.contextSummary &&
          other.enablePostprocessing == this.enablePostprocessing &&
          other.postprocessingPrompt == this.postprocessingPrompt);
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
  final Value<DriftGenerationConfig> generationConfig;
  final Value<DriftContextConfig> contextConfig;
  final Value<List<DriftXmlRule>> xmlRules;
  final Value<LlmType> apiType;
  final Value<String?> selectedOpenAIConfigId;
  final Value<bool> enablePreprocessing;
  final Value<String?> preprocessingPrompt;
  final Value<String?> contextSummary;
  final Value<bool> enablePostprocessing;
  final Value<String?> postprocessingPrompt;
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
    this.generationConfig = const Value.absent(),
    this.contextConfig = const Value.absent(),
    this.xmlRules = const Value.absent(),
    this.apiType = const Value.absent(),
    this.selectedOpenAIConfigId = const Value.absent(),
    this.enablePreprocessing = const Value.absent(),
    this.preprocessingPrompt = const Value.absent(),
    this.contextSummary = const Value.absent(),
    this.enablePostprocessing = const Value.absent(),
    this.postprocessingPrompt = const Value.absent(),
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
    required DriftGenerationConfig generationConfig,
    required DriftContextConfig contextConfig,
    required List<DriftXmlRule> xmlRules,
    required LlmType apiType,
    this.selectedOpenAIConfigId = const Value.absent(),
    this.enablePreprocessing = const Value.absent(),
    this.preprocessingPrompt = const Value.absent(),
    this.contextSummary = const Value.absent(),
    this.enablePostprocessing = const Value.absent(),
    this.postprocessingPrompt = const Value.absent(),
  })  : createdAt = Value(createdAt),
        updatedAt = Value(updatedAt),
        generationConfig = Value(generationConfig),
        contextConfig = Value(contextConfig),
        xmlRules = Value(xmlRules),
        apiType = Value(apiType);
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
    Expression<String>? generationConfig,
    Expression<String>? contextConfig,
    Expression<String>? xmlRules,
    Expression<String>? apiType,
    Expression<String>? selectedOpenAIConfigId,
    Expression<bool>? enablePreprocessing,
    Expression<String>? preprocessingPrompt,
    Expression<String>? contextSummary,
    Expression<bool>? enablePostprocessing,
    Expression<String>? postprocessingPrompt,
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
      if (generationConfig != null) 'generation_config': generationConfig,
      if (contextConfig != null) 'context_config': contextConfig,
      if (xmlRules != null) 'xml_rules': xmlRules,
      if (apiType != null) 'api_type': apiType,
      if (selectedOpenAIConfigId != null)
        'selected_open_a_i_config_id': selectedOpenAIConfigId,
      if (enablePreprocessing != null)
        'enable_preprocessing': enablePreprocessing,
      if (preprocessingPrompt != null)
        'preprocessing_prompt': preprocessingPrompt,
      if (contextSummary != null) 'context_summary': contextSummary,
      if (enablePostprocessing != null)
        'enable_postprocessing': enablePostprocessing,
      if (postprocessingPrompt != null)
        'postprocessing_prompt': postprocessingPrompt,
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
      Value<DriftGenerationConfig>? generationConfig,
      Value<DriftContextConfig>? contextConfig,
      Value<List<DriftXmlRule>>? xmlRules,
      Value<LlmType>? apiType,
      Value<String?>? selectedOpenAIConfigId,
      Value<bool>? enablePreprocessing,
      Value<String?>? preprocessingPrompt,
      Value<String?>? contextSummary,
      Value<bool>? enablePostprocessing,
      Value<String?>? postprocessingPrompt}) {
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
      generationConfig: generationConfig ?? this.generationConfig,
      contextConfig: contextConfig ?? this.contextConfig,
      xmlRules: xmlRules ?? this.xmlRules,
      apiType: apiType ?? this.apiType,
      selectedOpenAIConfigId:
          selectedOpenAIConfigId ?? this.selectedOpenAIConfigId,
      enablePreprocessing: enablePreprocessing ?? this.enablePreprocessing,
      preprocessingPrompt: preprocessingPrompt ?? this.preprocessingPrompt,
      contextSummary: contextSummary ?? this.contextSummary,
      enablePostprocessing: enablePostprocessing ?? this.enablePostprocessing,
      postprocessingPrompt: postprocessingPrompt ?? this.postprocessingPrompt,
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
    if (generationConfig.present) {
      map['generation_config'] = Variable<String>(
          $ChatsTable.$convertergenerationConfig.toSql(generationConfig.value));
    }
    if (contextConfig.present) {
      map['context_config'] = Variable<String>(
          $ChatsTable.$convertercontextConfig.toSql(contextConfig.value));
    }
    if (xmlRules.present) {
      map['xml_rules'] = Variable<String>(
          $ChatsTable.$converterxmlRules.toSql(xmlRules.value));
    }
    if (apiType.present) {
      map['api_type'] =
          Variable<String>($ChatsTable.$converterapiType.toSql(apiType.value));
    }
    if (selectedOpenAIConfigId.present) {
      map['selected_open_a_i_config_id'] =
          Variable<String>(selectedOpenAIConfigId.value);
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
    if (enablePostprocessing.present) {
      map['enable_postprocessing'] = Variable<bool>(enablePostprocessing.value);
    }
    if (postprocessingPrompt.present) {
      map['postprocessing_prompt'] =
          Variable<String>(postprocessingPrompt.value);
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
          ..write('generationConfig: $generationConfig, ')
          ..write('contextConfig: $contextConfig, ')
          ..write('xmlRules: $xmlRules, ')
          ..write('apiType: $apiType, ')
          ..write('selectedOpenAIConfigId: $selectedOpenAIConfigId, ')
          ..write('enablePreprocessing: $enablePreprocessing, ')
          ..write('preprocessingPrompt: $preprocessingPrompt, ')
          ..write('contextSummary: $contextSummary, ')
          ..write('enablePostprocessing: $enablePostprocessing, ')
          ..write('postprocessingPrompt: $postprocessingPrompt')
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
  @override
  List<GeneratedColumn> get $columns =>
      [id, chatId, partsJson, role, timestamp, originalXmlContent];
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
  const MessageData(
      {required this.id,
      required this.chatId,
      required this.partsJson,
      required this.role,
      required this.timestamp,
      this.originalXmlContent});
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
    };
  }

  MessageData copyWith(
          {int? id,
          int? chatId,
          String? partsJson,
          MessageRole? role,
          DateTime? timestamp,
          Value<String?> originalXmlContent = const Value.absent()}) =>
      MessageData(
        id: id ?? this.id,
        chatId: chatId ?? this.chatId,
        partsJson: partsJson ?? this.partsJson,
        role: role ?? this.role,
        timestamp: timestamp ?? this.timestamp,
        originalXmlContent: originalXmlContent.present
            ? originalXmlContent.value
            : this.originalXmlContent,
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
          ..write('originalXmlContent: $originalXmlContent')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, chatId, partsJson, role, timestamp, originalXmlContent);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageData &&
          other.id == this.id &&
          other.chatId == this.chatId &&
          other.partsJson == this.partsJson &&
          other.role == this.role &&
          other.timestamp == this.timestamp &&
          other.originalXmlContent == this.originalXmlContent);
}

class MessagesCompanion extends UpdateCompanion<MessageData> {
  final Value<int> id;
  final Value<int> chatId;
  final Value<String> partsJson;
  final Value<MessageRole> role;
  final Value<DateTime> timestamp;
  final Value<String?> originalXmlContent;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.chatId = const Value.absent(),
    this.partsJson = const Value.absent(),
    this.role = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.originalXmlContent = const Value.absent(),
  });
  MessagesCompanion.insert({
    this.id = const Value.absent(),
    required int chatId,
    required String partsJson,
    required MessageRole role,
    required DateTime timestamp,
    this.originalXmlContent = const Value.absent(),
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
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (chatId != null) 'chat_id': chatId,
      if (partsJson != null) 'raw_text': partsJson,
      if (role != null) 'role': role,
      if (timestamp != null) 'timestamp': timestamp,
      if (originalXmlContent != null)
        'original_xml_content': originalXmlContent,
    });
  }

  MessagesCompanion copyWith(
      {Value<int>? id,
      Value<int>? chatId,
      Value<String>? partsJson,
      Value<MessageRole>? role,
      Value<DateTime>? timestamp,
      Value<String?>? originalXmlContent}) {
    return MessagesCompanion(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      partsJson: partsJson ?? this.partsJson,
      role: role ?? this.role,
      timestamp: timestamp ?? this.timestamp,
      originalXmlContent: originalXmlContent ?? this.originalXmlContent,
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
          ..write('originalXmlContent: $originalXmlContent')
          ..write(')'))
        .toString();
  }
}

class $GeminiApiKeysTable extends GeminiApiKeys
    with TableInfo<$GeminiApiKeysTable, GeminiApiKey> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GeminiApiKeysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _apiKeyMeta = const VerificationMeta('apiKey');
  @override
  late final GeneratedColumn<String> apiKey = GeneratedColumn<String>(
      'api_key', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [id, apiKey, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gemini_api_keys';
  @override
  VerificationContext validateIntegrity(Insertable<GeminiApiKey> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('api_key')) {
      context.handle(_apiKeyMeta,
          apiKey.isAcceptableOrUnknown(data['api_key']!, _apiKeyMeta));
    } else if (isInserting) {
      context.missing(_apiKeyMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GeminiApiKey map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GeminiApiKey(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      apiKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}api_key'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $GeminiApiKeysTable createAlias(String alias) {
    return $GeminiApiKeysTable(attachedDatabase, alias);
  }
}

class GeminiApiKey extends DataClass implements Insertable<GeminiApiKey> {
  final int id;
  final String apiKey;
  final DateTime createdAt;
  const GeminiApiKey(
      {required this.id, required this.apiKey, required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['api_key'] = Variable<String>(apiKey);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  GeminiApiKeysCompanion toCompanion(bool nullToAbsent) {
    return GeminiApiKeysCompanion(
      id: Value(id),
      apiKey: Value(apiKey),
      createdAt: Value(createdAt),
    );
  }

  factory GeminiApiKey.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GeminiApiKey(
      id: serializer.fromJson<int>(json['id']),
      apiKey: serializer.fromJson<String>(json['apiKey']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'apiKey': serializer.toJson<String>(apiKey),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  GeminiApiKey copyWith({int? id, String? apiKey, DateTime? createdAt}) =>
      GeminiApiKey(
        id: id ?? this.id,
        apiKey: apiKey ?? this.apiKey,
        createdAt: createdAt ?? this.createdAt,
      );
  GeminiApiKey copyWithCompanion(GeminiApiKeysCompanion data) {
    return GeminiApiKey(
      id: data.id.present ? data.id.value : this.id,
      apiKey: data.apiKey.present ? data.apiKey.value : this.apiKey,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GeminiApiKey(')
          ..write('id: $id, ')
          ..write('apiKey: $apiKey, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, apiKey, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GeminiApiKey &&
          other.id == this.id &&
          other.apiKey == this.apiKey &&
          other.createdAt == this.createdAt);
}

class GeminiApiKeysCompanion extends UpdateCompanion<GeminiApiKey> {
  final Value<int> id;
  final Value<String> apiKey;
  final Value<DateTime> createdAt;
  const GeminiApiKeysCompanion({
    this.id = const Value.absent(),
    this.apiKey = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  GeminiApiKeysCompanion.insert({
    this.id = const Value.absent(),
    required String apiKey,
    this.createdAt = const Value.absent(),
  }) : apiKey = Value(apiKey);
  static Insertable<GeminiApiKey> custom({
    Expression<int>? id,
    Expression<String>? apiKey,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (apiKey != null) 'api_key': apiKey,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  GeminiApiKeysCompanion copyWith(
      {Value<int>? id, Value<String>? apiKey, Value<DateTime>? createdAt}) {
    return GeminiApiKeysCompanion(
      id: id ?? this.id,
      apiKey: apiKey ?? this.apiKey,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (apiKey.present) {
      map['api_key'] = Variable<String>(apiKey.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GeminiApiKeysCompanion(')
          ..write('id: $id, ')
          ..write('apiKey: $apiKey, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $OpenAIConfigsTable extends OpenAIConfigs
    with TableInfo<$OpenAIConfigsTable, OpenAIConfig> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OpenAIConfigsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _baseUrlMeta =
      const VerificationMeta('baseUrl');
  @override
  late final GeneratedColumn<String> baseUrl = GeneratedColumn<String>(
      'base_url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _apiKeyMeta = const VerificationMeta('apiKey');
  @override
  late final GeneratedColumn<String> apiKey = GeneratedColumn<String>(
      'api_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
      'model', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _temperatureMeta =
      const VerificationMeta('temperature');
  @override
  late final GeneratedColumn<double> temperature = GeneratedColumn<double>(
      'temperature', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _maxTokensMeta =
      const VerificationMeta('maxTokens');
  @override
  late final GeneratedColumn<int> maxTokens = GeneratedColumn<int>(
      'max_tokens', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
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
        baseUrl,
        apiKey,
        model,
        temperature,
        maxTokens,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'open_a_i_configs';
  @override
  VerificationContext validateIntegrity(Insertable<OpenAIConfig> instance,
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
    if (data.containsKey('base_url')) {
      context.handle(_baseUrlMeta,
          baseUrl.isAcceptableOrUnknown(data['base_url']!, _baseUrlMeta));
    } else if (isInserting) {
      context.missing(_baseUrlMeta);
    }
    if (data.containsKey('api_key')) {
      context.handle(_apiKeyMeta,
          apiKey.isAcceptableOrUnknown(data['api_key']!, _apiKeyMeta));
    } else if (isInserting) {
      context.missing(_apiKeyMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
          _modelMeta, model.isAcceptableOrUnknown(data['model']!, _modelMeta));
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('temperature')) {
      context.handle(
          _temperatureMeta,
          temperature.isAcceptableOrUnknown(
              data['temperature']!, _temperatureMeta));
    }
    if (data.containsKey('max_tokens')) {
      context.handle(_maxTokensMeta,
          maxTokens.isAcceptableOrUnknown(data['max_tokens']!, _maxTokensMeta));
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
  OpenAIConfig map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OpenAIConfig(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      baseUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}base_url'])!,
      apiKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}api_key'])!,
      model: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}model'])!,
      temperature: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}temperature']),
      maxTokens: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}max_tokens']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $OpenAIConfigsTable createAlias(String alias) {
    return $OpenAIConfigsTable(attachedDatabase, alias);
  }
}

class OpenAIConfig extends DataClass implements Insertable<OpenAIConfig> {
  final String id;
  final String name;
  final String baseUrl;
  final String apiKey;
  final String model;
  final double? temperature;
  final int? maxTokens;
  final DateTime createdAt;
  final DateTime updatedAt;
  const OpenAIConfig(
      {required this.id,
      required this.name,
      required this.baseUrl,
      required this.apiKey,
      required this.model,
      this.temperature,
      this.maxTokens,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['base_url'] = Variable<String>(baseUrl);
    map['api_key'] = Variable<String>(apiKey);
    map['model'] = Variable<String>(model);
    if (!nullToAbsent || temperature != null) {
      map['temperature'] = Variable<double>(temperature);
    }
    if (!nullToAbsent || maxTokens != null) {
      map['max_tokens'] = Variable<int>(maxTokens);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  OpenAIConfigsCompanion toCompanion(bool nullToAbsent) {
    return OpenAIConfigsCompanion(
      id: Value(id),
      name: Value(name),
      baseUrl: Value(baseUrl),
      apiKey: Value(apiKey),
      model: Value(model),
      temperature: temperature == null && nullToAbsent
          ? const Value.absent()
          : Value(temperature),
      maxTokens: maxTokens == null && nullToAbsent
          ? const Value.absent()
          : Value(maxTokens),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory OpenAIConfig.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OpenAIConfig(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      baseUrl: serializer.fromJson<String>(json['baseUrl']),
      apiKey: serializer.fromJson<String>(json['apiKey']),
      model: serializer.fromJson<String>(json['model']),
      temperature: serializer.fromJson<double?>(json['temperature']),
      maxTokens: serializer.fromJson<int?>(json['maxTokens']),
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
      'baseUrl': serializer.toJson<String>(baseUrl),
      'apiKey': serializer.toJson<String>(apiKey),
      'model': serializer.toJson<String>(model),
      'temperature': serializer.toJson<double?>(temperature),
      'maxTokens': serializer.toJson<int?>(maxTokens),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  OpenAIConfig copyWith(
          {String? id,
          String? name,
          String? baseUrl,
          String? apiKey,
          String? model,
          Value<double?> temperature = const Value.absent(),
          Value<int?> maxTokens = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      OpenAIConfig(
        id: id ?? this.id,
        name: name ?? this.name,
        baseUrl: baseUrl ?? this.baseUrl,
        apiKey: apiKey ?? this.apiKey,
        model: model ?? this.model,
        temperature: temperature.present ? temperature.value : this.temperature,
        maxTokens: maxTokens.present ? maxTokens.value : this.maxTokens,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  OpenAIConfig copyWithCompanion(OpenAIConfigsCompanion data) {
    return OpenAIConfig(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      baseUrl: data.baseUrl.present ? data.baseUrl.value : this.baseUrl,
      apiKey: data.apiKey.present ? data.apiKey.value : this.apiKey,
      model: data.model.present ? data.model.value : this.model,
      temperature:
          data.temperature.present ? data.temperature.value : this.temperature,
      maxTokens: data.maxTokens.present ? data.maxTokens.value : this.maxTokens,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OpenAIConfig(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('apiKey: $apiKey, ')
          ..write('model: $model, ')
          ..write('temperature: $temperature, ')
          ..write('maxTokens: $maxTokens, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, baseUrl, apiKey, model, temperature,
      maxTokens, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OpenAIConfig &&
          other.id == this.id &&
          other.name == this.name &&
          other.baseUrl == this.baseUrl &&
          other.apiKey == this.apiKey &&
          other.model == this.model &&
          other.temperature == this.temperature &&
          other.maxTokens == this.maxTokens &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class OpenAIConfigsCompanion extends UpdateCompanion<OpenAIConfig> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> baseUrl;
  final Value<String> apiKey;
  final Value<String> model;
  final Value<double?> temperature;
  final Value<int?> maxTokens;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const OpenAIConfigsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.apiKey = const Value.absent(),
    this.model = const Value.absent(),
    this.temperature = const Value.absent(),
    this.maxTokens = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OpenAIConfigsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String baseUrl,
    required String apiKey,
    required String model,
    this.temperature = const Value.absent(),
    this.maxTokens = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : name = Value(name),
        baseUrl = Value(baseUrl),
        apiKey = Value(apiKey),
        model = Value(model);
  static Insertable<OpenAIConfig> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? baseUrl,
    Expression<String>? apiKey,
    Expression<String>? model,
    Expression<double>? temperature,
    Expression<int>? maxTokens,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (baseUrl != null) 'base_url': baseUrl,
      if (apiKey != null) 'api_key': apiKey,
      if (model != null) 'model': model,
      if (temperature != null) 'temperature': temperature,
      if (maxTokens != null) 'max_tokens': maxTokens,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OpenAIConfigsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? baseUrl,
      Value<String>? apiKey,
      Value<String>? model,
      Value<double?>? temperature,
      Value<int?>? maxTokens,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return OpenAIConfigsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
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
    if (baseUrl.present) {
      map['base_url'] = Variable<String>(baseUrl.value);
    }
    if (apiKey.present) {
      map['api_key'] = Variable<String>(apiKey.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (temperature.present) {
      map['temperature'] = Variable<double>(temperature.value);
    }
    if (maxTokens.present) {
      map['max_tokens'] = Variable<int>(maxTokens.value);
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
    return (StringBuffer('OpenAIConfigsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('apiKey: $apiKey, ')
          ..write('model: $model, ')
          ..write('temperature: $temperature, ')
          ..write('maxTokens: $maxTokens, ')
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
  late final $GeminiApiKeysTable geminiApiKeys = $GeminiApiKeysTable(this);
  late final $OpenAIConfigsTable openAIConfigs = $OpenAIConfigsTable(this);
  late final ChatDao chatDao = ChatDao(this as AppDatabase);
  late final MessageDao messageDao = MessageDao(this as AppDatabase);
  late final ApiConfigDao apiConfigDao = ApiConfigDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [chats, messages, geminiApiKeys, openAIConfigs];
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
  required DriftGenerationConfig generationConfig,
  required DriftContextConfig contextConfig,
  required List<DriftXmlRule> xmlRules,
  required LlmType apiType,
  Value<String?> selectedOpenAIConfigId,
  Value<bool> enablePreprocessing,
  Value<String?> preprocessingPrompt,
  Value<String?> contextSummary,
  Value<bool> enablePostprocessing,
  Value<String?> postprocessingPrompt,
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
  Value<DriftGenerationConfig> generationConfig,
  Value<DriftContextConfig> contextConfig,
  Value<List<DriftXmlRule>> xmlRules,
  Value<LlmType> apiType,
  Value<String?> selectedOpenAIConfigId,
  Value<bool> enablePreprocessing,
  Value<String?> preprocessingPrompt,
  Value<String?> contextSummary,
  Value<bool> enablePostprocessing,
  Value<String?> postprocessingPrompt,
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

  ColumnWithTypeConverterFilters<DriftGenerationConfig, DriftGenerationConfig,
          String>
      get generationConfig => $composableBuilder(
          column: $table.generationConfig,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnWithTypeConverterFilters<DriftContextConfig, DriftContextConfig, String>
      get contextConfig => $composableBuilder(
          column: $table.contextConfig,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnWithTypeConverterFilters<List<DriftXmlRule>, List<DriftXmlRule>, String>
      get xmlRules => $composableBuilder(
          column: $table.xmlRules,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnWithTypeConverterFilters<LlmType, LlmType, String> get apiType =>
      $composableBuilder(
          column: $table.apiType,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get selectedOpenAIConfigId => $composableBuilder(
      column: $table.selectedOpenAIConfigId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get enablePreprocessing => $composableBuilder(
      column: $table.enablePreprocessing,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get preprocessingPrompt => $composableBuilder(
      column: $table.preprocessingPrompt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contextSummary => $composableBuilder(
      column: $table.contextSummary,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get enablePostprocessing => $composableBuilder(
      column: $table.enablePostprocessing,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get postprocessingPrompt => $composableBuilder(
      column: $table.postprocessingPrompt,
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

  ColumnOrderings<String> get generationConfig => $composableBuilder(
      column: $table.generationConfig,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contextConfig => $composableBuilder(
      column: $table.contextConfig,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get xmlRules => $composableBuilder(
      column: $table.xmlRules, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get apiType => $composableBuilder(
      column: $table.apiType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get selectedOpenAIConfigId => $composableBuilder(
      column: $table.selectedOpenAIConfigId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get enablePreprocessing => $composableBuilder(
      column: $table.enablePreprocessing,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get preprocessingPrompt => $composableBuilder(
      column: $table.preprocessingPrompt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contextSummary => $composableBuilder(
      column: $table.contextSummary,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get enablePostprocessing => $composableBuilder(
      column: $table.enablePostprocessing,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get postprocessingPrompt => $composableBuilder(
      column: $table.postprocessingPrompt,
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

  GeneratedColumnWithTypeConverter<DriftGenerationConfig, String>
      get generationConfig => $composableBuilder(
          column: $table.generationConfig, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DriftContextConfig, String>
      get contextConfig => $composableBuilder(
          column: $table.contextConfig, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<DriftXmlRule>, String> get xmlRules =>
      $composableBuilder(column: $table.xmlRules, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LlmType, String> get apiType =>
      $composableBuilder(column: $table.apiType, builder: (column) => column);

  GeneratedColumn<String> get selectedOpenAIConfigId => $composableBuilder(
      column: $table.selectedOpenAIConfigId, builder: (column) => column);

  GeneratedColumn<bool> get enablePreprocessing => $composableBuilder(
      column: $table.enablePreprocessing, builder: (column) => column);

  GeneratedColumn<String> get preprocessingPrompt => $composableBuilder(
      column: $table.preprocessingPrompt, builder: (column) => column);

  GeneratedColumn<String> get contextSummary => $composableBuilder(
      column: $table.contextSummary, builder: (column) => column);

  GeneratedColumn<bool> get enablePostprocessing => $composableBuilder(
      column: $table.enablePostprocessing, builder: (column) => column);

  GeneratedColumn<String> get postprocessingPrompt => $composableBuilder(
      column: $table.postprocessingPrompt, builder: (column) => column);

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
            Value<DriftGenerationConfig> generationConfig =
                const Value.absent(),
            Value<DriftContextConfig> contextConfig = const Value.absent(),
            Value<List<DriftXmlRule>> xmlRules = const Value.absent(),
            Value<LlmType> apiType = const Value.absent(),
            Value<String?> selectedOpenAIConfigId = const Value.absent(),
            Value<bool> enablePreprocessing = const Value.absent(),
            Value<String?> preprocessingPrompt = const Value.absent(),
            Value<String?> contextSummary = const Value.absent(),
            Value<bool> enablePostprocessing = const Value.absent(),
            Value<String?> postprocessingPrompt = const Value.absent(),
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
            generationConfig: generationConfig,
            contextConfig: contextConfig,
            xmlRules: xmlRules,
            apiType: apiType,
            selectedOpenAIConfigId: selectedOpenAIConfigId,
            enablePreprocessing: enablePreprocessing,
            preprocessingPrompt: preprocessingPrompt,
            contextSummary: contextSummary,
            enablePostprocessing: enablePostprocessing,
            postprocessingPrompt: postprocessingPrompt,
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
            required DriftGenerationConfig generationConfig,
            required DriftContextConfig contextConfig,
            required List<DriftXmlRule> xmlRules,
            required LlmType apiType,
            Value<String?> selectedOpenAIConfigId = const Value.absent(),
            Value<bool> enablePreprocessing = const Value.absent(),
            Value<String?> preprocessingPrompt = const Value.absent(),
            Value<String?> contextSummary = const Value.absent(),
            Value<bool> enablePostprocessing = const Value.absent(),
            Value<String?> postprocessingPrompt = const Value.absent(),
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
            generationConfig: generationConfig,
            contextConfig: contextConfig,
            xmlRules: xmlRules,
            apiType: apiType,
            selectedOpenAIConfigId: selectedOpenAIConfigId,
            enablePreprocessing: enablePreprocessing,
            preprocessingPrompt: preprocessingPrompt,
            contextSummary: contextSummary,
            enablePostprocessing: enablePostprocessing,
            postprocessingPrompt: postprocessingPrompt,
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
});
typedef $$MessagesTableUpdateCompanionBuilder = MessagesCompanion Function({
  Value<int> id,
  Value<int> chatId,
  Value<String> partsJson,
  Value<MessageRole> role,
  Value<DateTime> timestamp,
  Value<String?> originalXmlContent,
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
          }) =>
              MessagesCompanion(
            id: id,
            chatId: chatId,
            partsJson: partsJson,
            role: role,
            timestamp: timestamp,
            originalXmlContent: originalXmlContent,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int chatId,
            required String partsJson,
            required MessageRole role,
            required DateTime timestamp,
            Value<String?> originalXmlContent = const Value.absent(),
          }) =>
              MessagesCompanion.insert(
            id: id,
            chatId: chatId,
            partsJson: partsJson,
            role: role,
            timestamp: timestamp,
            originalXmlContent: originalXmlContent,
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
typedef $$GeminiApiKeysTableCreateCompanionBuilder = GeminiApiKeysCompanion
    Function({
  Value<int> id,
  required String apiKey,
  Value<DateTime> createdAt,
});
typedef $$GeminiApiKeysTableUpdateCompanionBuilder = GeminiApiKeysCompanion
    Function({
  Value<int> id,
  Value<String> apiKey,
  Value<DateTime> createdAt,
});

class $$GeminiApiKeysTableFilterComposer
    extends Composer<_$AppDatabase, $GeminiApiKeysTable> {
  $$GeminiApiKeysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get apiKey => $composableBuilder(
      column: $table.apiKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$GeminiApiKeysTableOrderingComposer
    extends Composer<_$AppDatabase, $GeminiApiKeysTable> {
  $$GeminiApiKeysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get apiKey => $composableBuilder(
      column: $table.apiKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$GeminiApiKeysTableAnnotationComposer
    extends Composer<_$AppDatabase, $GeminiApiKeysTable> {
  $$GeminiApiKeysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get apiKey =>
      $composableBuilder(column: $table.apiKey, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$GeminiApiKeysTableTableManager extends RootTableManager<
    _$AppDatabase,
    $GeminiApiKeysTable,
    GeminiApiKey,
    $$GeminiApiKeysTableFilterComposer,
    $$GeminiApiKeysTableOrderingComposer,
    $$GeminiApiKeysTableAnnotationComposer,
    $$GeminiApiKeysTableCreateCompanionBuilder,
    $$GeminiApiKeysTableUpdateCompanionBuilder,
    (
      GeminiApiKey,
      BaseReferences<_$AppDatabase, $GeminiApiKeysTable, GeminiApiKey>
    ),
    GeminiApiKey,
    PrefetchHooks Function()> {
  $$GeminiApiKeysTableTableManager(_$AppDatabase db, $GeminiApiKeysTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GeminiApiKeysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GeminiApiKeysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GeminiApiKeysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> apiKey = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              GeminiApiKeysCompanion(
            id: id,
            apiKey: apiKey,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String apiKey,
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              GeminiApiKeysCompanion.insert(
            id: id,
            apiKey: apiKey,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$GeminiApiKeysTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $GeminiApiKeysTable,
    GeminiApiKey,
    $$GeminiApiKeysTableFilterComposer,
    $$GeminiApiKeysTableOrderingComposer,
    $$GeminiApiKeysTableAnnotationComposer,
    $$GeminiApiKeysTableCreateCompanionBuilder,
    $$GeminiApiKeysTableUpdateCompanionBuilder,
    (
      GeminiApiKey,
      BaseReferences<_$AppDatabase, $GeminiApiKeysTable, GeminiApiKey>
    ),
    GeminiApiKey,
    PrefetchHooks Function()>;
typedef $$OpenAIConfigsTableCreateCompanionBuilder = OpenAIConfigsCompanion
    Function({
  Value<String> id,
  required String name,
  required String baseUrl,
  required String apiKey,
  required String model,
  Value<double?> temperature,
  Value<int?> maxTokens,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$OpenAIConfigsTableUpdateCompanionBuilder = OpenAIConfigsCompanion
    Function({
  Value<String> id,
  Value<String> name,
  Value<String> baseUrl,
  Value<String> apiKey,
  Value<String> model,
  Value<double?> temperature,
  Value<int?> maxTokens,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$OpenAIConfigsTableFilterComposer
    extends Composer<_$AppDatabase, $OpenAIConfigsTable> {
  $$OpenAIConfigsTableFilterComposer({
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

  ColumnFilters<String> get baseUrl => $composableBuilder(
      column: $table.baseUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get apiKey => $composableBuilder(
      column: $table.apiKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get model => $composableBuilder(
      column: $table.model, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get temperature => $composableBuilder(
      column: $table.temperature, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get maxTokens => $composableBuilder(
      column: $table.maxTokens, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$OpenAIConfigsTableOrderingComposer
    extends Composer<_$AppDatabase, $OpenAIConfigsTable> {
  $$OpenAIConfigsTableOrderingComposer({
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

  ColumnOrderings<String> get baseUrl => $composableBuilder(
      column: $table.baseUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get apiKey => $composableBuilder(
      column: $table.apiKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get model => $composableBuilder(
      column: $table.model, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get temperature => $composableBuilder(
      column: $table.temperature, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get maxTokens => $composableBuilder(
      column: $table.maxTokens, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$OpenAIConfigsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OpenAIConfigsTable> {
  $$OpenAIConfigsTableAnnotationComposer({
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

  GeneratedColumn<String> get baseUrl =>
      $composableBuilder(column: $table.baseUrl, builder: (column) => column);

  GeneratedColumn<String> get apiKey =>
      $composableBuilder(column: $table.apiKey, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<double> get temperature => $composableBuilder(
      column: $table.temperature, builder: (column) => column);

  GeneratedColumn<int> get maxTokens =>
      $composableBuilder(column: $table.maxTokens, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$OpenAIConfigsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OpenAIConfigsTable,
    OpenAIConfig,
    $$OpenAIConfigsTableFilterComposer,
    $$OpenAIConfigsTableOrderingComposer,
    $$OpenAIConfigsTableAnnotationComposer,
    $$OpenAIConfigsTableCreateCompanionBuilder,
    $$OpenAIConfigsTableUpdateCompanionBuilder,
    (
      OpenAIConfig,
      BaseReferences<_$AppDatabase, $OpenAIConfigsTable, OpenAIConfig>
    ),
    OpenAIConfig,
    PrefetchHooks Function()> {
  $$OpenAIConfigsTableTableManager(_$AppDatabase db, $OpenAIConfigsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OpenAIConfigsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OpenAIConfigsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OpenAIConfigsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> baseUrl = const Value.absent(),
            Value<String> apiKey = const Value.absent(),
            Value<String> model = const Value.absent(),
            Value<double?> temperature = const Value.absent(),
            Value<int?> maxTokens = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OpenAIConfigsCompanion(
            id: id,
            name: name,
            baseUrl: baseUrl,
            apiKey: apiKey,
            model: model,
            temperature: temperature,
            maxTokens: maxTokens,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<String> id = const Value.absent(),
            required String name,
            required String baseUrl,
            required String apiKey,
            required String model,
            Value<double?> temperature = const Value.absent(),
            Value<int?> maxTokens = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OpenAIConfigsCompanion.insert(
            id: id,
            name: name,
            baseUrl: baseUrl,
            apiKey: apiKey,
            model: model,
            temperature: temperature,
            maxTokens: maxTokens,
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

typedef $$OpenAIConfigsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OpenAIConfigsTable,
    OpenAIConfig,
    $$OpenAIConfigsTableFilterComposer,
    $$OpenAIConfigsTableOrderingComposer,
    $$OpenAIConfigsTableAnnotationComposer,
    $$OpenAIConfigsTableCreateCompanionBuilder,
    $$OpenAIConfigsTableUpdateCompanionBuilder,
    (
      OpenAIConfig,
      BaseReferences<_$AppDatabase, $OpenAIConfigsTable, OpenAIConfig>
    ),
    OpenAIConfig,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ChatsTableTableManager get chats =>
      $$ChatsTableTableManager(_db, _db.chats);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$GeminiApiKeysTableTableManager get geminiApiKeys =>
      $$GeminiApiKeysTableTableManager(_db, _db.geminiApiKeys);
  $$OpenAIConfigsTableTableManager get openAIConfigs =>
      $$OpenAIConfigsTableTableManager(_db, _db.openAIConfigs);
}

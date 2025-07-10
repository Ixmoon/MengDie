import 'package:drift/drift.dart' show Value;
import 'enums.dart';
import '../services/xml_processor.dart'; // Import for text processing

// Import the new Drift-specific models and enums
import '../data/models/drift_context_config.dart';
import '../data/models/drift_xml_rule.dart';
import '../data/common_enums.dart' as drift_enums;
import '../data/app_database.dart'; // For ChatData, ChatsCompanion

// These classes now represent the application's domain models.

// --- 聊天会话模型 ---
class Chat {
  int id = 0; // Placeholder, will be set by Drift
  String? title;
  String? systemPrompt;
  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
  String? coverImageBase64;
  String? backgroundImagePath;

  int? orderIndex;
  bool isFolder = false;
  int? parentFolderId;

  // --- Refactored Fields ---
  String? apiConfigId; // Replaces selectedOpenAIConfigId
  DriftContextConfig contextConfig = DriftContextConfig();
  List<DriftXmlRule> xmlRules = [];

  // --- 新增字段 ---
  bool enablePreprocessing = false;
  String? preprocessingPrompt;
  String? contextSummary;
  String? preprocessingApiConfigId;
  bool enableSecondaryXml = false;
  String? secondaryXmlPrompt;
  String? secondaryXmlApiConfigId;
  String? continuePrompt;
  
  // Legacy fields for migration
  drift_enums.LlmType? apiType;
  Map<String, dynamic>? generationConfig;
  // --- 结束 ---

  Chat();

  // 从 Drift Data Class 创建业务模型的工厂构造函数
  factory Chat.fromData(ChatData data) {
    return Chat()
      ..id = data.id
      ..title = data.title
      ..systemPrompt = data.systemPrompt
      ..createdAt = data.createdAt
      ..updatedAt = data.updatedAt
      ..coverImageBase64 = data.coverImageBase64
      ..backgroundImagePath = data.backgroundImagePath
      ..orderIndex = data.orderIndex
      ..isFolder = data.isFolder
      ..parentFolderId = data.parentFolderId
      ..apiConfigId = data.apiConfigId
      ..contextConfig = data.contextConfig
      ..xmlRules = data.xmlRules
      ..enablePreprocessing = data.enablePreprocessing ?? false
      ..preprocessingPrompt = data.preprocessingPrompt
      ..contextSummary = data.contextSummary
      ..preprocessingApiConfigId = data.preprocessingApiConfigId
      ..enableSecondaryXml = data.enableSecondaryXml ?? false
      ..secondaryXmlPrompt = data.secondaryXmlPrompt
      ..secondaryXmlApiConfigId = data.secondaryXmlApiConfigId
      ..continuePrompt = data.continuePrompt
      ..generationConfig = data.generationConfig
      ..apiType = data.apiType;
  }

  // 将业务模型转换为 Drift Companion Class 的方法
  ChatsCompanion toCompanion({bool updateTime = true, bool forInsert = false}) {
    final newUpdatedAt = updateTime ? DateTime.now() : updatedAt;
    
    return ChatsCompanion(
      id: forInsert ? const Value.absent() : Value(id),
      title: Value(title),
      systemPrompt: Value(systemPrompt),
      createdAt: Value(createdAt),
      updatedAt: Value(newUpdatedAt),
      coverImageBase64: Value(coverImageBase64),
      backgroundImagePath: Value(backgroundImagePath),
      orderIndex: Value(orderIndex),
      isFolder: Value(isFolder),
      parentFolderId: Value(parentFolderId),
      apiConfigId: Value(apiConfigId),
      contextConfig: Value(contextConfig),
      xmlRules: Value(xmlRules),
      enablePreprocessing: Value(enablePreprocessing),
      preprocessingPrompt: Value(preprocessingPrompt),
      contextSummary: Value(contextSummary),
      preprocessingApiConfigId: Value(preprocessingApiConfigId),
      enableSecondaryXml: Value(enableSecondaryXml),
      secondaryXmlPrompt: Value(secondaryXmlPrompt),
      secondaryXmlApiConfigId: Value(secondaryXmlApiConfigId),
      continuePrompt: Value(continuePrompt),
      generationConfig: Value(generationConfig),
      apiType: Value(apiType),
    );
  }

  // copyWith method to create a modified copy of a Chat instance
  Chat copyWith({
    int? id,
    String? title,
    String? systemPrompt,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<String?>? coverImageBase64,
    Value<String?>? backgroundImagePath,
    Value<int?>? orderIndex,
    bool? isFolder,
    Value<int?>? parentFolderId,
    Value<String?>? apiConfigId,
    DriftContextConfig? contextConfig,
    List<DriftXmlRule>? xmlRules,
    bool? enablePreprocessing,
    Value<String?>? preprocessingPrompt,
    Value<String?>? contextSummary,
    Value<String?>? preprocessingApiConfigId,
    bool? enableSecondaryXml,
    Value<String?>? secondaryXmlPrompt,
    Value<String?>? secondaryXmlApiConfigId,
    Value<String?>? continuePrompt,
    Value<Map<String, dynamic>?>? generationConfig,
    drift_enums.LlmType? apiType,
  }) {
    final newChat = Chat()
      ..id = id ?? this.id
      ..title = title ?? this.title
      ..systemPrompt = systemPrompt ?? this.systemPrompt
      ..createdAt = createdAt ?? this.createdAt
      ..updatedAt = updatedAt ?? this.updatedAt
      ..coverImageBase64 = coverImageBase64 != null ? coverImageBase64.value : this.coverImageBase64
      ..backgroundImagePath = backgroundImagePath != null ? backgroundImagePath.value : this.backgroundImagePath
      ..orderIndex = orderIndex != null ? orderIndex.value : this.orderIndex
      ..isFolder = isFolder ?? this.isFolder
      ..parentFolderId = parentFolderId != null ? parentFolderId.value : this.parentFolderId
      ..apiConfigId = apiConfigId != null ? apiConfigId.value : this.apiConfigId
      ..contextConfig = contextConfig ?? this.contextConfig.copyWith()
      ..xmlRules = xmlRules ?? List<DriftXmlRule>.from(this.xmlRules)
      ..enablePreprocessing = enablePreprocessing ?? this.enablePreprocessing
      ..preprocessingPrompt = preprocessingPrompt != null ? preprocessingPrompt.value : this.preprocessingPrompt
      ..contextSummary = contextSummary != null ? contextSummary.value : this.contextSummary
      ..preprocessingApiConfigId = preprocessingApiConfigId != null ? preprocessingApiConfigId.value : this.preprocessingApiConfigId
      ..enableSecondaryXml = enableSecondaryXml ?? this.enableSecondaryXml
      ..secondaryXmlPrompt = secondaryXmlPrompt != null ? secondaryXmlPrompt.value : this.secondaryXmlPrompt
      ..secondaryXmlApiConfigId = secondaryXmlApiConfigId != null ? secondaryXmlApiConfigId.value : this.secondaryXmlApiConfigId
      ..continuePrompt = continuePrompt != null ? continuePrompt.value : this.continuePrompt
      ..generationConfig = generationConfig != null ? generationConfig.value : this.generationConfig
      ..apiType = apiType ?? this.apiType;
    return newChat;
  }

  // 用于在代码中方便创建聊天的构造函数
  Chat.create({
    this.title,
    this.systemPrompt,
    // this.coverImagePath, // 移除或注释掉旧的 coverImagePath
    this.coverImageBase64, // 新增
    this.backgroundImagePath,
    this.isFolder = false,
    this.parentFolderId,
    this.orderIndex,
    this.apiConfigId,
    DriftContextConfig? contextConfig,
    List<DriftXmlRule>? xmlRules,
    this.enablePreprocessing = false,
    this.preprocessingPrompt,
    this.contextSummary,
    this.preprocessingApiConfigId,
    this.enableSecondaryXml = false,
    this.secondaryXmlPrompt,
    this.secondaryXmlApiConfigId,
    this.continuePrompt,
    this.generationConfig,
    this.apiType,
  }) {
    createdAt = DateTime.now();
    updatedAt = DateTime.now();
    this.contextConfig = contextConfig ?? DriftContextConfig();
    this.xmlRules = xmlRules ?? [];
  }
}

// --- 消息内容部分模型 ---
class MessagePart {
  final MessagePartType type;
  final String? text; // For text content
  final String? mimeType; // For image/file content
  final String? base64Data; // For image/file content (base64 encoded)
  final String? fileName; // For file content

  MessagePart({
    required this.type,
    this.text,
    this.mimeType,
    this.base64Data,
    this.fileName,
  }) {
    // Basic validation
    if (type == MessagePartType.text && text == null) {
      throw ArgumentError('Text content cannot be null for text parts.');
    } else if (type == MessagePartType.image && (base64Data == null || mimeType == null)) {
      throw ArgumentError('Image content requires base64Data and mimeType.');
    } else if (type == MessagePartType.file && (base64Data == null || mimeType == null || fileName == null)) {
      throw ArgumentError('File content requires base64Data, mimeType, and fileName.');
    }
  }

  // Factory constructor for text part
  factory MessagePart.text(String text) {
    return MessagePart(type: MessagePartType.text, text: text);
  }

  // Factory constructor for image part
  factory MessagePart.image({required String mimeType, required String base64Data, String? fileName}) {
    return MessagePart(
      type: MessagePartType.image,
      mimeType: mimeType,
      base64Data: base64Data,
      fileName: fileName,
    );
  }

  // Factory constructor for file part
  factory MessagePart.file({required String mimeType, required String base64Data, required String fileName}) {
    return MessagePart(
      type: MessagePartType.file,
      mimeType: mimeType,
      base64Data: base64Data,
      fileName: fileName,
    );
  }

  // JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'text': text,
      'mimeType': mimeType,
      'base64Data': base64Data,
      'fileName': fileName,
    };
  }

  // JSON deserialization
  factory MessagePart.fromJson(Map<String, dynamic> json) {
    final type = MessagePartType.values.byName(json['type']);
    return MessagePart(
      type: type,
      text: json['text'],
      mimeType: json['mimeType'],
      base64Data: json['base64Data'],
      fileName: json['fileName'],
    );
  }
}


// --- 消息模型 ---
class Message {
  int id = 0; // Placeholder, will be set by Drift
  late int chatId;
  List<MessagePart> parts;
  drift_enums.MessageRole role; // Use Drift enum
  final DateTime timestamp;
  String? originalXmlContent;
  String? secondaryXmlContent;
  final String displayText; // New field for pre-processed display text

  Message({
    this.id = 0,
    required this.chatId,
    required this.parts,
    required this.role,
    DateTime? timestamp,
    this.originalXmlContent,
    this.secondaryXmlContent,
  })  : timestamp = timestamp ?? DateTime.now(),
        // Calculate displayText upon creation from all text parts
        displayText = XmlProcessor.stripXmlContent(
            parts.where((p) => p.type == MessagePartType.text).map((p) => p.text ?? '').join('\n'));

  // Getter for backward compatibility and simple text access
  String get rawText {
    return parts.where((p) => p.type == MessagePartType.text).map((p) => p.text).join('\n');
  }

  // copyWith method
  Message copyWith({
    int? id,
    int? chatId,
    List<MessagePart>? parts,
    String? rawText, // Keep for easy text-only updates
    String? appendToRawText,
    drift_enums.MessageRole? role,
    DateTime? timestamp,
    String? originalXmlContent,
    String? secondaryXmlContent,
  }) {
    List<MessagePart> newParts;
    if (parts != null) {
      newParts = parts;
    } else if (rawText != null) {
      // If only rawText is provided, replace all text parts with the new one
      newParts = this.parts.where((p) => p.type != MessagePartType.text).toList();
      newParts.insert(0, MessagePart.text(rawText));
    } else if (appendToRawText != null) {
      // If appendToRawText is provided, append it to the existing text part
      final existingText = this.parts.where((p) => p.type == MessagePartType.text).map((p) => p.text ?? '').join('');
      newParts = this.parts.where((p) => p.type != MessagePartType.text).toList();
      newParts.insert(0, MessagePart.text(existingText + appendToRawText));
    } else {
      newParts = this.parts;
    }

    // The main constructor will automatically recalculate displayText
    return Message(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      parts: newParts,
      role: role ?? this.role,
      timestamp: timestamp ?? this.timestamp,
      originalXmlContent: originalXmlContent ?? this.originalXmlContent,
      secondaryXmlContent: secondaryXmlContent ?? this.secondaryXmlContent,
    );
  }

  // Named factory constructor for convenience
  factory Message.create({
    required int chatId,
    required drift_enums.MessageRole role,
    List<MessagePart>? parts,
    String? rawText, // Allow creating from simple text
    String? originalXmlContent,
    String? secondaryXmlContent,
    DateTime? timestamp,
  }) {
    final finalParts = (parts != null && parts.isNotEmpty)
        ? parts
        : (rawText != null ? [MessagePart.text(rawText)] : <MessagePart>[]);
    
    if (finalParts.isEmpty) {
      throw ArgumentError("Either 'parts' or 'rawText' must be provided and be valid.");
    }

    // The main constructor will handle displayText calculation and timestamp
    return Message(
      chatId: chatId,
      role: role,
      parts: finalParts,
      originalXmlContent: originalXmlContent,
      secondaryXmlContent: secondaryXmlContent,
      timestamp: timestamp,
    );
  }
}

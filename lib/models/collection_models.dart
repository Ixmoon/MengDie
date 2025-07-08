import 'package:drift/drift.dart' show Value;
import 'enums.dart';
import '../services/xml_processor.dart'; // Import for text processing

// Import the new Drift-specific models and enums
import '../data/database/drift/models/drift_generation_config.dart';
import '../data/database/drift/models/drift_context_config.dart';
import '../data/database/drift/models/drift_xml_rule.dart';
import '../data/database/drift/common_enums.dart' as drift_enums;
import '../data/database/drift/app_database.dart'; // For ChatData, ChatsCompanion

// These classes now represent the application's domain models.

// --- 聊天会话模型 ---
class Chat {
  int id = 0; // Placeholder, will be set by Drift
  String? title;
  String? systemPrompt;
  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
  // String? coverImagePath; // 移除或注释掉旧的 coverImagePath
  String? coverImageBase64; // 新增：用于存储封面图片的 Base64 字符串
  String? backgroundImagePath;

  int? orderIndex;
  bool isFolder = false;
  int? parentFolderId;

  DriftGenerationConfig generationConfig = DriftGenerationConfig();
  DriftContextConfig contextConfig = DriftContextConfig();
  List<DriftXmlRule> xmlRules = [];

  drift_enums.LlmType apiType = drift_enums.LlmType.gemini;
  String? selectedOpenAIConfigId;

  // --- 新增字段 ---
  bool enablePreprocessing = false;
  String? preprocessingPrompt;
  String? contextSummary;
  bool enablePostprocessing = false;
  String? postprocessingPrompt;
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
      ..generationConfig = data.generationConfig
      ..contextConfig = data.contextConfig
      ..xmlRules = data.xmlRules
      ..apiType = data.apiType
      ..selectedOpenAIConfigId = data.selectedOpenAIConfigId
      ..enablePreprocessing = data.enablePreprocessing
      ..preprocessingPrompt = data.preprocessingPrompt
      ..contextSummary = data.contextSummary
      ..enablePostprocessing = data.enablePostprocessing
      ..postprocessingPrompt = data.postprocessingPrompt;
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
      generationConfig: Value(generationConfig),
      contextConfig: Value(contextConfig),
      xmlRules: Value(xmlRules),
      apiType: Value(apiType),
      selectedOpenAIConfigId: Value(selectedOpenAIConfigId),
      enablePreprocessing: Value(enablePreprocessing),
      preprocessingPrompt: Value(preprocessingPrompt),
      contextSummary: Value(contextSummary),
      enablePostprocessing: Value(enablePostprocessing),
      postprocessingPrompt: Value(postprocessingPrompt),
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
    DriftGenerationConfig? generationConfig,
    DriftContextConfig? contextConfig,
    List<DriftXmlRule>? xmlRules,
    drift_enums.LlmType? apiType,
    Value<String?>? selectedOpenAIConfigId,
    bool? enablePreprocessing,
    Value<String?>? preprocessingPrompt,
    Value<String?>? contextSummary,
    bool? enablePostprocessing,
    Value<String?>? postprocessingPrompt,
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
      ..generationConfig = generationConfig ?? this.generationConfig.copyWith() // Assuming Drift models also have copyWith
      ..contextConfig = contextConfig ?? this.contextConfig.copyWith()
      ..xmlRules = xmlRules ?? List<DriftXmlRule>.from(this.xmlRules)
      ..apiType = apiType ?? this.apiType
      ..selectedOpenAIConfigId = selectedOpenAIConfigId != null ? selectedOpenAIConfigId.value : this.selectedOpenAIConfigId
      ..enablePreprocessing = enablePreprocessing ?? this.enablePreprocessing
      ..preprocessingPrompt = preprocessingPrompt != null ? preprocessingPrompt.value : this.preprocessingPrompt
      ..contextSummary = contextSummary != null ? contextSummary.value : this.contextSummary
      ..enablePostprocessing = enablePostprocessing ?? this.enablePostprocessing
      ..postprocessingPrompt = postprocessingPrompt != null ? postprocessingPrompt.value : this.postprocessingPrompt;
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
    this.apiType = drift_enums.LlmType.gemini, // Use Drift enum
    this.selectedOpenAIConfigId,
    DriftGenerationConfig? generationConfig, // Allow passing custom configs
    DriftContextConfig? contextConfig,
    List<DriftXmlRule>? xmlRules,
    this.enablePreprocessing = false,
    this.preprocessingPrompt,
    this.contextSummary,
    this.enablePostprocessing = false,
    this.postprocessingPrompt,
  }) {
    createdAt = DateTime.now();
    updatedAt = DateTime.now();
    this.generationConfig = generationConfig ?? DriftGenerationConfig();
    // DriftGenerationConfig() will now correctly initialize with:
    // - useCustomParameters = false (by its own default in its constructor)
    // - temperature = null (as no default is provided in its constructor)
    // - topP = null (as no default is provided in its constructor)
    // - topK = null (as no default is provided in its constructor)
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
  final String displayText; // New field for pre-processed display text

  Message({
    this.id = 0,
    required this.chatId,
    required this.parts,
    required this.role,
    DateTime? timestamp,
    this.originalXmlContent,
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
    drift_enums.MessageRole? role,
    DateTime? timestamp,
    String? originalXmlContent,
  }) {
    List<MessagePart> newParts;
    if (parts != null) {
      newParts = parts;
    } else if (rawText != null) {
      // If only rawText is provided, replace all text parts with the new one
      newParts = this.parts.where((p) => p.type != MessagePartType.text).toList();
      newParts.insert(0, MessagePart.text(rawText));
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
    );
  }

  // Named factory constructor for convenience
  factory Message.create({
    required int chatId,
    required drift_enums.MessageRole role,
    List<MessagePart>? parts,
    String? rawText, // Allow creating from simple text
    String? originalXmlContent,
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
      timestamp: timestamp,
    );
  }
}

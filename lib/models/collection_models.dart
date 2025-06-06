// import 'package:isar/isar.dart'; // No longer needed

// Import the new Drift-specific models and enums
import '../data/database/drift/models/drift_generation_config.dart';
import '../data/database/drift/models/drift_context_config.dart';
import '../data/database/drift/models/drift_xml_rule.dart';
// OpenAIAPIConfig is not directly part of Chat model, but keep if other parts of 'models' need it.
// For now, assume Chat model does not directly embed OpenAIAPIConfig list like Isar might have.
// If selectedOpenAIConfigId refers to something, that'd be a String ID.
import '../data/database/drift/common_enums.dart' as drift_enums;


// part 'collection_models.g.dart'; // No longer needed for Drift

// These classes now represent the application's domain models,
// which will be populated from/to Drift data entities (ChatData, MessageData).

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

  Chat();

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

// --- 消息模型 ---
class Message {
  int id = 0; // Placeholder, will be set by Drift
  late int chatId;
  String rawText;
  drift_enums.MessageRole role; // Use Drift enum
  DateTime timestamp = DateTime.now();

  Message({
    this.id = 0,
    required this.chatId,
    required this.rawText,
    required this.role,
    DateTime? timestamp,
  }) : this.timestamp = timestamp ?? DateTime.now();


  // copyWith method
  Message copyWith({
    int? id,
    int? chatId,
    String? rawText,
    drift_enums.MessageRole? role,
    DateTime? timestamp,
  }) {
    return Message(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      rawText: rawText ?? this.rawText,
      role: role ?? this.role,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  // Named constructor for convenience, similar to original
  Message.create({
    required this.chatId,
    required this.rawText,
    required this.role,
  }) {
    timestamp = DateTime.now();
  }
}

// Ensure the old enums are not referenced if they were in a separate file,
// or update references if they were in 'enums.dart' which is now aliased or replaced.
// For this refactoring, we assume the drift_enums are the source of truth for these models.

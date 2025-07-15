import 'package:drift/drift.dart';
import '../type_converters.dart';

// Drift table for Chats
@DataClassName('ChatData') // To avoid conflict with existing Chat model
class Chats extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().nullable()();
  TextColumn get systemPrompt => text().nullable()();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get coverImageBase64 => text().nullable()(); // 新增：用于存储封面图片的 Base64 字符串
  TextColumn get backgroundImagePath => text().nullable()();

  IntColumn get orderIndex => integer().nullable()();
  BoolColumn get isFolder => boolean().nullable()();
  IntColumn get parentFolderId => integer().nullable()();

  // For embedded objects, we'll store them as JSON strings initially
  // and use TypeConverters later.
  TextColumn get contextConfig => text().map(const ContextConfigConverter())();
  TextColumn get xmlRules => text().map(const XmlRuleListConverter())();

  // 移除了 generationConfig, apiType, selectedOpenAIConfigId
  // 新增 apiConfigId 作为外键
  TextColumn get apiConfigId => text().nullable()();


  // --- Pre-processing and Post-processing ---
  BoolColumn get enablePreprocessing => boolean().nullable()();
  TextColumn get preprocessingPrompt => text().nullable()();
  TextColumn get contextSummary => text().nullable()(); // Stores the last summary from pre-processing
  TextColumn get preprocessingApiConfigId => text().nullable()();

  BoolColumn get enableSecondaryXml => boolean().nullable()();
  TextColumn get secondaryXmlPrompt => text().nullable()();
  TextColumn get secondaryXmlApiConfigId => text().nullable()();
  TextColumn get continuePrompt => text().nullable()(); // 新增：续写提示词

  // --- "Help Me Reply" Feature ---
  BoolColumn get enableHelpMeReply => boolean().nullable()();
  TextColumn get helpMeReplyPrompt => text().nullable()();
  TextColumn get helpMeReplyApiConfigId => text().nullable()();
  TextColumn get helpMeReplyTriggerMode => text().map(const HelpMeReplyTriggerModeConverter()).nullable()();
  // --- End ---

  // autoIncrement() on id column automatically makes it the primary key.
  // So, no need to override primaryKey explicitly.
}

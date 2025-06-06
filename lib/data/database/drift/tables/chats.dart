import 'package:drift/drift.dart';
import '../type_converters.dart';

// Drift table for Chats
@DataClassName('ChatData') // To avoid conflict with existing Chat model
class Chats extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().nullable()();
  TextColumn get systemPrompt => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  // TextColumn get coverImagePath => text().nullable()(); // 移除或注释掉旧的 coverImagePath
  TextColumn get coverImageBase64 => text().nullable()(); // 新增：用于存储封面图片的 Base64 字符串
  TextColumn get backgroundImagePath => text().nullable()();

  IntColumn get orderIndex => integer().nullable()();
  BoolColumn get isFolder => boolean().withDefault(const Constant(false))();
  IntColumn get parentFolderId => integer().nullable()();

  // For embedded objects, we'll store them as JSON strings initially
  // and use TypeConverters later.
  TextColumn get generationConfig => text().map(const GenerationConfigConverter())();
  TextColumn get contextConfig => text().map(const ContextConfigConverter())();
  TextColumn get xmlRules => text().map(const XmlRuleListConverter())();

  TextColumn get apiType => text().map(const LlmTypeConverter())();
  TextColumn get selectedOpenAIConfigId => text().nullable()();

  // autoIncrement() on id column automatically makes it the primary key.
  // So, no need to override primaryKey explicitly.
}

import 'package:drift/drift.dart';

// Gemini API 密钥表
@DataClassName('GeminiApiKey')
class GeminiApiKeys extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get apiKey => text().unique()(); // 密钥应该是唯一的
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// OpenAI API 配置表
// 这个表的设计反映了 DriftOpenAIAPIConfig 模型
@DataClassName('OpenAIConfig')
class OpenAIConfigs extends Table {
  TextColumn get id => text().clientDefault(() => 'temp_id')(); // 保持与模型一致
  TextColumn get name => text()();
  TextColumn get baseUrl => text()();
  TextColumn get apiKey => text()();
  TextColumn get model => text()();
  RealColumn get temperature => real().nullable()();
  IntColumn get maxTokens => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
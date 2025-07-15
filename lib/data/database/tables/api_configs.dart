import 'package:drift/drift.dart';

import '../type_converters.dart';


// 统一的 API 配置表
// 该表合并了 Gemini 和 OpenAI 的配置，并包含了各自的高级生成设置
@DataClassName('ApiConfig')
class ApiConfigs extends Table {
  // --- Foreign Key ---
  IntColumn get userId => integer().nullable()(); // Made nullable for safer migration

  // --- 通用字段 ---
  TextColumn get id => text().clientDefault(() => 'temp_id')();
  TextColumn get name => text()(); // 配置名称，对用户可见
  TextColumn get apiType => text().map(const LlmTypeConverter())(); // Gemini or OpenAI
  TextColumn get model => text()(); // 模型名称, e.g., 'gemini-1.5-pro', 'gpt-4'
  TextColumn get apiKey => text().nullable()(); // API Key (对于 Gemini, 这是全局的, 此处可为空)
  TextColumn get baseUrl => text().nullable()(); // Base URL (主要用于 OpenAI 兼容 API)

  // --- 高级生成设置 (从 DriftGenerationConfig 迁移) ---
  BoolColumn get useCustomTemperature => boolean().nullable()();
  RealColumn get temperature => real().nullable()();
  BoolColumn get useCustomTopP => boolean().nullable()();
  RealColumn get topP => real().nullable()();
  BoolColumn get useCustomTopK => boolean().nullable()();
  IntColumn get topK => integer().nullable()();
  IntColumn get maxOutputTokens => integer().nullable()();
  TextColumn get stopSequences => text().map(const StringListConverter()).nullable()();

  // --- OpenAI 专属设置 ---
  BoolColumn get enableReasoningEffort => boolean().nullable()();
  TextColumn get reasoningEffort => text().map(const OpenAIReasoningEffortConverter()).nullable()();

  // --- 时间戳 ---
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/api_configs.dart';

part 'api_config_dao.g.dart';

@DriftAccessor(tables: [GeminiApiKeys, OpenAIConfigs])
class ApiConfigDao extends DatabaseAccessor<AppDatabase> with _$ApiConfigDaoMixin {
  ApiConfigDao(AppDatabase db) : super(db);

  // --- Gemini API Key Operations ---

  Future<List<GeminiApiKey>> getAllGeminiApiKeys() => select(geminiApiKeys).get();
  Stream<List<GeminiApiKey>> watchAllGeminiApiKeys() => select(geminiApiKeys).watch();
  Future<void> addGeminiApiKey(String key) => into(geminiApiKeys).insert(GeminiApiKeysCompanion(apiKey: Value(key)));
  Future<void> addGeminiApiKeys(List<String> keys) async {
    await batch((batch) {
      batch.insertAll(geminiApiKeys, keys.map((key) => GeminiApiKeysCompanion(apiKey: Value(key))).toList(), mode: InsertMode.insertOrIgnore);
    });
  }
  Future<int> deleteGeminiApiKey(String key) => (delete(geminiApiKeys)..where((tbl) => tbl.apiKey.equals(key))).go();
  Future<void> clearAllGeminiApiKeys() => delete(geminiApiKeys).go();

  // --- OpenAI Config Operations ---

  Future<List<OpenAIConfig>> getAllOpenAIConfigs() => select(openAIConfigs).get();
  Stream<List<OpenAIConfig>> watchAllOpenAIConfigs() => select(openAIConfigs).watch();
  Future<void> saveOpenAIConfig(OpenAIConfigsCompanion companion) => into(openAIConfigs).insertOnConflictUpdate(companion);
  Future<int> deleteOpenAIConfig(String id) => (delete(openAIConfigs)..where((tbl) => tbl.id.equals(id))).go();
  Future<void> clearAllOpenAIConfigs() => delete(openAIConfigs).go();
}
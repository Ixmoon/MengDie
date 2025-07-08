import '../data/database/drift/daos/api_config_dao.dart';
import '../data/database/drift/models/drift_openai_api_config.dart';

// A simple data class to hold both types of API configurations.
// This helps in providing a unified API from the repository.
class ApiConfigs {
  final List<String> geminiApiKeys;
  final List<DriftOpenAIAPIConfig> openAIConfigs;

  ApiConfigs({required this.geminiApiKeys, required this.openAIConfigs});
}

class ApiConfigRepository {
  final ApiConfigDao _dao;

  ApiConfigRepository(this._dao);

  // --- Unified Fetch Method ---
  Future<ApiConfigs> getAllConfigs() async {
    final geminiData = await _dao.getAllGeminiApiKeys();
    final openAIData = await _dao.getAllOpenAIConfigs();

    final geminiKeys = geminiData.map((e) => e.apiKey).toList();
    final openAIConfigs = openAIData.map((data) => DriftOpenAIAPIConfig.fromData(data)).toList();
    
    return ApiConfigs(geminiApiKeys: geminiKeys, openAIConfigs: openAIConfigs);
  }

  // --- Gemini Key-specific Methods ---
  Future<void> addGeminiApiKey(String key) => _dao.addGeminiApiKey(key);
  Future<void> addGeminiApiKeys(List<String> keys) => _dao.addGeminiApiKeys(keys);
  Future<void> deleteGeminiApiKey(String key) => _dao.deleteGeminiApiKey(key);
  Future<void> clearAllGeminiApiKeys() => _dao.clearAllGeminiApiKeys();

  // --- OpenAI Config-specific Methods ---
  Future<void> saveOpenAIConfig(DriftOpenAIAPIConfig config) {
    // Check if the config exists to decide if it's an insert or update.
    // This is a simplified approach. A more robust way might be to check via the DAO.
    final isInsert = config.id.startsWith('temp_'); // A simple heuristic
    return _dao.saveOpenAIConfig(config.toCompanion(forInsert: isInsert));
  }
  Future<void> deleteOpenAIConfig(String id) => _dao.deleteOpenAIConfig(id);
  Future<void> clearAllOpenAIConfigs() => _dao.clearAllOpenAIConfigs();

}
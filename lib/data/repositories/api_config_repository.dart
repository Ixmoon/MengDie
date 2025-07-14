import 'package:logging/logging.dart';
import '../database/daos/api_config_dao.dart';
import '../mappers/api_config_mapper.dart';
import '../models/api_config.dart';

class ApiConfigRepository {
  final _log = Logger('ApiConfigRepository');
  final ApiConfigDao _dao;

  ApiConfigRepository(this._dao);

  // --- Unified API Config Methods ---

  Future<List<ApiConfig>> getAllConfigs(int userId) async {
    final driftConfigs = await _dao.getAllApiConfigs(userId);
    return driftConfigs.map(ApiConfigMapper.fromData).toList();
  }

  Stream<List<ApiConfig>> watchAllConfigs(int userId) {
    return _dao.watchAllApiConfigs(userId).map((driftConfigs) =>
        driftConfigs.map(ApiConfigMapper.fromData).toList());
  }

  Future<ApiConfig?> getConfigById(String id, int userId) async {
    final driftConfig = await _dao.getApiConfigById(id, userId);
    return driftConfig != null ? ApiConfigMapper.fromData(driftConfig) : null;
  }

  Future<void> saveConfig(ApiConfig config, int userId) {
    final companion = ApiConfigMapper.toCompanion(config);
    return _dao.upsertApiConfig(companion, userId);
  }

  Future<void> deleteConfig(String id, int userId) =>
      _dao.deleteApiConfig(id, userId);
  
  Future<void> clearAllConfigs(int userId) =>
      _dao.clearAllApiConfigs(userId);

  // Data migration logic can be added here.
  // This method would be called once upon app initialization.
  Future<void> migrateOldConfigs() async {
    // This is a placeholder for the complex migration logic.
    // It would involve:
    // 1. Reading from the (now-hidden) old `GeminiApiKeys` and `OpenAIConfigs` tables.
    // 2. Creating new `ApiConfig` entries for each old config.
    // 3. Updating all chats to point to the new `apiConfigId`.
    // 4. After successful migration, the old tables can be dropped in a future schema version.
    _log.info("Placeholder for data migration logic.");
  }
}
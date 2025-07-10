import 'package:logging/logging.dart';
import '../../data/database/daos/api_config_dao.dart';
import '../../data/mappers/api_config_mapper.dart';
import '../../data/models/api_config.dart';
import '../../data/database/app_database.dart' as drift;

class ApiConfigRepository {
  final _log = Logger('ApiConfigRepository');
  final ApiConfigDao _dao;

  ApiConfigRepository(this._dao);

  // --- Unified API Config Methods ---

  Future<List<ApiConfig>> getAllConfigs() async {
    final driftConfigs = await _dao.getAllApiConfigs();
    return driftConfigs.map(ApiConfigMapper.fromData).toList();
  }

  Stream<List<ApiConfig>> watchAllConfigs() {
    return _dao.watchAllApiConfigs().map((driftConfigs) =>
        driftConfigs.map(ApiConfigMapper.fromData).toList());
  }

  Future<ApiConfig?> getConfigById(String id) async {
    final driftConfig = await _dao.getApiConfigById(id);
    return driftConfig != null ? ApiConfigMapper.fromData(driftConfig) : null;
  }

  Future<void> saveConfig(ApiConfig config) {
    final companion = ApiConfigMapper.toCompanion(config);
    return _dao.upsertApiConfig(companion);
  }

  Future<void> deleteConfig(String id) => _dao.deleteApiConfig(id);
  
  Future<void> clearAllConfigs() => _dao.clearAllApiConfigs();

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
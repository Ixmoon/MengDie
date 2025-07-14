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

}
import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/api_configs.dart';

part 'api_config_dao.g.dart';

@DriftAccessor(tables: [ApiConfigs])
class ApiConfigDao extends DatabaseAccessor<AppDatabase> with _$ApiConfigDaoMixin {
  ApiConfigDao(super.db);

  // --- Unified API Config Operations ---

  // Get all configs
  Future<List<ApiConfig>> getAllApiConfigs() => select(apiConfigs).get();

  // Watch all configs
  Stream<List<ApiConfig>> watchAllApiConfigs() => select(apiConfigs).watch();

  // Get a single config by ID
  Future<ApiConfig?> getApiConfigById(String id) {
    return (select(apiConfigs)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  // Insert or update a config
  Future<void> upsertApiConfig(ApiConfigsCompanion companion) {
    return into(apiConfigs).insertOnConflictUpdate(companion);
  }

  // Delete a config by ID
  Future<int> deleteApiConfig(String id) {
    return (delete(apiConfigs)..where((tbl) => tbl.id.equals(id))).go();
  }

  // Clear all configs (use with caution)
  Future<void> clearAllApiConfigs() => delete(apiConfigs).go();
}
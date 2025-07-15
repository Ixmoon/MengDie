import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/api_configs.dart';

part 'api_config_dao.g.dart';

@DriftAccessor(tables: [ApiConfigs])
class ApiConfigDao extends DatabaseAccessor<AppDatabase> with _$ApiConfigDaoMixin {
  ApiConfigDao(super.db);

  // --- Unified API Config Operations ---

  // Get all configs for a specific user
  Future<List<ApiConfig>> getAllApiConfigs(int userId) {
    return (select(apiConfigs)..where((tbl) => tbl.userId.equals(userId))).get();
  }

  // Watch all configs for a specific user
  Stream<List<ApiConfig>> watchAllApiConfigs(int userId) {
    return (select(apiConfigs)..where((tbl) => tbl.userId.equals(userId))).watch();
  }

  // Get a single config by ID, ensuring it belongs to the user
  Future<ApiConfig?> getApiConfigById(String id, int userId) {
    return (select(apiConfigs)
          ..where((tbl) => tbl.id.equals(id))
          ..where((tbl) => tbl.userId.equals(userId)))
        .getSingleOrNull();
  }

  // Insert or update a config for a specific user
  Future<void> upsertApiConfig(ApiConfigsCompanion companion, int userId) async {
    // Ensure the companion has the correct userId and an updated timestamp before upserting
    final companionWithMeta = companion.copyWith(
      userId: Value(userId),
      updatedAt: Value(DateTime.now()),
    );
    await into(apiConfigs).insertOnConflictUpdate(companionWithMeta);
  }

  // Delete a config by ID for a specific user
  Future<int> deleteApiConfig(String id, int userId) async {
    final count = await (delete(apiConfigs)
          ..where((tbl) => tbl.id.equals(id))
          ..where((tbl) => tbl.userId.equals(userId)))
        .go();
    return count;
  }

  // Clear all configs for a specific user
  Future<void> clearAllApiConfigs(int userId) async {
    await (delete(apiConfigs)..where((tbl) => tbl.userId.equals(userId))).go();
  }
}
import 'package:drift/drift.dart';
import 'package:postgres/postgres.dart';

import '../app_database.dart';
import '../sync/sync_service.dart';
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
  Future<void> upsertApiConfig(ApiConfigsCompanion companion, {bool forceRemoteWrite = false}) async {
    await into(apiConfigs).insertOnConflictUpdate(companion);

    SyncService.instance.backgroundWrite(
      force: forceRemoteWrite,
      remoteTransaction: (remote) async {
        await remote.execute(
          'INSERT INTO api_configs (id, name, api_type, model, api_key, base_url, use_custom_temperature, temperature, use_custom_top_p, top_p, use_custom_top_k, top_k, max_output_tokens, stop_sequences, enable_reasoning_effort, reasoning_effort, created_at, updated_at) '
          'VALUES (@id, @name, @api_type, @model, @api_key, @base_url, @use_custom_temperature, @temperature, @use_custom_top_p, @top_p, @use_custom_top_k, @top_k, @max_output_tokens, @stop_sequences, @enable_reasoning_effort, @reasoning_effort, @created_at, @updated_at) '
          'ON CONFLICT (id) DO UPDATE SET '
          'name = @name, api_type = @api_type, model = @model, api_key = @api_key, base_url = @base_url, use_custom_temperature = @use_custom_temperature, temperature = @temperature, use_custom_top_p = @use_custom_top_p, top_p = @top_p, use_custom_top_k = @use_custom_top_k, top_k = @top_k, max_output_tokens = @max_output_tokens, stop_sequences = @stop_sequences, enable_reasoning_effort = @enable_reasoning_effort, reasoning_effort = @reasoning_effort, updated_at = @updated_at',
          parameters: {
            'id': companion.id.value,
            'name': companion.name.value,
            'api_type': companion.apiType.value.name,
            'model': companion.model.value,
            'api_key': companion.apiKey.value,
            'base_url': companion.baseUrl.value,
            'use_custom_temperature': companion.useCustomTemperature.value,
            'temperature': companion.temperature.value,
            'use_custom_top_p': companion.useCustomTopP.value,
            'top_p': companion.topP.value,
            'use_custom_top_k': companion.useCustomTopK.value,
            'top_k': companion.topK.value,
            'max_output_tokens': companion.maxOutputTokens.value,
            'stop_sequences': companion.stopSequences.value,
            'enable_reasoning_effort': companion.enableReasoningEffort.value,
            'reasoning_effort': companion.reasoningEffort.value?.name,
            'created_at': companion.createdAt.value,
            'updated_at': companion.updatedAt.value,
          },
        );
      },
      rollbackAction: () async {
        await (delete(apiConfigs)..where((tbl) => tbl.id.equals(companion.id.value))).go();
      },
    );
  }

  // Delete a config by ID
  Future<int> deleteApiConfig(String id, {bool forceRemoteWrite = false}) async {
    final configToDelete = await getApiConfigById(id);
    if (configToDelete == null) return 0;

    final count = await (delete(apiConfigs)..where((tbl) => tbl.id.equals(id))).go();

    if (count > 0) {
      SyncService.instance.backgroundWrite(
        force: forceRemoteWrite,
        remoteTransaction: (remote) async {
          await remote.execute(
            'DELETE FROM api_configs WHERE id = @id',
            parameters: {'id': id},
          );
        },
        rollbackAction: () async {
          await into(apiConfigs).insertOnConflictUpdate(configToDelete.toCompanion(false));
        },
      );
    }
    return count;
  }

  // Clear all configs (use with caution)
  Future<void> clearAllApiConfigs({bool forceRemoteWrite = false}) async {
    final allConfigs = await getAllApiConfigs();
    if (allConfigs.isEmpty) return;

    await delete(apiConfigs).go();

    SyncService.instance.backgroundWrite(
      force: forceRemoteWrite,
      remoteTransaction: (remote) async {
        await remote.execute('DELETE FROM api_configs');
      },
      rollbackAction: () async {
        await batch((batch) {
          batch.insertAll(apiConfigs, allConfigs);
        });
      },
    );
  }
}
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:postgres/postgres.dart';

import '../../app_database.dart';
import '../sync_meta.dart';
import 'base_sync_handler.dart';
import '../../type_converters.dart';
import '../../settings_service.dart';
import '../../../models/enums.dart';

class ApiConfigSyncHandler extends BaseSyncHandler<ApiConfig> {
  final int? userId;

  ApiConfigSyncHandler(super.db, super.remoteConnection, this.userId);

  @override
  String get entityType => 'api_configs';

  @override
  Future<List<SyncMeta>> getLocalMetas() async {
    final rows = await (db.selectOnly(db.apiConfigs)..addColumns([db.apiConfigs.id, db.apiConfigs.createdAt, db.apiConfigs.updatedAt])).get();
    return rows.map((row) => SyncMeta(
      id: row.read(db.apiConfigs.id)!,
      createdAt: row.read(db.apiConfigs.createdAt)!,
      updatedAt: row.read(db.apiConfigs.updatedAt)!
    )).toList();
  }

  @override
  Future<List<SyncMeta>> getRemoteMetas({List<dynamic>? localIds}) async {
    Result rows;
    if (localIds != null) {
      if (localIds.isEmpty) {
        return [];
      }
      rows = await remoteConnection!.execute(
        Sql.named('SELECT id, created_at, updated_at FROM api_configs WHERE id = ANY(@ids)'),
        parameters: {'ids': localIds},
      );
    } else {
      rows = await remoteConnection!.execute(
        Sql.named('SELECT id, created_at, updated_at FROM api_configs'),
      );
    }

    return rows.map((row) => SyncMeta(
      id: row[0] as String,
      createdAt: row[1] as DateTime,
      updatedAt: row[2] as DateTime
    )).toList();
  }

  @override
  Future<void> push(List<dynamic> ids) async {
    if (ids.isEmpty) return;
    final configsToPush = await (db.select(db.apiConfigs)..where((t) => t.id.isIn(ids.cast<String>()))).get();
    if (configsToPush.isEmpty) return;

    await _batchPushApiConfigs(remoteConnection!, configsToPush);
  }

  @override
  Future<void> pull(List<dynamic> ids) async {
    if (ids.isEmpty) return;
    final rows = await remoteConnection!.execute(Sql.named('SELECT * FROM api_configs WHERE id = ANY(@ids)'), parameters: {'ids': ids});
    final configsToPull = rows.map((r) {
        final map = r.toColumnMap();
        return ApiConfig(
          id: map['id'],
          name: map['name'],
          apiType: map['api_type'] == null ? LlmType.gemini : const LlmTypeConverter().fromSql(map['api_type']),
          model: map['model'],
          userId: map['user_id'],
          apiKey: map['api_key'],
          baseUrl: map['base_url'],
          useCustomTemperature: map['use_custom_temperature'],
          temperature: (map['temperature'] as num?)?.toDouble(),
          useCustomTopP: map['use_custom_top_p'],
          topP: (map['top_p'] as num?)?.toDouble(),
          useCustomTopK: map['use_custom_top_k'],
          topK: map['top_k'],
          maxOutputTokens: map['max_output_tokens'],
          stopSequences: map['stop_sequences'] == null ? null : const StringListConverter().fromSql(map['stop_sequences']),
          enableReasoningEffort: map['enable_reasoning_effort'],
          reasoningEffort: map['reasoning_effort'] == null ? null : const OpenAIReasoningEffortConverter().fromSql(map['reasoning_effort']),
          thinkingBudget: map['thinking_budget'],
          toolConfig: map['tool_config'],
          toolChoice: map['tool_choice'],
          useDefaultSafetySettings: map['use_default_safety_settings'] ?? true,
          createdAt: map['created_at'],
          updatedAt: map['updated_at'],
        );
    }).toList();
    if (configsToPull.isEmpty) return;

    await db.batch((batch) {
      batch.insertAll(db.apiConfigs, configsToPull.map((c) => c.toCompanion(true)), mode: InsertMode.insertOrReplace);
    });
  }

  @override
  Future<Map<dynamic, dynamic>> resolveConflicts(List<SyncMeta> localMetas, List<SyncMeta> remoteMetas) async {
    final localIdMap = {for (var meta in localMetas) meta.id: meta};
    final remoteIdMap = {for (var meta in remoteMetas) meta.id: meta};
    final conflictingIds = <String>{};

    for (final id in localIdMap.keys) {
      if (remoteIdMap.containsKey(id)) {
        final localMeta = localIdMap[id]!;
        final remoteMeta = remoteIdMap[id]!;
        if (localMeta.createdAt.toUtc() != remoteMeta.createdAt.toUtc()) {
          conflictingIds.add(id as String);
        }
      }
    }

    final idChangeMap = <String, String>{};
    if (conflictingIds.isNotEmpty) {
      await db.transaction(() async {
        for (final id in conflictingIds) {
          final newId = await _resolveApiConfigConflict(id);
          if (newId != null) {
            idChangeMap[id] = newId;
          }
        }
      });
    }
    return idChangeMap;
  }

  @override
  Future<void> deleteRemotely(List<String> keys) async {
    if (keys.isEmpty) return;
    final idsToDelete = keys;
    await remoteConnection!.execute(Sql.named('DELETE FROM api_configs WHERE id = ANY(@ids)'), parameters: {'ids': idsToDelete});
  }

  String _generateUuid() {
    final random = Random();
    String hex(int val, int len) => val.toRadixString(16).padLeft(len, '0');
    
    final b = List<int>.generate(16, (i) => random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40; // Version 4
    b[8] = (b[8] & 0x3f) | 0x80; // Variant 1

    return '${hex(b[0], 2)}${hex(b[1], 2)}${hex(b[2], 2)}${hex(b[3], 2)}-'
           '${hex(b[4], 2)}${hex(b[5], 2)}-'
           '${hex(b[6], 2)}${hex(b[7], 2)}-'
           '${hex(b[8], 2)}${hex(b[9], 2)}-'
           '${hex(b[10], 2)}${hex(b[11], 2)}${hex(b[12], 2)}${hex(b[13], 2)}${hex(b[14], 2)}${hex(b[15], 2)}';
  }

  Future<String?> _resolveApiConfigConflict(String oldId) async {
    final newId = _generateUuid();
    
    final oldCompanion = (await (db.select(db.apiConfigs)..where((tbl) => tbl.id.equals(oldId))).getSingleOrNull())?.toCompanion(true);
    if (oldCompanion == null) {
      return null;
    }

    await db.into(db.apiConfigs).insert(oldCompanion.copyWith(id: Value(newId)));
    await (db.update(db.chats)..where((tbl) => tbl.apiConfigId.equals(oldId))).write(ChatsCompanion(apiConfigId: Value(newId)));
    await (db.update(db.chats)..where((tbl) => tbl.preprocessingApiConfigId.equals(oldId))).write(ChatsCompanion(preprocessingApiConfigId: Value(newId)));
    await (db.update(db.chats)..where((tbl) => tbl.secondaryXmlApiConfigId.equals(oldId))).write(ChatsCompanion(secondaryXmlApiConfigId: Value(newId)));
    await (db.update(db.chats)..where((tbl) => tbl.helpMeReplyApiConfigId.equals(oldId))).write(ChatsCompanion(helpMeReplyApiConfigId: Value(newId)));
    await (db.update(db.users)..where((tbl) => tbl.titleGenerationApiConfigId.equals(oldId))).write(UsersCompanion(titleGenerationApiConfigId: Value(newId)));
    await (db.update(db.users)..where((tbl) => tbl.resumeApiConfigId.equals(oldId))).write(UsersCompanion(resumeApiConfigId: Value(newId)));
    await (db.delete(db.apiConfigs)..where((tbl) => tbl.id.equals(oldId))).go();
    return newId;
  }

  Future<void> _batchPushApiConfigs(Connection remoteConnection, List<ApiConfig> apiConfigs) async {
    await remoteConnection.execute(
      Sql.named('''
        INSERT INTO api_configs (
          id, user_id, name, api_type, model, api_key, base_url,
          use_custom_temperature, temperature, use_custom_top_p, top_p,
          use_custom_top_k, top_k, max_output_tokens, stop_sequences,
          enable_reasoning_effort, reasoning_effort, thinking_budget, tool_config, tool_choice, use_default_safety_settings,
          created_at, updated_at
        )
        SELECT
          c.id, c.user_id, c.name, c.api_type, c.model, c.api_key, c.base_url,
          c.use_custom_temperature, c.temperature::real, c.use_custom_top_p, c.top_p::real,
          c.use_custom_top_k, c.top_k, c.max_output_tokens, c.stop_sequences,
          c.enable_reasoning_effort, c.reasoning_effort, c.thinking_budget, c.tool_config, c.tool_choice, c.use_default_safety_settings,
          c.created_at, c.updated_at
        FROM UNNEST(
          @ids::text[], @user_ids::integer[], @names::text[], @api_types::text[], @models::text[], @api_keys::text[], @base_urls::text[],
          @use_custom_temperatures::boolean[], @temperatures::text[], @use_custom_top_ps::boolean[], @top_ps::text[],
          @use_custom_top_ks::boolean[], @top_ks::integer[], @max_output_tokens_list::integer[], @stop_sequences_list::text[],
          @enable_reasoning_efforts::boolean[], @reasoning_efforts::text[], @thinking_budgets::integer[], @tool_configs::text[], @tool_choices::text[], @use_default_safety_settings_list::boolean[],
          @created_ats::timestamp[], @updated_ats::timestamp[]
        ) AS c(
          id, user_id, name, api_type, model, api_key, base_url,
          use_custom_temperature, temperature, use_custom_top_p, top_p,
          use_custom_top_k, top_k, max_output_tokens, stop_sequences,
          enable_reasoning_effort, reasoning_effort, thinking_budget, tool_config, tool_choice, use_default_safety_settings,
          created_at, updated_at
        )
        ON CONFLICT (id) DO UPDATE SET
          name = EXCLUDED.name, api_type = EXCLUDED.api_type,
          model = EXCLUDED.model, api_key = EXCLUDED.api_key, base_url = EXCLUDED.base_url,
          use_custom_temperature = EXCLUDED.use_custom_temperature, temperature = EXCLUDED.temperature,
          use_custom_top_p = EXCLUDED.use_custom_top_p, top_p = EXCLUDED.top_p,
          use_custom_top_k = EXCLUDED.use_custom_top_k, top_k = EXCLUDED.top_k,
          max_output_tokens = EXCLUDED.max_output_tokens, stop_sequences = EXCLUDED.stop_sequences,
          enable_reasoning_effort = EXCLUDED.enable_reasoning_effort,
          reasoning_effort = EXCLUDED.reasoning_effort, 
          thinking_budget = EXCLUDED.thinking_budget,
          tool_config = EXCLUDED.tool_config,
          tool_choice = EXCLUDED.tool_choice,
          use_default_safety_settings = EXCLUDED.use_default_safety_settings,
          updated_at = EXCLUDED.updated_at;
      '''),
      parameters: {
        'ids': TypedValue(Type.textArray, apiConfigs.map((c) => c.id).toList()),
        'user_ids': TypedValue(Type.integerArray, apiConfigs.map((c) => c.userId).toList()),
        'names': TypedValue(Type.textArray, apiConfigs.map((c) => c.name).toList()),
        'api_types': TypedValue(Type.textArray, apiConfigs.map((c) => c.apiType.name).toList()),
        'models': TypedValue(Type.textArray, apiConfigs.map((c) => c.model).toList()),
        'api_keys': TypedValue(Type.textArray, apiConfigs.map((c) => c.apiKey).toList()),
        'base_urls': TypedValue(Type.textArray, apiConfigs.map((c) => c.baseUrl).toList()),
        'use_custom_temperatures': TypedValue(Type.booleanArray, apiConfigs.map((c) => c.useCustomTemperature).toList()),
        'temperatures': TypedValue(Type.textArray, apiConfigs.map((c) => c.temperature?.toString()).toList()),
        'use_custom_top_ps': TypedValue(Type.booleanArray, apiConfigs.map((c) => c.useCustomTopP).toList()),
        'top_ps': TypedValue(Type.textArray, apiConfigs.map((c) => c.topP?.toString()).toList()),
        'use_custom_top_ks': TypedValue(Type.booleanArray, apiConfigs.map((c) => c.useCustomTopK).toList()),
        'top_ks': TypedValue(Type.integerArray, apiConfigs.map((c) => c.topK).toList()),
        'max_output_tokens_list': TypedValue(Type.integerArray, apiConfigs.map((c) => c.maxOutputTokens).toList()),
        'stop_sequences_list': TypedValue(Type.textArray, apiConfigs.map((c) => const StringListConverter().toSql(c.stopSequences ?? [])).toList()),
        'enable_reasoning_efforts': TypedValue(Type.booleanArray, apiConfigs.map((c) => c.enableReasoningEffort).toList()),
        'reasoning_efforts': TypedValue(Type.textArray, apiConfigs.map((c) => c.reasoningEffort?.name).toList()),
        'thinking_budgets': TypedValue(Type.integerArray, apiConfigs.map((c) => c.thinkingBudget).toList()),
        'tool_configs': TypedValue(Type.textArray, apiConfigs.map((c) => c.toolConfig).toList()),
        'tool_choices': TypedValue(Type.textArray, apiConfigs.map((c) => c.toolChoice).toList()),
        'use_default_safety_settings_list': TypedValue(Type.booleanArray, apiConfigs.map((c) => c.useDefaultSafetySettings).toList()),
        'created_ats': TypedValue(Type.timestampArray, apiConfigs.map((c) => c.createdAt).toList()),
        'updated_ats': TypedValue(Type.timestampArray, apiConfigs.map((c) => c.updatedAt).toList()),
      }
    );
  }
}
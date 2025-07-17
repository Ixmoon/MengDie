import 'package:drift/drift.dart';
import 'package:postgres/postgres.dart';

import '../../database/app_database.dart';
import '../sync_meta.dart';
import 'base_sync_handler.dart';
import '../../database/type_converters.dart';

class UserSyncHandler extends BaseSyncHandler<DriftUser> {
  UserSyncHandler(super.db, super.remoteConnection);

  @override
  String get entityType => 'users';

  @override
  Future<List<SyncMeta>> getLocalMetas() async {
    final rows = await (db.selectOnly(db.users)..addColumns([db.users.uuid, db.users.createdAt, db.users.updatedAt])).get();
    return rows.map((row) => SyncMeta(
      id: row.read(db.users.uuid)!,
      createdAt: row.read(db.users.createdAt)!,
      updatedAt: row.read(db.users.updatedAt)!
    )).toList();
  }

  @override
  Future<List<SyncMeta>> getRemoteMetas({List<dynamic>? localIds}) async {
    // For users, we fetch all remote metas regardless of local IDs,
    // as we need to know about new users created on other devices.
    // The `localIds` parameter is ignored here.
    final rows = await remoteConnection!.execute('SELECT uuid, created_at, updated_at FROM users');
    return rows.map((row) => SyncMeta(
      id: row[0] as String,
      createdAt: row[1] as DateTime,
      updatedAt: row[2] as DateTime
    )).toList();
  }

  @override
  Future<void> push(List<dynamic> ids) async {
    if (ids.isEmpty) return;
    final usersToPush = await (db.select(db.users)..where((t) => t.uuid.isIn(ids.cast<String>()))).get();
    if (usersToPush.isEmpty) return;

    await _batchPushUsers(remoteConnection!, usersToPush);
  }

  @override
  Future<void> pull(List<dynamic> ids) async {
    if (ids.isEmpty) return;
    final rows = await remoteConnection!.execute(Sql.named('SELECT * FROM users WHERE uuid = ANY(@ids)'), parameters: {'ids': ids});
    final usersToPull = rows.map((r) => DriftUser.fromJson(r.toColumnMap())).toList();
    if (usersToPull.isEmpty) return;

    await db.batch((batch) {
      batch.insertAll(db.users, usersToPull.map((u) => u.toCompanion(true)), mode: InsertMode.insertOrReplace);
    });
  }

  @override
  Future<Map<dynamic, dynamic>> resolveConflicts(List<SyncMeta> localMetas, List<SyncMeta> remoteMetas) async {
    final localIdMap = {for (var meta in localMetas) meta.id: meta};
    final remoteIdMap = {for (var meta in remoteMetas) meta.id: meta};
    final conflictingUuids = <String>{};

    for (final uuid in localIdMap.keys) {
      if (remoteIdMap.containsKey(uuid)) {
        final localMeta = localIdMap[uuid]!;
        final remoteMeta = remoteIdMap[uuid]!;
        if (localMeta.createdAt.toUtc() != remoteMeta.createdAt.toUtc()) {
          conflictingUuids.add(uuid as String);
        }
      }
    }

    final idChangeMap = <int, int>{};
    if (conflictingUuids.isNotEmpty) {
      await db.transaction(() async {
        for (final uuid in conflictingUuids) {
          final change = await _resolveUserConflict(uuid);
          if (change != null) {
            idChangeMap.addAll(change);
          }
        }
      });
    }
    return idChangeMap;
  }
  
  @override
  Future<void> deleteRemotely(List<String> keys) async {
    if (keys.isEmpty) return;
    // For users, the key is the UUID.
    final uuidsToDelete = keys;
    await remoteConnection!.execute(Sql.named('DELETE FROM users WHERE uuid = ANY(@ids)'), parameters: {'ids': uuidsToDelete});
  }

  // ============== CONFLICT RESOLUTION HELPER ==============

  Future<Map<int, int>?> _resolveUserConflict(String oldUuid) async {
    final user = await (db.select(db.users)..where((tbl) => tbl.uuid.equals(oldUuid))).getSingleOrNull();
    if (user == null) {
      return null;
    }
    final oldId = user.id;

    // Create a new user record with a new auto-incremented ID
    final newUserCompanion = user.toCompanion(false).copyWith(id: const Value.absent());
    final newUser = await db.into(db.users).insertReturning(newUserCompanion);
    final newId = newUser.id;

    // Cascade the ID change to related tables (api_configs)
    await (db.update(db.apiConfigs)..where((tbl) => tbl.userId.equals(oldId)))
        .write(ApiConfigsCompanion(userId: Value(newId)));

    // Delete the old user record
    await (db.delete(db.users)..where((tbl) => tbl.id.equals(oldId))).go();

    return {oldId: newId};
  }

  // ============== BATCH PUSH HELPER ==============

  // Private batch push helper, moved from SyncService
  Future<void> _batchPushUsers(Connection remoteConnection, List<DriftUser> users) async {
    await remoteConnection.execute(
      Sql.named('''
        INSERT INTO users (
          id, uuid, created_at, updated_at, username, password_hash, chat_ids,
          enable_auto_title_generation, title_generation_prompt, title_generation_api_config_id,
          enable_resume, resume_prompt, resume_api_config_id, gemini_api_keys
        )
        SELECT
          u.id, u.uuid, u.created_at, u.updated_at, u.username, u.password_hash, u.chat_ids,
          u.enable_auto_title_generation, u.title_generation_prompt, u.title_generation_api_config_id,
          u.enable_resume, u.resume_prompt, u.resume_api_config_id, u.gemini_api_keys
        FROM UNNEST(
          @ids::integer[], @uuids::text[], @created_ats::timestamp[], @updated_ats::timestamp[], @usernames::text[],
          @password_hashes::text[], @chat_ids_list::text[], @enable_auto_title_generations::boolean[],
          @title_generation_prompts::text[], @title_generation_api_config_ids::text[], @enable_resumes::boolean[],
          @resume_prompts::text[], @resume_api_config_ids::text[], @gemini_api_keys_list::text[]
        ) AS u(
          id, uuid, created_at, updated_at, username, password_hash, chat_ids,
          enable_auto_title_generation, title_generation_prompt, title_generation_api_config_id,
          enable_resume, resume_prompt, resume_api_config_id, gemini_api_keys
        )
        ON CONFLICT (uuid) DO UPDATE SET
          username = EXCLUDED.username,
          password_hash = EXCLUDED.password_hash,
          chat_ids = EXCLUDED.chat_ids,
          enable_auto_title_generation = EXCLUDED.enable_auto_title_generation,
          title_generation_prompt = EXCLUDED.title_generation_prompt,
          title_generation_api_config_id = EXCLUDED.title_generation_api_config_id,
          enable_resume = EXCLUDED.enable_resume,
          resume_prompt = EXCLUDED.resume_prompt,
          resume_api_config_id = EXCLUDED.resume_api_config_id,
          gemini_api_keys = EXCLUDED.gemini_api_keys,
          updated_at = EXCLUDED.updated_at;
      '''),
      parameters: {
        'ids': TypedValue(Type.integerArray, users.map((u) => u.id).toList()),
        'uuids': TypedValue(Type.textArray, users.map((u) => u.uuid).toList()),
        'created_ats': TypedValue(Type.timestampArray, users.map((u) => u.createdAt).toList()),
        'updated_ats': TypedValue(Type.timestampArray, users.map((u) => u.updatedAt).toList()),
        'usernames': TypedValue(Type.textArray, users.map((u) => u.username).toList()),
        'password_hashes': TypedValue(Type.textArray, users.map((u) => u.passwordHash).toList()),
        'chat_ids_list': TypedValue(Type.textArray, users.map((u) => const IntListConverter().toSql(u.chatIds ?? [])).toList()),
        'enable_auto_title_generations': TypedValue(Type.booleanArray, users.map((u) => u.enableAutoTitleGeneration).toList()),
        'title_generation_prompts': TypedValue(Type.textArray, users.map((u) => u.titleGenerationPrompt).toList()),
        'title_generation_api_config_ids': TypedValue(Type.textArray, users.map((u) => u.titleGenerationApiConfigId).toList()),
        'enable_resumes': TypedValue(Type.booleanArray, users.map((u) => u.enableResume).toList()),
        'resume_prompts': TypedValue(Type.textArray, users.map((u) => u.resumePrompt).toList()),
        'resume_api_config_ids': TypedValue(Type.textArray, users.map((u) => u.resumeApiConfigId).toList()),
        'gemini_api_keys_list': TypedValue(Type.textArray, users.map((u) => const StringListConverter().toSql(u.geminiApiKeys ?? [])).toList()),
      },
    );
  }
}
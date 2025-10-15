import 'package:drift/drift.dart';
import 'package:postgres/postgres.dart';

import '../../database/app_database.dart';
import '../sync_meta.dart';
import 'base_sync_handler.dart';
import '../../../domain/models/user.dart';
import '../../database/type_converters.dart';

class UserSyncHandler extends BaseSyncHandler<DriftUser> {
  UserSyncHandler(super.db, super.remoteConnection);

  @override
  String get entityType => 'users';

  @override
  Future<List<SyncMeta>> getLocalMetas() async {
    final rows =
        await (db.selectOnly(db.users)
              ..where(db.users.id.isNotValue(0)) // Always exclude guest user
              ..addColumns([
                db.users.username,
                db.users.createdAt,
                db.users.updatedAt,
              ]))
            .get();
    return rows
        .map(
          (row) => SyncMeta(
            id: row.read(db.users.username)!,
            createdAt: const MicrosecondDateTimeConverter().fromSql(
              row.read(db.users.createdAt)!,
            ),
            updatedAt: const MicrosecondDateTimeConverter().fromSql(
              row.read(db.users.updatedAt)!,
            ),
          ),
        )
        .toList();
  }

  Future<bool> remoteUsernameExists(String username) async {
    if (remoteConnection == null) return false;
    final result = await remoteConnection!.execute(
      Sql.named('SELECT 1 FROM users WHERE username = @username'),
      parameters: {'username': username},
    );
    return result.isNotEmpty;
  }

  @override
  Future<List<SyncMeta>> getRemoteMetas({List<dynamic>? localIds}) async {
    // For users, we fetch all remote metas regardless of local IDs,
    // as we need to know about new users created on other devices.
    // The `localIds` parameter is ignored here.
    final rows = await remoteConnection!.execute(
      'SELECT username, created_at, updated_at FROM users',
    );
    return rows
        .map(
          (row) => SyncMeta(
            id: row[0] as String,
            createdAt: row[1] as DateTime,
            updatedAt: row[2] as DateTime,
          ),
        )
        .toList();
  }

  @override
  Future<void> push(List<dynamic> ids) async {
    if (ids.isEmpty) return;
    final usersToPush =
        await (db.select(db.users)
              ..where((t) => t.username.isIn(ids.cast<String>()))
              ..where((t) => t.id.isNotValue(0)))
            .get();
    if (usersToPush.isEmpty) return;

    await _batchPushUsers(remoteConnection!, usersToPush);
  }

  @override
  Future<void> pull(List<dynamic> ids) async {
    if (ids.isEmpty) return;
    final rows = await remoteConnection!.execute(
      Sql.named('SELECT * FROM users WHERE username = ANY(@ids)'),
      parameters: {'ids': ids},
    );
    final usersToPull = rows
        .map((r) {
          final map = r.toColumnMap();
          // Key conversion from snake_case to camelCase for fromJson
          final camelCaseMap = {
            'id': map['id'],
            'uuid': map['uuid'],
            'createdAt': map['created_at'],
            'updatedAt': map['updated_at'],
            'username': map['username'],
            'passwordHash': map['password_hash'],
            'chatIds': const IntListConverter().fromSql(map['chat_ids']),
            'enableAutoTitleGeneration': map['enable_auto_title_generation'],
            'titleGenerationPrompt': map['title_generation_prompt'],
            'titleGenerationApiConfigId': map['title_generation_api_config_id'],
            'enableResume': map['enable_resume'],
            'resumePrompt': map['resume_prompt'],
            'resumeApiConfigId': map['resume_api_config_id'],
            'geminiApiKeys': const StringListConverter().fromSql(
              map['gemini_api_keys'],
            ),
          };
          return DriftUser.fromJson(camelCaseMap);
        })
        .where((user) => user.id != 0)
        .toList();
    if (usersToPull.isEmpty) return;

    await db.batch((batch) {
      batch.insertAll(
        db.users,
        usersToPull.map((u) => u.toCompanion(true)),
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  @override
  Future<Map<dynamic, dynamic>> resolveConflicts(
    List<SyncMeta> localMetas,
    List<SyncMeta> remoteMetas,
  ) async {
    // For users, conflicts are now handled by `ON CONFLICT (username) DO UPDATE`
    // during the push operation. This method is now a no-op but is kept
    // for consistency with the base handler.
    return {};
  }

  @override
  Future<void> deleteRemotely(List<String> keys) async {
    if (keys.isEmpty) return;
    // For users, the key is now the username.
    final usernamesToDelete = keys;
    await remoteConnection!.execute(
      Sql.named('DELETE FROM users WHERE username = ANY(@ids)'),
      parameters: {'ids': usernamesToDelete},
    );
  }

  /// Deletes a user and all their associated data from the remote database.
  Future<void> deleteUserRemotely(User user) async {
    final c = remoteConnection!;
    await c.execute('BEGIN');
    try {
      final chatIds = user.chatIds;

      // We need to fetch api_config_ids from remote as they are not on the User model
      final apiConfigsResult = await c.execute(
        Sql.named('SELECT id FROM api_configs WHERE user_id = @userId'),
        parameters: {'userId': user.id},
      );
      final apiConfigIds =
          apiConfigsResult.map((row) => row[0] as String).toList();

      if (chatIds.isNotEmpty) {
        await c.execute(
          Sql.named('DELETE FROM messages WHERE chat_id = ANY(@ids)'),
          parameters: {'ids': chatIds},
        );
        await c.execute(
          Sql.named('DELETE FROM chats WHERE id = ANY(@ids)'),
          parameters: {'ids': chatIds},
        );
      }

      if (apiConfigIds.isNotEmpty) {
        await c.execute(
          Sql.named('DELETE FROM api_configs WHERE id = ANY(@ids)'),
          parameters: {'ids': apiConfigIds},
        );
      }

      await c.execute(
        Sql.named('DELETE FROM users WHERE id = @id'),
        parameters: {'id': user.id},
      );
      await c.execute('COMMIT');
    } catch (e) {
      await c.execute('ROLLBACK');
      rethrow;
    }
  }

  // ============== BATCH PUSH HELPER ==============

  // Private batch push helper, moved from SyncService
  Future<void> _batchPushUsers(
    Connection remoteConnection,
    List<DriftUser> users,
  ) async {
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
        ON CONFLICT (username) DO UPDATE SET
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
        'created_ats': TypedValue(
          Type.timestampArray,
          users.map((u) => u.createdAt).toList(),
        ),
        'updated_ats': TypedValue(
          Type.timestampArray,
          users.map((u) => u.updatedAt).toList(),
        ),
        'usernames': TypedValue(
          Type.textArray,
          users.map((u) => u.username).toList(),
        ),
        'password_hashes': TypedValue(
          Type.textArray,
          users.map((u) => u.passwordHash).toList(),
        ),
        'chat_ids_list': TypedValue(
          Type.textArray,
          users
              .map((u) => const IntListConverter().toSql(u.chatIds ?? []))
              .toList(),
        ),
        'enable_auto_title_generations': TypedValue(
          Type.booleanArray,
          users.map((u) => u.enableAutoTitleGeneration).toList(),
        ),
        'title_generation_prompts': TypedValue(
          Type.textArray,
          users.map((u) => u.titleGenerationPrompt).toList(),
        ),
        'title_generation_api_config_ids': TypedValue(
          Type.textArray,
          users.map((u) => u.titleGenerationApiConfigId).toList(),
        ),
        'enable_resumes': TypedValue(
          Type.booleanArray,
          users.map((u) => u.enableResume).toList(),
        ),
        'resume_prompts': TypedValue(
          Type.textArray,
          users.map((u) => u.resumePrompt).toList(),
        ),
        'resume_api_config_ids': TypedValue(
          Type.textArray,
          users.map((u) => u.resumeApiConfigId).toList(),
        ),
        'gemini_api_keys_list': TypedValue(
          Type.textArray,
          users
              .map(
                (u) => const StringListConverter().toSql(u.geminiApiKeys ?? []),
              )
              .toList(),
        ),
      },
    );
  }
}

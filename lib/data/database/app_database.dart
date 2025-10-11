import 'package:drift/drift.dart';

import 'package:uuid/uuid.dart';
import 'connections/native.dart' if (dart.library.html) 'connections/web.dart';
import '../sync/sync_service.dart';

// Import tables
import 'tables/chats.dart';
import 'tables/messages.dart';
import 'tables/api_configs.dart'; // Import new tables
import 'tables/users.dart'; // Import user table

// Import DAOs
import 'daos/chat_dao.dart';
import 'daos/message_dao.dart';
import 'daos/api_config_dao.dart'; // Import new DAO
import 'daos/user_dao.dart'; // Import user DAO

// Import type converters and models for them
import 'type_converters.dart';
import '../../domain/models/context_config.dart';
import '../../domain/models/xml_rule.dart';
import '../../domain/enums.dart';
// path_provider and path are only needed in native.dart now.

part 'app_database.g.dart'; // Drift will generate this file

@DriftDatabase(
  tables: [Chats, Messages, ApiConfigs, Users],
  daos: [ChatDao, MessageDao, ApiConfigDao, UserDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(connect());

  AppDatabase.forTesting(super.connection);

  // The transactionExecutor getter is removed as SyncService will use
  // the transaction() method directly to ensure a proper transaction context.

  @override
  int get schemaVersion => 6; // Bumped version to 6 for microsecond timestamp precision

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) => m.createAll(),
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.addColumn(apiConfigs, apiConfigs.thinkingBudget);
          await m.addColumn(apiConfigs, apiConfigs.toolConfig);
          await m.addColumn(apiConfigs, apiConfigs.toolChoice);
          await m.addColumn(apiConfigs, apiConfigs.useDefaultSafetySettings);
          await customStatement(
            'UPDATE api_configs SET use_default_safety_settings = TRUE WHERE use_default_safety_settings IS NULL',
          );
        }
        if (from < 3) {
          await customStatement(
            'UPDATE api_configs SET use_default_safety_settings = TRUE WHERE use_default_safety_settings IS NULL',
          );
        }
        if (from < 4) {
          await m.addColumn(messages, messages.updatedAt);
          await customStatement(
            'UPDATE messages SET updated_at = timestamp WHERE updated_at IS NULL',
          );
        }
        if (from < 5) {
          await m.addColumn(chats, chats.lastSummarizedMessageId);
        }
        if (from < 6) {
          // Migration for microsecond precision timestamps for all tables.

          // Step 1: Ensure there are no NULL values in `updated_at` columns before altering them.
          await customStatement(
            'UPDATE messages SET updated_at = "timestamp" WHERE updated_at IS NULL',
          );
          await customStatement(
            'UPDATE chats SET updated_at = created_at WHERE updated_at IS NULL',
          );
          await customStatement(
            'UPDATE api_configs SET updated_at = created_at WHERE updated_at IS NULL',
          );
          await customStatement(
            'UPDATE users SET updated_at = created_at WHERE updated_at IS NULL',
          );

          // Step 2: Use alterTable with an expression to convert from seconds to microseconds.
          await m.alterTable(
            TableMigration(
              messages,
              columnTransformer: {
                messages.timestamp:
                    messages.timestamp * const Constant(1000000),
                messages.updatedAt:
                    messages.updatedAt * const Constant(1000000),
              },
            ),
          );
          await m.alterTable(
            TableMigration(
              chats,
              columnTransformer: {
                chats.createdAt: chats.createdAt * const Constant(1000000),
                chats.updatedAt: chats.updatedAt * const Constant(1000000),
              },
            ),
          );
          await m.alterTable(
            TableMigration(
              apiConfigs,
              columnTransformer: {
                apiConfigs.createdAt:
                    apiConfigs.createdAt * const Constant(1000000),
                apiConfigs.updatedAt:
                    apiConfigs.updatedAt * const Constant(1000000),
              },
            ),
          );
          await m.alterTable(
            TableMigration(
              users,
              columnTransformer: {
                users.createdAt: users.createdAt * const Constant(1000000),
                users.updatedAt: users.updatedAt * const Constant(1000000),
              },
            ),
          );
        }
      },
    );
  }

  Future<void> syncWithRemote() async {
    // This method is now a proxy to the SyncService instance method.
    // The actual logic is handled within SyncService itself.
    await SyncService.instance.syncWithRemote();
  }
}

// _openConnection function is now removed, using connect() from conditional import.

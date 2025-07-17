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

@DriftDatabase(tables: [Chats, Messages, ApiConfigs, Users], daos: [ChatDao, MessageDao, ApiConfigDao, UserDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(connect());

  AppDatabase.forTesting(super.connection);

  // The transactionExecutor getter is removed as SyncService will use
  // the transaction() method directly to ensure a proper transaction context.

  @override
  int get schemaVersion => 4; // Bumped version to 4 for messages.updatedAt

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) => m.createAll(),
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          // This logic is for users migrating from version 1.
          await m.addColumn(apiConfigs, apiConfigs.thinkingBudget);
          await m.addColumn(apiConfigs, apiConfigs.toolConfig);
          await m.addColumn(apiConfigs, apiConfigs.toolChoice);
          await m.addColumn(apiConfigs, apiConfigs.useDefaultSafetySettings);
          // Set a default value for existing rows.
          await customStatement('UPDATE api_configs SET use_default_safety_settings = TRUE WHERE use_default_safety_settings IS NULL');
        }
        if (from < 3) {
          // This logic is for users who were on version 2 with the faulty migration.
          // It ensures that any NULL values from the previous migration are fixed.
          await customStatement('UPDATE api_configs SET use_default_safety_settings = TRUE WHERE use_default_safety_settings IS NULL');
        }
        if (from < 4) {
          // Add the updatedAt column as nullable first, to support older SQLite versions.
          await m.addColumn(messages, messages.updatedAt);
          // Then, backfill existing rows with the value from the timestamp column.
          await customStatement('UPDATE messages SET updated_at = timestamp WHERE updated_at IS NULL');
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

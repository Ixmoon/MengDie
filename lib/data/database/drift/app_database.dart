// Remove platform specific imports from here, they are in connection files now
// import 'dart:io'; 

import 'package:drift/drift.dart';
// import 'package:drift/wasm.dart'; // No longer needed here
// import 'package:flutter/foundation.dart'; // No longer needed here

// Conditional import for connection logic
import 'connections/native.dart' if (dart.library.html) 'connections/web.dart';

// Import tables
import 'tables/chats.dart';
import 'tables/messages.dart';
import 'tables/api_configs.dart'; // Import new tables

// Import DAOs
import 'daos/chat_dao.dart';
import 'daos/message_dao.dart';
import 'daos/api_config_dao.dart'; // Import new DAO

// Import type converters and models for them
import 'type_converters.dart';
import 'models/drift_generation_config.dart';
import 'models/drift_context_config.dart';
import 'models/drift_xml_rule.dart';
import 'common_enums.dart';
// path_provider and path are only needed in native.dart now.


part 'app_database.g.dart'; // Drift will generate this file

@DriftDatabase(tables: [Chats, Messages, GeminiApiKeys, OpenAIConfigs], daos: [ChatDao, MessageDao, ApiConfigDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(connect()); // Use the conditionally imported connect()

  AppDatabase.forTesting(super.connection);

  @override
  int get schemaVersion => 4; // Bump version to 4

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // Each migration builds on the last.
      if (from < 2) {
         await m.addColumn(chats, chats.coverImageBase64);
      }
      if (from < 3) {
        await m.createTable(geminiApiKeys);
        await m.createTable(openAIConfigs);
      }
      if (from < 4) {
        // Add all new columns for version 4
        await m.addColumn(chats, chats.enablePreprocessing);
        await m.addColumn(chats, chats.preprocessingPrompt);
        await m.addColumn(chats, chats.contextSummary);
        await m.addColumn(chats, chats.enablePostprocessing);
        await m.addColumn(chats, chats.postprocessingPrompt);
        await m.addColumn(messages, messages.originalXmlContent);
      }
    },
  );


}

// _openConnection function is now removed, using connect() from conditional import.

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

// Import DAOs
import 'daos/chat_dao.dart';
import 'daos/message_dao.dart';

// Import type converters and models for them
import 'type_converters.dart';
import 'models/drift_generation_config.dart';
import 'models/drift_context_config.dart';
import 'models/drift_xml_rule.dart';
import 'common_enums.dart';
// path_provider and path are only needed in native.dart now.


part 'app_database.g.dart'; // Drift will generate this file

@DriftDatabase(tables: [Chats, Messages], daos: [ChatDao, MessageDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(connect()); // Use the conditionally imported connect()

  AppDatabase.forTesting(DatabaseConnection connection) : super(connection);

  @override
  int get schemaVersion => 2; // Bump version to 2

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from == 1) {
        // We added the coverImageBase64 column to the chats table
        await m.addColumn(chats, chats.coverImageBase64);
      }
    },
  );


}

// _openConnection function is now removed, using connect() from conditional import.

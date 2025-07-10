import 'dart:io';

import 'package:drift/drift.dart'; // Full import
import 'package:drift/native.dart' show NativeDatabase;
import 'package:path_provider/path_provider.dart' show getApplicationDocumentsDirectory;
import 'package:path/path.dart' as p;

dynamic connect() { // Changed return type to dynamic
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'gemini_chat_app_drift.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

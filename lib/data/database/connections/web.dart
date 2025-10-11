import 'package:drift/drift.dart';
import 'package:drift/wasm.dart'; // Revert to Wasm

DatabaseConnection connect() {
  return DatabaseConnection.delayed(
    Future(() async {
      final result = await WasmDatabase.open(
        databaseName: 'gemini_chat_app_drift_web_wasm', // New name for Wasm DB
        sqlite3Uri: Uri.parse('/sqlite3.wasm'),
        driftWorkerUri: Uri.parse('/drift_worker.js'),
      );

      return result.resolvedExecutor;
    }),
  );
}

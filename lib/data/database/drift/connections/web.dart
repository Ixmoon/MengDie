import 'package:drift/drift.dart';
import 'package:drift/wasm.dart'; // Revert to Wasm
import 'package:flutter/foundation.dart'; // For debugPrint

DatabaseConnection connect() {
  debugPrint("Attempting to connect to Drift database on web using Wasm (sqlite3.wasm and drift_worker.js).");
  return DatabaseConnection.delayed(
    Future(() async {
      final result = await WasmDatabase.open(
        databaseName: 'gemini_chat_app_drift_web_wasm', // New name for Wasm DB
        sqlite3Uri: Uri.parse('/sqlite3.wasm'), 
        driftWorkerUri: Uri.parse('/drift_worker.js'),
      );

      if (result.missingFeatures.isNotEmpty) {
        debugPrint('Using ${result.chosenImplementation} due to missing browser features: ${result.missingFeatures}');
      }
      return result.resolvedExecutor;
    }),
  );
}

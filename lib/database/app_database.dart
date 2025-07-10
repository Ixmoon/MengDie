
import 'package:drift/drift.dart';
import 'package:logging/logging.dart';

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
import 'models/drift_context_config.dart';
import 'models/drift_xml_rule.dart';
import 'common_enums.dart';
// path_provider and path are only needed in native.dart now.


part 'app_database.g.dart'; // Drift will generate this file

final _log = Logger('AppDatabase');

@DriftDatabase(tables: [Chats, Messages, ApiConfigs], daos: [ChatDao, MessageDao, ApiConfigDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(connect()); // Use the conditionally imported connect()

  AppDatabase.forTesting(super.connection);

  @override
  int get schemaVersion => 16; // Bump version to 16 for a comprehensive fix

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // Each migration builds on the last.
      // We wrap calls in try-catch to make them idempotent, preventing crashes
      // if a previous, failed migration partially completed a step.
      if (from < 2) {
        try { await m.addColumn(chats, chats.coverImageBase64); } catch (e) { _log.warning("Migration warning (from < 2): ${e.toString()}"); }
      }
      if (from < 4) {
        try { await m.addColumn(chats, chats.enablePreprocessing); } catch (e) { _log.warning("Migration warning (from < 4): ${e.toString()}"); }
        try { await m.addColumn(chats, chats.preprocessingPrompt); } catch (e) { _log.warning("Migration warning (from < 4): ${e.toString()}"); }
        try { await m.addColumn(chats, chats.contextSummary); } catch (e) { _log.warning("Migration warning (from < 4): ${e.toString()}"); }
        try { await m.addColumn(chats, chats.enableSecondaryXml); } catch (e) { _log.warning("Migration warning (from < 4): ${e.toString()}"); }
        try { await m.addColumn(chats, chats.secondaryXmlPrompt); } catch (e) { _log.warning("Migration warning (from < 4): ${e.toString()}"); }
        try { await m.addColumn(messages, messages.originalXmlContent); } catch (e) { _log.warning("Migration warning (from < 4): ${e.toString()}"); }
      }
      if (from < 5) {
        try { await m.addColumn(chats, chats.continuePrompt); } catch (e) { _log.warning("Migration warning (from < 5): ${e.toString()}"); }
      }
      if (from < 6) {
        try { await m.addColumn(messages, messages.secondaryXmlContent); } catch (e) { _log.warning("Migration warning (from < 6): ${e.toString()}"); }
      }
      if (from < 9) {
        try { await m.createTable(apiConfigs); } catch (e) { _log.warning("Migration warning (from < 9): ${e.toString()}"); }
        try { await m.addColumn(chats, chats.apiConfigId); } catch (e) { _log.warning("Migration warning (from < 9): ${e.toString()}"); }
      }
      if (from < 10) {
        try { await m.addColumn(apiConfigs, apiConfigs.useCustomTemperature); } catch (e) { _log.warning("Migration warning (from < 10): ${e.toString()}"); }
        try { await m.addColumn(apiConfigs, apiConfigs.useCustomTopP); } catch (e) { _log.warning("Migration warning (from < 10): ${e.toString()}"); }
        try { await m.addColumn(apiConfigs, apiConfigs.useCustomTopK); } catch (e) { _log.warning("Migration warning (from < 10): ${e.toString()}"); }
      }
      if (from < 11) {
        // This version is just to ensure the idempotent logic from v10 runs correctly
        // for users who might be stuck in a broken state. No new schema changes.
        // We can re-add the try-catch blocks here defensively.
        try { await m.addColumn(apiConfigs, apiConfigs.useCustomTemperature); } catch (e) { _log.warning("Migration warning (from < 11): ${e.toString()}"); }
        try { await m.addColumn(apiConfigs, apiConfigs.useCustomTopP); } catch (e) { _log.warning("Migration warning (from < 11): ${e.toString()}"); }
        try { await m.addColumn(apiConfigs, apiConfigs.useCustomTopK); } catch (e) { _log.warning("Migration warning (from < 11): ${e.toString()}"); }
      }
      if (from < 12) {
        try { await m.addColumn(chats, chats.preprocessingApiConfigId); } catch (e) { _log.warning("Migration warning (from < 12): ${e.toString()}"); }
        try { await m.addColumn(chats, chats.secondaryXmlApiConfigId); } catch (e) { _log.warning("Migration warning (from < 12): ${e.toString()}"); }
      }
      if (from < 13) {
        // This migration is to fix a bug where columns from schema version 4 were not added correctly for some users.
        try { await m.addColumn(chats, chats.enablePreprocessing); } catch (e) { _log.warning("Migration warning (from < 13): ${e.toString()}"); }
        try { await m.addColumn(chats, chats.preprocessingPrompt); } catch (e) { _log.warning("Migration warning (from < 13): ${e.toString()}"); }
        try { await m.addColumn(chats, chats.contextSummary); } catch (e) { _log.warning("Migration warning (from < 13): ${e.toString()}"); }
        try { await m.addColumn(chats, chats.enableSecondaryXml); } catch (e) { _log.warning("Migration warning (from < 13): ${e.toString()}"); }
        try { await m.addColumn(chats, chats.secondaryXmlPrompt); } catch (e) { _log.warning("Migration warning (from < 13): ${e.toString()}"); }
        try { await m.addColumn(messages, messages.originalXmlContent); } catch (e) { _log.warning("Migration warning (from < 13): ${e.toString()}"); }
      }
      if (from < 16) {
        // This is a comprehensive "catch-all" migration to fix various states of corruption.
        // It re-adds columns from multiple previous versions idempotently to ensure consistency.
        _log.info('Running comprehensive migration for version 16 to ensure all columns exist.');
        try { await m.addColumn(chats, chats.enablePreprocessing); } catch (e) { /* ignore */ }
        try { await m.addColumn(chats, chats.preprocessingPrompt); } catch (e) { /* ignore */ }
        try { await m.addColumn(chats, chats.contextSummary); } catch (e) { /* ignore */ }
        try { await m.addColumn(chats, chats.enableSecondaryXml); } catch (e) { /* ignore */ }
        try { await m.addColumn(chats, chats.secondaryXmlPrompt); } catch (e) { /* ignore */ }
        try { await m.addColumn(messages, messages.originalXmlContent); } catch (e) { /* ignore */ }
        try { await m.addColumn(chats, chats.continuePrompt); } catch (e) { /* ignore */ }
        try { await m.addColumn(chats, chats.apiType); } catch (e) { /* ignore */ }
        try { await m.addColumn(chats, chats.generationConfig); } catch (e) { /* ignore */ }
        try { await m.addColumn(chats, chats.apiConfigId); } catch (e) { /* ignore */ }
        try { await m.addColumn(chats, chats.preprocessingApiConfigId); } catch (e) { /* ignore */ }
        try { await m.addColumn(chats, chats.secondaryXmlApiConfigId); } catch (e) { /* ignore */ }
      }
    },
  );


}

// _openConnection function is now removed, using connect() from conditional import.

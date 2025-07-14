
import 'package:drift/drift.dart';
import 'package:logging/logging.dart';

import 'connections/native.dart' if (dart.library.html) 'connections/web.dart';
import 'connections/remote.dart';
import 'sync/sync_service.dart';

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
import 'models/drift_context_config.dart';
import 'models/drift_xml_rule.dart';
import '../models/enums.dart';
// path_provider and path are only needed in native.dart now.


part 'app_database.g.dart'; // Drift will generate this file

final _log = Logger('AppDatabase');

@DriftDatabase(tables: [Chats, Messages, ApiConfigs, Users], daos: [ChatDao, MessageDao, ApiConfigDao, UserDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(connect()) {
    // Pass the database instance itself to the SyncService for rollback capabilities.
    SyncService.initialize(this, connectRemote);
  }

  AppDatabase.forTesting(super.connection);

  // The transactionExecutor getter is removed as SyncService will use
  // the transaction() method directly to ensure a proper transaction context.

  @override
  int get schemaVersion => 29; // Make all non-essential columns nullable.

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
        try { await m.addColumn(messages, messages.originalXmlContent); } catch (e) { /* ignore */  }
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
      if (from < 17) {
        _log.info('Running migration for version 17 to add reasoning_effort fields.');
        try { await m.addColumn(apiConfigs, apiConfigs.enableReasoningEffort); } catch (e) { /* ignore */ }
        try { await m.addColumn(apiConfigs, apiConfigs.reasoningEffort); } catch (e) { /* ignore */ }
      }
      if (from < 19) {
        _log.info('Running migration for version 19 to ensure reasoning_effort columns are correctly added with defaults.');
        try { await m.addColumn(apiConfigs, apiConfigs.enableReasoningEffort); } catch (e) { /* ignore */ }
        try { await m.addColumn(apiConfigs, apiConfigs.reasoningEffort); } catch (e) { /* ignore */ }
      }
      if (from < 20) {
        _log.info('Running migration for version 20 to add users table.');
        try { await m.createTable(users); } catch (e) { /* ignore */ }
      }
      if (from < 21) {
        _log.info('Running migration for version 21 to add "Help Me Reply" fields to chats table.');
        try { await m.addColumn(chats, chats.enableHelpMeReply); } catch (e) { /* ignore */ }
        try { await m.addColumn(chats, chats.helpMeReplyPrompt); } catch (e) { /* ignore */ }
        try { await m.addColumn(chats, chats.helpMeReplyApiConfigId); } catch (e) { /* ignore */ }
        try { await m.addColumn(chats, chats.helpMeReplyTriggerMode); } catch (e) { /* ignore */ }
      }
      if (from < 22) {
        _log.info('Running migration for version 22 to add global settings to users table.');
        try { await m.addColumn(users, users.enableAutoTitleGeneration); } catch (e) { /* ignore */ }
        try { await m.addColumn(users, users.titleGenerationPrompt); } catch (e) { /* ignore */ }
        try { await m.addColumn(users, users.titleGenerationApiConfigId); } catch (e) { /* ignore */ }
        try { await m.addColumn(users, users.enableResume); } catch (e) { /* ignore */ }
        try { await m.addColumn(users, users.resumePrompt); } catch (e) { /* ignore */ }
        try { await m.addColumn(users, users.resumeApiConfigId); } catch (e) { /* ignore */ }
      }
      if (from < 23) {
        try { await m.addColumn(apiConfigs, apiConfigs.userId); } catch (e) { /* ignore */ }
      }
      if (from < 24) {
        try { await m.addColumn(users, users.geminiApiKeys); } catch (e) { /* ignore */ }
      }
      if (from < 25) {
        _log.info('Running comprehensive re-migration for data isolation fields.');
        try { await m.addColumn(apiConfigs, apiConfigs.userId); } catch (e) { /* ignore */ }
        try { await m.addColumn(users, users.geminiApiKeys); } catch (e) { /* ignore */ }
      }
      if (from < 26) {
        // This migration was attempted incorrectly. It is now superseded by version 27.
      }
      if (from < 27) {
        // Migration 27 was a failed attempt and is now obsolete.
      }
      // Versions 26, 27, and 28 were part of a faulty debugging process and are now obsolete.
      // The final, correct migration is to version 29.
      if (from < 29) {
        _log.info('Running migration for version 29: Recreating all tables to make columns nullable.');
        
        // --- Recreate Users Table ---
        try {
          await m.issueCustomQuery('ALTER TABLE users RENAME TO users_old_v28_final;');
          await m.createTable(users);
          await m.issueCustomQuery('''
            INSERT INTO users (id, username, password_hash, chat_ids, enable_auto_title_generation, title_generation_prompt, title_generation_api_config_id, enable_resume, resume_prompt, resume_api_config_id, gemini_api_keys)
            SELECT id, username, password_hash, chat_ids, enable_auto_title_generation, title_generation_prompt, title_generation_api_config_id, enable_resume, resume_prompt, resume_api_config_id, gemini_api_keys FROM users_old_v28_final;
          ''');
          await m.issueCustomQuery('DROP TABLE users_old_v28_final;');
        } catch (e) {
          _log.warning('Could not migrate users table, it might not exist or is already in the new format. Error: $e');
          try { await m.issueCustomQuery('DROP TABLE users_old_v28_final;'); } catch (_) {}
          await m.createTable(users);
        }

        // --- Recreate ApiConfigs Table ---
        try {
          await m.issueCustomQuery('ALTER TABLE api_configs RENAME TO api_configs_old_v28_final;');
          await m.createTable(apiConfigs);
          await m.issueCustomQuery('''
            INSERT INTO api_configs (user_id, id, name, api_type, model, api_key, base_url, use_custom_temperature, temperature, use_custom_top_p, top_p, use_custom_top_k, top_k, max_output_tokens, stop_sequences, enable_reasoning_effort, reasoning_effort, created_at, updated_at)
            SELECT user_id, id, name, api_type, model, api_key, base_url, use_custom_temperature, temperature, use_custom_top_p, top_p, use_custom_top_k, top_k, max_output_tokens, stop_sequences, enable_reasoning_effort, reasoning_effort, created_at, updated_at FROM api_configs_old_v28_final;
          ''');
          await m.issueCustomQuery('DROP TABLE api_configs_old_v28_final;');
        } catch (e) {
          _log.warning('Could not migrate api_configs table. Error: $e');
          try { await m.issueCustomQuery('DROP TABLE api_configs_old_v28_final;'); } catch (_) {}
          await m.createTable(apiConfigs);
        }

        // --- Recreate Chats Table ---
        try {
          await m.issueCustomQuery('ALTER TABLE chats RENAME TO chats_old_v28_final;');
          await m.createTable(chats);
          await m.issueCustomQuery('''
            INSERT INTO chats (id, title, system_prompt, created_at, updated_at, cover_image_base64, background_image_path, order_index, is_folder, parent_folder_id, context_config, xml_rules, api_config_id, api_type, generation_config, enable_preprocessing, preprocessing_prompt, context_summary, preprocessing_api_config_id, enable_secondary_xml, secondary_xml_prompt, secondary_xml_api_config_id, continue_prompt, enable_help_me_reply, help_me_reply_prompt, help_me_reply_api_config_id, help_me_reply_trigger_mode)
            SELECT id, title, system_prompt, created_at, updated_at, cover_image_base64, background_image_path, order_index, is_folder, parent_folder_id, context_config, xml_rules, api_config_id, api_type, generation_config, enable_preprocessing, preprocessing_prompt, context_summary, preprocessing_api_config_id, enable_secondary_xml, secondary_xml_prompt, secondary_xml_api_config_id, continue_prompt, enable_help_me_reply, help_me_reply_prompt, help_me_reply_api_config_id, help_me_reply_trigger_mode FROM chats_old_v28_final;
          ''');
          await m.issueCustomQuery('DROP TABLE chats_old_v28_final;');
        } catch (e) {
           _log.warning('Could not migrate chats table. Error: $e');
           try { await m.issueCustomQuery('DROP TABLE chats_old_v28_final;'); } catch (_) {}
           await m.createTable(chats);
        }
      }
    },
  );


}

// _openConnection function is now removed, using connect() from conditional import.

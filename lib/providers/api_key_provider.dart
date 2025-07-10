import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../database/common_enums.dart';
import '../repositories/api_config_repository.dart';
import '../repositories/chat_repository.dart';
import 'repository_providers.dart' show apiConfigRepositoryProvider;

// --- State ---
@immutable
class ApiKeyState {
  final List<ApiConfig> apiConfigs;
  final List<String> geminiApiKeys;
  final int geminiApiKeyIndex;
  final String? error;

  const ApiKeyState({
    this.apiConfigs = const [],
    this.geminiApiKeys = const [],
    this.geminiApiKeyIndex = 0,
    this.error,
  });

  ApiKeyState copyWith({
    List<ApiConfig>? apiConfigs,
    List<String>? geminiApiKeys,
    int? geminiApiKeyIndex,
    String? error,
    bool clearError = false,
  }) {
    return ApiKeyState(
      apiConfigs: apiConfigs ?? this.apiConfigs,
      geminiApiKeys: geminiApiKeys ?? this.geminiApiKeys,
      geminiApiKeyIndex: geminiApiKeyIndex ?? this.geminiApiKeyIndex,
      error: clearError ? null : error ?? this.error,
    );
  }

  bool get hasAnyValidConfig => apiConfigs.isNotEmpty;
  bool get hasGeminiKey => geminiApiKeys.isNotEmpty;
}

// --- Notifier ---
class ApiKeyNotifier extends StateNotifier<ApiKeyState> {
  final ApiConfigRepository _repository;
  final ChatRepository _chatRepository;
  static const _geminiKeysPrefKey = 'gemini_api_keys';
  static const _migrationV11PrefKey = 'migrated_chat_configs_to_v11';

  ApiKeyNotifier(this._repository, this._chatRepository) : super(const ApiKeyState());

  Future<void> init() async {
    await _loadConfigs();
    await loadGeminiKeys();
    await _migrateOldChatDataIfNeeded();
    debugPrint("ApiKeyNotifier initialized with ${state.apiConfigs.length} API configs and ${state.geminiApiKeys.length} Gemini keys.");
  }

  Future<void> saveConfig({
    String? id,
    required String name,
    required LlmType apiType,
    required String model,
    String? apiKey,
    String? baseUrl,
    bool useCustomTemperature = false,
    double? temperature,
    bool useCustomTopP = false,
    double? topP,
    bool useCustomTopK = false,
    int? topK,
    int? maxOutputTokens,
    List<String>? stopSequences,
  }) async {
    final configId = id ?? const Uuid().v4();
    
    final companion = ApiConfigsCompanion(
      id: Value(configId),
      name: Value(name),
      apiType: Value(apiType),
      model: Value(model),
      apiKey: Value(apiKey),
      baseUrl: Value(baseUrl),
      useCustomTemperature: Value(useCustomTemperature),
      temperature: Value(temperature),
      useCustomTopP: Value(useCustomTopP),
      topP: Value(topP),
      useCustomTopK: Value(useCustomTopK),
      topK: Value(topK),
      maxOutputTokens: Value(maxOutputTokens),
      stopSequences: Value(stopSequences),
      updatedAt: Value(DateTime.now()),
    );

    await _repository.saveConfig(companion);
    await _loadConfigs();
    debugPrint("Saved API config: $name");
  }

  Future<void> deleteConfig(String id) async {
    await _repository.deleteConfig(id);
    await _loadConfigs();
    debugPrint("Deleted API config ID: $id");
  }

  ApiConfig? getConfigById(String? id) {
    if (id == null) return null;
    try {
      return state.apiConfigs.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> _loadConfigs() async {
    final configs = await _repository.getAllConfigs();
    state = state.copyWith(apiConfigs: configs, clearError: true);
  }

  Future<void> loadGeminiKeys() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> keys = [];
    final dynamic storedKeys = prefs.get(_geminiKeysPrefKey);

    if (storedKeys is List) {
      keys = storedKeys.map((e) => e.toString()).toList();
    } else if (storedKeys is String) {
      if (storedKeys.isNotEmpty) {
        keys = [storedKeys];
      }
    }
    state = state.copyWith(geminiApiKeys: keys, geminiApiKeyIndex: 0);
  }

  Future<void> addGeminiKey(String key) async {
    if (key.isEmpty || state.geminiApiKeys.contains(key)) return;
    final newKeys = [...state.geminiApiKeys, key];
    state = state.copyWith(geminiApiKeys: newKeys);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_geminiKeysPrefKey, newKeys);
  }

  Future<void> deleteGeminiKey(String key) async {
    final newKeys = state.geminiApiKeys.where((k) => k != key).toList();
    state = state.copyWith(geminiApiKeys: newKeys);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_geminiKeysPrefKey, newKeys);
  }

  Future<void> clearAllGeminiKeys() async {
    state = state.copyWith(geminiApiKeys: []);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_geminiKeysPrefKey);
  }

  String? getNextGeminiApiKey() {
    if (state.geminiApiKeys.isEmpty) {
      return null;
    }
    final index = state.geminiApiKeyIndex % state.geminiApiKeys.length;
    final key = state.geminiApiKeys[index];
    state = state.copyWith(geminiApiKeyIndex: index + 1);
    return key;
  }

  // --- Data Migration ---
  Future<void> _migrateOldChatDataIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migrationV11PrefKey) ?? false) {
      return;
    }

    debugPrint("Starting one-time data migration for chat generation configs...");
    try {
      final oldChats = await _chatRepository.getRawChatsForMigration();
      for (final oldChat in oldChats) {
        final oldGenConfig = oldChat['generation_config'];
        final oldApiTypeStr = oldChat['api_type'] as String?;
        
        if (oldGenConfig != null) {
          final newConfigId = const Uuid().v4();
          final newConfigName = "Migrated - ${oldChat['title'] ?? oldChat['id']}";
          
          await saveConfig(
            id: newConfigId,
            name: newConfigName,
            apiType: oldApiTypeStr == 'openai' ? LlmType.openai : LlmType.gemini,
            model: oldGenConfig['modelName'] ?? 'gemini-1.5-pro-latest',
            useCustomTemperature: oldGenConfig['useCustomTemperature'] ?? false,
            temperature: oldGenConfig['temperature'],
            useCustomTopP: oldGenConfig['useCustomTopP'] ?? false,
            topP: oldGenConfig['topP'],
            useCustomTopK: oldGenConfig['useCustomTopK'] ?? false,
            topK: oldGenConfig['topK'],
            maxOutputTokens: oldGenConfig['maxOutputTokens'],
            stopSequences: (oldGenConfig['stopSequences'] as List<dynamic>?)?.cast<String>(),
          );
          
          await _chatRepository.updateApiConfigId(oldChat['id'] as int, newConfigId);
        }
      }
      
      await prefs.setBool(_migrationV11PrefKey, true);
      debugPrint("One-time data migration completed successfully.");
    } catch (e) {
      debugPrint("Error during one-time data migration: $e");
    }
  }
}

// --- Provider ---
final apiKeyNotifierProvider = StateNotifierProvider<ApiKeyNotifier, ApiKeyState>((ref) {
  final apiConfigRepo = ref.watch(apiConfigRepositoryProvider);
  final chatRepo = ref.watch(chatRepositoryProvider);
  final notifier = ApiKeyNotifier(apiConfigRepo, chatRepo);
  notifier.init();
  return notifier;
});

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/api_config.dart'; // Use the new domain model
import '../../data/models/enums.dart'; // Use the pure enums
import '../../data/repositories/api_config_repository.dart';
import '../../data/repositories/chat_repository.dart' hide chatRepositoryProvider;
import '../../data/repositories/user_repository.dart';
import 'auth_providers.dart';
import 'repository_providers.dart' show apiConfigRepositoryProvider, chatRepositoryProvider, userRepositoryProvider;

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
  final ApiConfigRepository _apiConfigRepository;
  final ChatRepository _chatRepository;
  final UserRepository _userRepository;
  final Ref _ref;

  static const _geminiKeysPrefKey = 'gemini_api_keys'; // For migration
  static const _geminiKeysMigratedPrefKey = 'gemini_keys_migrated_to_db';
  static const _migrationV11PrefKey = 'migrated_chat_configs_to_v11';
  
  int? get _userId => _ref.read(authProvider).currentUser?.id;

  ApiKeyNotifier(this._apiConfigRepository, this._chatRepository, this._userRepository, this._ref) : super(const ApiKeyState());

  Future<void> init() async {
    _ref.listen<AuthState>(authProvider, (previous, next) {
      // If the user logs in, logs out, or the user object itself changes, reload all data.
      if (previous?.currentUser != next.currentUser) {
        _loadAllUserData();
      }
    }, fireImmediately: true);
    
    await _migrateOldChatDataIfNeeded();
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
    // Gemini specific settings
    bool enableReasoningEffort = false,
    OpenAIReasoningEffort? reasoningEffort,
  }) async {
    final now = DateTime.now();
    final configId = id ?? const Uuid().v4();

    // Create the domain model instance directly
    final config = ApiConfig(
      id: configId,
      name: name,
      apiType: apiType,
      model: model,
      apiKey: apiKey,
      baseUrl: baseUrl,
      useCustomTemperature: useCustomTemperature,
      temperature: temperature,
      useCustomTopP: useCustomTopP,
      topP: topP,
      useCustomTopK: useCustomTopK,
      topK: topK,
      maxOutputTokens: maxOutputTokens,
      stopSequences: stopSequences,
      createdAt: id == null ? now : (getConfigById(id)?.createdAt ?? now), // Preserve original creation time on update
      updatedAt: now,
      enableReasoningEffort: enableReasoningEffort,
      reasoningEffort: reasoningEffort,
    );

    if (_userId == null) {
      return;
    }
    await _apiConfigRepository.saveConfig(config, _userId!);
    await _loadConfigs();
  }

  Future<void> deleteConfig(String id) async {
    if (_userId == null) {
      return;
    }
    await _apiConfigRepository.deleteConfig(id, _userId!);
    await _loadConfigs();
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
    if (_userId == null) {
      state = state.copyWith(apiConfigs: [], clearError: true);
      return;
    }
    final configs = await _apiConfigRepository.getAllConfigs(_userId!);
    state = state.copyWith(apiConfigs: configs, clearError: true);
  }

  Future<void> _loadGeminiKeys() async {
    final currentUser = _ref.read(authProvider).currentUser;
    if (currentUser != null) {
      state = state.copyWith(geminiApiKeys: currentUser.geminiApiKeys, geminiApiKeyIndex: 0);
    } else {
      state = state.copyWith(geminiApiKeys: [], geminiApiKeyIndex: 0);
    }
  }

  Future<void> addGeminiKey(String key) async {
    final currentUser = _ref.read(authProvider).currentUser;
    if (key.isEmpty || currentUser == null || currentUser.geminiApiKeys.contains(key)) return;
    
    final newKeys = [...currentUser.geminiApiKeys, key];
    await _userRepository.updateUserSettings(currentUser.copyWith(geminiApiKeys: newKeys));
    // The listener on authProvider will now handle the state refresh automatically.
  }

  Future<void> deleteGeminiKey(String key) async {
    final currentUser = _ref.read(authProvider).currentUser;
    if (currentUser == null) return;

    // The user object from the authProvider is guaranteed to have a non-null list.
    final newKeys = currentUser.geminiApiKeys.where((k) => k != key).toList();
    await _userRepository.updateUserSettings(currentUser.copyWith(geminiApiKeys: newKeys));
  }

  Future<void> clearAllGeminiKeys() async {
    final currentUser = _ref.read(authProvider).currentUser;
    if (currentUser == null) return;
    
    await _userRepository.updateUserSettings(currentUser.copyWith(geminiApiKeys: []));
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
  Future<void> _loadAllUserData() async {
    await _loadConfigs();
    await _loadGeminiKeys();
    await _migrateGeminiKeysFromPrefs(); // Run migration after user is loaded
  }

  Future<void> _migrateGeminiKeysFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_geminiKeysMigratedPrefKey) ?? false) {
      return;
    }

    final currentUser = _ref.read(authProvider).currentUser;
    if (currentUser == null || currentUser.isGuestMode) {
      return;
    }

    List<String> oldKeys = [];
    final dynamic storedKeys = prefs.get(_geminiKeysPrefKey);
    if (storedKeys is List) {
      oldKeys = storedKeys.map((e) => e.toString()).toList();
    } else if (storedKeys is String && storedKeys.isNotEmpty) {
      oldKeys = [storedKeys];
    }

    if (oldKeys.isNotEmpty) {
      final newKeys = {...currentUser.geminiApiKeys, ...oldKeys}.toList();
      await _userRepository.updateUserSettings(currentUser.copyWith(geminiApiKeys: newKeys));
      await prefs.remove(_geminiKeysPrefKey); // Clean up old key
    }
    
    await prefs.setBool(_geminiKeysMigratedPrefKey, true);
  }

  Future<void> _migrateOldChatDataIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migrationV11PrefKey) ?? false) {
      return;
    }

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
            // No reasoning effort settings to migrate from old data
          );
          
          await _chatRepository.updateApiConfigId(oldChat['id'] as int, newConfigId);
        }
      }
      
      await prefs.setBool(_migrationV11PrefKey, true);
    } catch (e) {
      // Errors in one-time migrations should not crash the app.
      // They can be logged to a more persistent store if needed.
    }
  }
}

// --- Provider ---
final apiKeyNotifierProvider = StateNotifierProvider<ApiKeyNotifier, ApiKeyState>((ref) {
  final apiConfigRepo = ref.watch(apiConfigRepositoryProvider);
  final chatRepo = ref.watch(chatRepositoryProvider);
  final userRepo = ref.watch(userRepositoryProvider);
  final notifier = ApiKeyNotifier(apiConfigRepo, chatRepo, userRepo, ref);
  notifier.init();
  return notifier;
});

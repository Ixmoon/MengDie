import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/api_config.dart'; // Use the new domain model
import '../../domain/enums.dart'; // Use the pure enums
import '../repositories/api_config_repository.dart';
import '../repositories/chat_repository.dart' hide chatRepositoryProvider;
import '../repositories/user_repository.dart';
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

  int? get _userId => _ref.read(authProvider).currentUser?.id;

  ApiKeyNotifier(this._apiConfigRepository, this._chatRepository, this._userRepository, this._ref) : super(const ApiKeyState());

  Future<void> init() async {
    _ref.listen<AuthState>(authProvider, (previous, next) {
      // If the user logs in, logs out, or the user object itself changes, reload all data.
      if (previous?.currentUser != next.currentUser) {
        _loadAllUserData();
      }
    }, fireImmediately: true);
    
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
    // OpenAI specific settings
    bool enableReasoningEffort = false,
    OpenAIReasoningEffort? reasoningEffort,
    String? toolChoice,
    // Gemini specific settings
    int? thinkingBudget,
    String? toolConfig,
    bool useDefaultSafetySettings = true,
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
      thinkingBudget: thinkingBudget,
      toolConfig: toolConfig,
      toolChoice: toolChoice,
      useDefaultSafetySettings: useDefaultSafetySettings,
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

  Future<void> _loadAllUserData() async {
    await _loadConfigs();
    await _loadGeminiKeys();
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

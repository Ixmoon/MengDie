import 'package:flutter/foundation.dart'; // for immutable, debugPrint
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/drift/models/drift_openai_api_config.dart';
import '../repositories/api_config_repository.dart';
import 'repository_providers.dart'; // Import the new repository provider

// 本文件包含用于管理 API 配置（Gemini 和 OpenAI）的状态和逻辑。

// --- API Key State ---
// 用于表示 API Key 状态的不可变类
@immutable
class ApiKeyState {
  final List<String> keys; // 存储的所有 Gemini API Key
  final int currentIndex; // 当前轮询到的 Gemini Key 的索引
  final List<DriftOpenAIAPIConfig> openAIConfigs; // Use DriftOpenAIAPIConfig
  final String? error; // 与 API Key 相关的错误信息 (例如，输入无效、无可用 Key)

  const ApiKeyState({
    required this.keys,
    this.currentIndex = 0,
    required this.openAIConfigs,
    this.error,
  });

  // copyWith 方法，用于创建状态的副本并更新部分字段，保持不可变性
  ApiKeyState copyWith({
    List<String>? keys,
    int? currentIndex,
    List<DriftOpenAIAPIConfig>? openAIConfigs, // Use DriftOpenAIAPIConfig
    String? error,
    bool clearError = false,
  }) {
    return ApiKeyState(
      keys: keys ?? this.keys,
      currentIndex: currentIndex ?? this.currentIndex,
      openAIConfigs: openAIConfigs ?? this.openAIConfigs, // Use DriftOpenAIAPIConfig
      // 明确处理错误清除逻辑
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// --- API Key StateNotifier ---
// StateNotifier 用于管理 ApiKeyState
class ApiKeyNotifier extends StateNotifier<ApiKeyState> {
  final ApiConfigRepository _repository;

  ApiKeyNotifier(this._repository) : super(const ApiKeyState(keys: [], openAIConfigs: []));

  // 异步初始化方法，从 Repository 加载数据
  Future<void> init() async {
    final configs = await _repository.getAllConfigs();
    state = state.copyWith(
      keys: configs.geminiApiKeys,
      openAIConfigs: configs.openAIConfigs,
      currentIndex: 0, // 每次启动时重置轮询索引
    );
    debugPrint("ApiKeyNotifier initialized: ${configs.geminiApiKeys.length} Gemini keys, ${configs.openAIConfigs.length} OpenAI configs.");
  }

  // 添加一个或多个 Gemini API Key (以逗号分隔)
  Future<void> addKeys(String keysInput) async {
    if (keysInput.trim().isEmpty) {
      state = state.copyWith(error: "输入不能为空", clearError: false);
      return;
    }

    final potentialKeys = keysInput.split(',').map((k) => k.trim()).where((k) => k.isNotEmpty).toList();
    final keysToAdd = potentialKeys.where((k) => !state.keys.contains(k)).toList();
    final duplicateCount = potentialKeys.length - keysToAdd.length;

    if (keysToAdd.isEmpty) {
      state = state.copyWith(error: "所有输入的 Key 都已存在", clearError: false);
      return;
    }

    // 更新数据库
    await _repository.addGeminiApiKeys(keysToAdd);

    // 更新状态
    state = state.copyWith(keys: [...state.keys, ...keysToAdd], clearError: true);

    String message = "成功添加 ${keysToAdd.length} 个 Gemini Key。";
    if (duplicateCount > 0) {
      message += " $duplicateCount 个 Key 已存在被忽略。";
    }
    debugPrint(message);
  }

  // 移除指定的 API Key
  Future<void> removeKey(String keyToRemove) async {
    final currentKeys = List<String>.from(state.keys);
    if (currentKeys.contains(keyToRemove)) {
      // 更新数据库
      await _repository.deleteGeminiApiKey(keyToRemove);
      
      // 更新状态
      currentKeys.remove(keyToRemove);
      int newIndex = state.currentIndex;
      if (newIndex >= currentKeys.length) {
        newIndex = currentKeys.isEmpty ? 0 : currentKeys.length - 1;
      }
      state = state.copyWith(keys: currentKeys, currentIndex: newIndex, clearError: true);
      debugPrint("移除了 Gemini API Key: ${keyToRemove.substring(0, 5)}...");
    }
  }

  // 获取下一个可用的 API Key (实现轮询逻辑)
  String? getNextApiKey() {
    if (state.keys.isEmpty) {
      state = state.copyWith(error: "没有可用的 Gemini API Key。请在设置中添加。", clearError: false);
      debugPrint("错误：没有可用的 Gemini API Key。");
      return null;
    }

    final keyIndex = state.currentIndex % state.keys.length;
    final key = state.keys[keyIndex];
    final nextIndex = (keyIndex + 1) % state.keys.length;

    // 只更新内存中的索引，不再持久化
    state = state.copyWith(currentIndex: nextIndex, clearError: true);

    debugPrint("正在使用索引 $keyIndex 的 API Key: ${key.substring(0, 5)}...");
    return key;
  }

  // 报告某个 API Key 遇到错误
  void reportKeyError(String apiKeyWithError) {
    debugPrint("API Key 报告错误: ${apiKeyWithError.substring(0, 5)}...");
  }

  // 清空所有 Gemini API Key
  Future<void> clearAllGeminiKeys() async {
    // 更新数据库
    await _repository.clearAllGeminiApiKeys();
    
    // 更新状态
    state = state.copyWith(keys: [], currentIndex: 0, clearError: true);
    debugPrint("所有 Gemini API Key 已被清空。");
  }

  // --- OpenAI API 配置管理 ---
  Future<void> addOpenAIConfig(DriftOpenAIAPIConfig config) async {
    if (state.openAIConfigs.any((c) => c.id == config.id)) {
      state = state.copyWith(error: "已存在相同 ID 的 OpenAI 配置。", clearError: false);
      return;
    }
    // 更新数据库
    await _repository.saveOpenAIConfig(config);
    // 更新状态
    state = state.copyWith(openAIConfigs: [...state.openAIConfigs, config], clearError: true);
    debugPrint("添加了 OpenAI 配置: ${config.name}");
  }

  Future<void> updateOpenAIConfig(DriftOpenAIAPIConfig configToUpdate) async {
    final index = state.openAIConfigs.indexWhere((c) => c.id == configToUpdate.id);
    if (index == -1) {
      state = state.copyWith(error: "未找到要更新的 OpenAI 配置。", clearError: false);
      return;
    }
    // 更新数据库
    await _repository.saveOpenAIConfig(configToUpdate);
    // 更新状态
    final updatedConfigs = List<DriftOpenAIAPIConfig>.from(state.openAIConfigs);
    updatedConfigs[index] = configToUpdate;
    state = state.copyWith(openAIConfigs: updatedConfigs, clearError: true);
    debugPrint("更新了 OpenAI 配置: ${configToUpdate.name}");
  }

  Future<void> deleteOpenAIConfig(String configId) async {
    if (state.openAIConfigs.any((c) => c.id == configId)) {
      // 更新数据库
      await _repository.deleteOpenAIConfig(configId);
      // 更新状态
      final updatedConfigs = state.openAIConfigs.where((c) => c.id != configId).toList();
      state = state.copyWith(openAIConfigs: updatedConfigs, clearError: true);
      debugPrint("删除了 OpenAI 配置 ID: $configId");
    } else {
      state = state.copyWith(error: "未找到要删除的 OpenAI 配置 ID: $configId", clearError: false);
    }
  }

  DriftOpenAIAPIConfig? getOpenAIConfigById(String configId) {
    try {
      return state.openAIConfigs.firstWhere((c) => c.id == configId);
    } catch (e) {
      return null; // 未找到
    }
  }
}

// --- API Key Provider ---
// StateNotifierProvider，用于在应用中访问 ApiKeyNotifier 实例
final apiKeyNotifierProvider = StateNotifierProvider<ApiKeyNotifier, ApiKeyState>((ref) {
  final repository = ref.watch(apiConfigRepositoryProvider);
  final notifier = ApiKeyNotifier(repository);
  notifier.init(); // 调用异步初始化
  return notifier;
});

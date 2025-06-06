import 'dart:convert'; // 用于 JSON 编解码

import 'package:flutter/foundation.dart'; // for immutable, debugPrint
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// import '../models/embedded_models.dart'; // Commented out: OpenAIAPIConfig is now DriftOpenAIAPIConfig
import '../data/database/drift/models/drift_openai_api_config.dart'; // Import Drift version
import 'core_providers.dart'; // 导入 SharedPreferences Provider

// 本文件包含用于管理 Google Gemini API Key 的状态和逻辑。

// --- SharedPreferences Keys ---
// 用于存储 API Key 列表的键
const String _apiKeyPrefKey = 'gemini_api_keys';
// 用于存储当前使用的 API Key 索引的键
const String _apiKeyIndexPrefKey = 'gemini_api_key_index';
// 新增：用于存储 OpenAI API 配置列表的键
const String _openAIConfigsPrefKey = 'openai_api_configs';

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
  final SharedPreferences _prefs; // SharedPreferences 实例，用于持久化存储

  ApiKeyNotifier(this._prefs) : super(const ApiKeyState(keys: [], openAIConfigs: [])) { // 初始化 openAIConfigs
    _loadKeys(); // 初始化时从 SharedPreferences 加载 Keys 和配置
  }

  // 从 SharedPreferences 加载 Keys 和当前索引
  void _loadKeys() {
    final String? storedKeys = _prefs.getString(_apiKeyPrefKey);
    // 解析存储的字符串，去除空条目
    final List<String> keys = storedKeys == null || storedKeys.isEmpty
        ? []
        : storedKeys.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final int storedIndex = _prefs.getInt(_apiKeyIndexPrefKey) ?? 0;
    // 确保加载后的索引在有效范围内
    final int validIndex = (keys.isEmpty || storedIndex < 0 || storedIndex >= keys.length) ? 0 : storedIndex;

    // 加载 OpenAI 配置
    final String? storedOpenAIConfigs = _prefs.getString(_openAIConfigsPrefKey);
    List<DriftOpenAIAPIConfig> openAIConfigs = []; // Use DriftOpenAIAPIConfig
    if (storedOpenAIConfigs != null && storedOpenAIConfigs.isNotEmpty) {
      try {
        final List<dynamic> decodedList = jsonDecode(storedOpenAIConfigs);
        openAIConfigs = decodedList.map((item) {
          // Use the constructor to pass the ID and other fields
          return DriftOpenAIAPIConfig.fromJson(item as Map<String, dynamic>); // Use Drift model's fromJson
        }).toList();
      } catch (e) {
        debugPrint("解析 OpenAI 配置时出错: $e");
        // 如果解析失败，保持为空列表
      }
    }
    // 更新状态
    state = state.copyWith(keys: keys, currentIndex: validIndex, openAIConfigs: openAIConfigs);
    debugPrint("加载了 ${keys.length} 个 Gemini API Key。当前索引: $validIndex。加载了 ${openAIConfigs.length} 个 OpenAI 配置。");
  }

  // 将当前的 Keys 和索引以及 OpenAI 配置保存到 SharedPreferences
  Future<void> _saveKeysAndConfigs() async {
    await _prefs.setString(_apiKeyPrefKey, state.keys.join(','));
    await _prefs.setInt(_apiKeyIndexPrefKey, state.currentIndex);

    // 保存 OpenAI 配置
    try {
      // Use Drift model's toJson
      final List<Map<String, dynamic>> configsToSave = state.openAIConfigs.map((config) => config.toJson()).toList();
      await _prefs.setString(_openAIConfigsPrefKey, jsonEncode(configsToSave));
    } catch (e) {
      debugPrint("保存 OpenAI 配置时出错: $e");
    }
  }

  // 添加一个或多个 Gemini API Key (以逗号分隔)
   Future<void> addKeys(String keysInput) async {
      // 检查输入是否为空
      if (keysInput.trim().isEmpty) {
         state = state.copyWith(error: "输入不能为空", clearError: false);
         return;
      }

      final List<String> keysToAdd = []; // 准备添加的新 Key
      final List<String> potentialKeys = keysInput.split(',').map((k) => k.trim()).where((k) => k.isNotEmpty).toList();
      int addedCount = 0; // 成功添加计数
      int duplicateCount = 0; // 重复 Key 计数

      // 遍历输入的 Key，检查是否已存在
      for (final key in potentialKeys) {
         if (!state.keys.contains(key)) {
            keysToAdd.add(key);
            addedCount++;
         } else {
            duplicateCount++;
         }
      }

      // 如果没有找到有效的 Key 添加
      if (keysToAdd.isEmpty) {
         if (duplicateCount > 0) {
            state = state.copyWith(error: "所有输入的 Key 都已存在", clearError: false);
         } else {
            // 理论上如果输入不为空，这里不应该发生
            state = state.copyWith(error: "未找到有效的 Key 添加", clearError: false);
         }
         return;
      }

      // 更新状态，添加新的 Key，并清除之前的错误信息
      state = state.copyWith(keys: [...state.keys, ...keysToAdd], clearError: true);
      await _saveKeysAndConfigs(); // 保存到 SharedPreferences

      // 打印日志并可选地设置成功消息
      String message = "成功添加 $addedCount 个 Gemini Key。";
      if (duplicateCount > 0) {
         message += " $duplicateCount 个 Key 已存在被忽略。";
      }
      debugPrint(message);
      // 可以选择在状态中设置成功消息，但目前仅清除错误
      // state = state.copyWith(error: message); // 示例：设置成功消息
   }

   // 移除指定的 API Key
   Future<void> removeKey(String keyToRemove) async {
       final currentKeys = List<String>.from(state.keys); // 创建可变副本
       bool removed = currentKeys.remove(keyToRemove); // 尝试移除

       if (removed) {
          // 如果成功移除，需要调整当前索引以防越界
          int newIndex = state.currentIndex;
          if (newIndex >= currentKeys.length) {
             // 如果索引超出新列表范围，将其设置为最后一个有效索引或 0
             newIndex = currentKeys.isEmpty ? 0 : currentKeys.length - 1;
          }
          // 更新状态并保存
          state = state.copyWith(keys: currentKeys, currentIndex: newIndex);
          await _saveKeysAndConfigs();
          // 打印部分 Key 以确认移除
          debugPrint("移除了 Gemini API Key: ${keyToRemove.substring(0,5)}...");
       }
   }

   // 获取下一个可用的 API Key (实现轮询逻辑)
    String? getNextApiKey() {
        // 如果没有可用的 Key
        if (state.keys.isEmpty) {
    // 更新状态以显示错误
    state = state.copyWith(error: "没有可用的 Gemini API Key。请在设置中添加。", clearError: false);
    debugPrint("错误：没有可用的 Gemini API Key。");
    return null; // 返回 null 表示无 Key 可用
  }

        // 计算当前要使用的 Key 的索引 (确保在范围内循环)
        final keyIndex = state.currentIndex % state.keys.length;
        final key = state.keys[keyIndex]; // 获取 Key

        // 计算下一个 Key 的索引
        int nextIndex = (keyIndex + 1) % state.keys.length;

        // 乐观地更新状态中的索引，并异步保存到 SharedPreferences
        // 成功获取 Key 时清除错误信息
        state = state.copyWith(currentIndex: nextIndex, clearError: true);
        _prefs.setInt(_apiKeyIndexPrefKey, nextIndex); // 异步保存索引

        // 打印部分 Key 以供调试
        debugPrint("正在使用索引 $keyIndex 的 API Key: ${key.substring(0, 5)}...");
        return key; // 返回获取到的 Key
      }

   // 报告某个 API Key 遇到错误 (可用于更高级的错误处理逻辑)
   void reportKeyError(String apiKeyWithError) {
     // 基本实现：仅记录错误日志
     debugPrint("API Key 报告错误: ${apiKeyWithError.substring(0,5)}...");
     // 高级逻辑：可以在这里实现暂时禁用 Key、增加错误计数、
     // 或者立即尝试下一个 Key 的逻辑。
     // 目前，getNextApiKey 中的轮询机制会在 *下一次* 调用时切换到下一个 Key。
   }

  // 清空所有 API Key 和配置
  Future<void> clearAllKeys() async {
    state = state.copyWith(keys: [], currentIndex: 0, openAIConfigs: [], clearError: true);
    await _saveKeysAndConfigs(); // 保存空列表和重置的索引
    debugPrint("所有 Gemini API Key 和 OpenAI 配置已被清空。");
  }

  // --- OpenAI API 配置管理 ---
  Future<void> addOpenAIConfig(DriftOpenAIAPIConfig config) async { // Use DriftOpenAIAPIConfig
    if (state.openAIConfigs.any((c) => c.id == config.id)) {
      state = state.copyWith(error: "已存在相同 ID 的 OpenAI 配置。", clearError: false);
      return;
    }
    // DriftOpenAIAPIConfig's ID is non-nullable and generated in constructor if not provided
    state = state.copyWith(openAIConfigs: [...state.openAIConfigs, config], clearError: true);
    await _saveKeysAndConfigs();
    debugPrint("添加了 OpenAI 配置: ${config.name}");
  }

  Future<void> updateOpenAIConfig(DriftOpenAIAPIConfig configToUpdate) async { // Use DriftOpenAIAPIConfig
    final index = state.openAIConfigs.indexWhere((c) => c.id == configToUpdate.id);
    if (index == -1) {
      state = state.copyWith(error: "未找到要更新的 OpenAI 配置。", clearError: false);
      return;
    }
    final updatedConfigs = List<DriftOpenAIAPIConfig>.from(state.openAIConfigs); // Use DriftOpenAIAPIConfig
    updatedConfigs[index] = configToUpdate;
    state = state.copyWith(openAIConfigs: updatedConfigs, clearError: true);
    await _saveKeysAndConfigs();
    debugPrint("更新了 OpenAI 配置: ${configToUpdate.name}");
  }

  Future<void> deleteOpenAIConfig(String configId) async {
    final initialLength = state.openAIConfigs.length;
    final updatedConfigs = state.openAIConfigs.where((c) => c.id != configId).toList(); // Use DriftOpenAIAPIConfig
    if (updatedConfigs.length < initialLength) {
      state = state.copyWith(openAIConfigs: updatedConfigs, clearError: true);
      await _saveKeysAndConfigs();
      debugPrint("删除了 OpenAI 配置 ID: $configId");
    } else {
      state = state.copyWith(error: "未找到要删除的 OpenAI 配置 ID: $configId", clearError: false);
    }
  }

  DriftOpenAIAPIConfig? getOpenAIConfigById(String configId) { // Use DriftOpenAIAPIConfig
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
  // 依赖 SharedPreferences Provider 来获取 SharedPreferences 实例
  final prefs = ref.watch(sharedPreferencesProvider);
  // 创建并返回 ApiKeyNotifier 实例
  return ApiKeyNotifier(prefs);
});

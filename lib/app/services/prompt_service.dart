import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/prompt_item.dart';
import '../providers/auth_providers.dart';
import '../providers/core_providers.dart';

@immutable
class PromptState {
  final List<PromptItem> globalItems;
  final Map<int, List<PromptItem>> chatItems;
  final Map<int, Map<String, PromptItemStatus>> chatStatuses;

  const PromptState({
    this.globalItems = const [],
    this.chatItems = const {},
    this.chatStatuses = const {},
  });

  PromptState copyWith({
    List<PromptItem>? globalItems,
    Map<int, List<PromptItem>>? chatItems,
    Map<int, Map<String, PromptItemStatus>>? chatStatuses,
  }) {
    return PromptState(
      globalItems: globalItems ?? this.globalItems,
      chatItems: chatItems ?? this.chatItems,
      chatStatuses: chatStatuses ?? this.chatStatuses,
    );
  }
}

final promptServiceProvider =
    StateNotifierProvider.autoDispose<PromptService, PromptState>(
  (ref) {
    final sharedPreferencesAsyncValue = ref.watch(sharedPreferencesProvider);
    final authState = ref.watch(authProvider);
    final userId = authState.currentUser?.id;

    // Use a non-nullable user ID, defaulting to 0 for guest/unauthenticated
    final effectiveUserId = userId ?? 0;

    return sharedPreferencesAsyncValue.when(
      data: (sharedPreferences) =>
          PromptService(sharedPreferences, const Uuid(), effectiveUserId),
      loading: () =>
          PromptService(_DummySharedPreferences(), const Uuid(), effectiveUserId),
      error: (err, stack) => throw Exception(
        'Failed to load SharedPreferences for PromptService: $err',
      ),
    );
  },
);

// A dummy implementation for the loading state to satisfy the notifier type.
class _DummySharedPreferences implements SharedPreferences {
  @override
  Future<bool> clear() async => true;
  @override
  Future<bool> commit() async => true;
  @override
  bool containsKey(String key) => false;
  @override
  Object? get(String key) => null;
  @override
  bool? getBool(String key) => null;
  @override
  double? getDouble(String key) => null;
  @override
  int? getInt(String key) => null;
  @override
  Set<String> getKeys() => {};
  @override
  String? getString(String key) => null;
  @override
  List<String>? getStringList(String key) => [];
  @override
  Future<void> reload() async {}
  @override
  Future<bool> remove(String key) async => true;
  @override
  Future<bool> setBool(String key, bool value) async => true;
  @override
  Future<bool> setDouble(String key, double value) async => true;
  @override
  Future<bool> setInt(String key, int value) async => true;
  @override
  Future<bool> setString(String key, String value) async => true;
  @override
  Future<bool> setStringList(String key, List<String> value) async => true;
}

class PromptService extends StateNotifier<PromptState> {
  final SharedPreferences _prefs;
  final Uuid _uuid;
  final int _userId;

  String get _globalItemsKey => 'prompt_items_global_userId_$_userId';
  String get _chatItemsKey => 'prompt_items_by_chat_userId_$_userId';
  String get _chatStatusesKey => 'prompt_statuses_by_chat_userId_$_userId';

  PromptService(this._prefs, this._uuid, this._userId)
      : super(const PromptState()) {
    // We can now load data even for guest (userId 0), as settings might be stored locally for them
    _loadData();
  }

  Future<void> _loadData() async {
    // 1. Load global items
    final globalItemsJson = _prefs.getStringList(_globalItemsKey) ?? [];
    final globalItems = globalItemsJson
        .map((json) => PromptItem.fromJson(jsonDecode(json)))
        .toList();

    // 2. Load chat-specific items
    final chatItemsJson = _prefs.getString(_chatItemsKey) ?? '{}';
    final decodedChatItems = jsonDecode(chatItemsJson) as Map<String, dynamic>;
    final chatItems = decodedChatItems.map((chatIdStr, itemsList) {
      final chatId = int.parse(chatIdStr);
      final items = (itemsList as List)
          .map((itemJson) =>
              PromptItem.fromJson(jsonDecode(itemJson as String)))
          .toList();
      return MapEntry(chatId, items);
    });

    // 3. Load chat-specific statuses for global items
    final statusesJson = _prefs.getString(_chatStatusesKey) ?? '{}';
    final decodedStatuses = jsonDecode(statusesJson) as Map<String, dynamic>;
    final chatStatuses = decodedStatuses.map((chatIdStr, statusMap) {
      final chatId = int.parse(chatIdStr);
      final statuses = (statusMap as Map<String, dynamic>).map(
        (itemId, status) => MapEntry(itemId, PromptItemStatus.values[status]),
      );
      return MapEntry(chatId, statuses);
    });

    state = PromptState(
      globalItems: globalItems,
      chatItems: chatItems,
      chatStatuses: chatStatuses,
    );
  }

  Future<void> _saveGlobalItems() async {
    final itemsJson =
        state.globalItems.map((item) => jsonEncode(item.toJson())).toList();
    await _prefs.setStringList(_globalItemsKey, itemsJson);
  }

  Future<void> _saveChatItems() async {
    final encodedChatItems = state.chatItems.map((chatId, items) {
      final itemsJson = items.map((item) => jsonEncode(item.toJson())).toList();
      return MapEntry(chatId.toString(), itemsJson);
    });
    await _prefs.setString(_chatItemsKey, jsonEncode(encodedChatItems));
  }

  Future<void> _saveStatuses() async {
    final encodedStatuses = state.chatStatuses.map((chatId, statusMap) {
      final statuses = statusMap.map(
        (itemId, status) => MapEntry(itemId, status.index),
      );
      return MapEntry(chatId.toString(), statuses);
    });
    await _prefs.setString(_chatStatusesKey, jsonEncode(encodedStatuses));
  }

  List<PromptItem> getItemsForChat(int chatId) {
    final chatSpecificItems = (state.chatItems[chatId] ?? [])
        .map((item) => item.copyWith(isGlobal: false))
        .toList();

    final chatStatusMap = state.chatStatuses[chatId] ?? {};
    final globalItems = state.globalItems.map((item) {
      return item.copyWith(
        status: chatStatusMap[item.id] ?? item.status,
        isGlobal: true,
      );
    }).toList();

    final combinedItems = [...chatSpecificItems, ...globalItems];
    combinedItems.sort((a, b) {
      // 聊天专属条目 (isGlobal: false) 总是优先于全局条目 (isGlobal: true)
      if (a.isGlobal != b.isGlobal) {
        return a.isGlobal ? 1 : -1;
      }
      // 如果类型相同，则按其内部顺序排序
      return a.order.compareTo(b.order);
    });

    return combinedItems;
  }

  Future<void> addGlobalPromptItem() async {
    final newItem =
        PromptItem(id: _uuid.v4(), order: state.globalItems.length);
    state = state.copyWith(globalItems: [...state.globalItems, newItem]);
    await _saveGlobalItems();
  }

  Future<void> addChatPromptItem(int chatId) async {
    final currentChatItems = state.chatItems[chatId] ?? [];
    final newItem = PromptItem(id: _uuid.v4(), order: currentChatItems.length);
    final newChatItemsMap = Map<int, List<PromptItem>>.from(state.chatItems);
    newChatItemsMap[chatId] = [...currentChatItems, newItem];
    state = state.copyWith(chatItems: newChatItemsMap);
    await _saveChatItems();
  }

  Future<void> updatePromptItem(PromptItem item, int chatId) async {
    if (item.isGlobal) {
      state = state.copyWith(
        globalItems: [
          for (final i in state.globalItems)
            if (i.id == item.id)
              i.copyWith(
                keyword: item.keyword,
                text: item.text,
                injectionRole: item.injectionRole,
                injectionPosition: item.injectionPosition,
                matchMessageCount: item.matchMessageCount,
                injectionTag: item.injectionTag,
              )
            else
              i,
        ],
      );
      await _saveGlobalItems();
    } else {
      final chatItems = List<PromptItem>.from(state.chatItems[chatId] ?? []);
      final itemIndex = chatItems.indexWhere((i) => i.id == item.id);
      if (itemIndex != -1) {
        // Use copyWith for consistency and safety, ensuring all fields are updated.
        chatItems[itemIndex] = chatItems[itemIndex].copyWith(
          status: item.status,
          keyword: item.keyword,
          text: item.text,
          injectionRole: item.injectionRole,
          injectionPosition: item.injectionPosition,
          matchMessageCount: item.matchMessageCount,
          injectionTag: item.injectionTag,
        );
        final newChatItemsMap = Map<int, List<PromptItem>>.from(state.chatItems);
        newChatItemsMap[chatId] = chatItems;
        state = state.copyWith(chatItems: newChatItemsMap);
        await _saveChatItems();
      }
    }
  }

  Future<void> updateStatusForChat(
    int chatId,
    String itemId,
    PromptItemStatus newStatus,
  ) async {
    final isGlobalItem = state.globalItems.any((item) => item.id == itemId);

    if (isGlobalItem) {
      final newChatStatuses = Map<int, Map<String, PromptItemStatus>>.from(
        state.chatStatuses,
      );
      final statusMap = Map<String, PromptItemStatus>.from(
        newChatStatuses[chatId] ?? {},
      );
      statusMap[itemId] = newStatus;
      newChatStatuses[chatId] = statusMap;
      state = state.copyWith(chatStatuses: newChatStatuses);
      await _saveStatuses();
    } else {
      final chatItems = List<PromptItem>.from(state.chatItems[chatId] ?? []);
      final itemIndex = chatItems.indexWhere((item) => item.id == itemId);
      if (itemIndex != -1) {
        chatItems[itemIndex] = chatItems[itemIndex].copyWith(status: newStatus);
        final newChatItemsMap = Map<int, List<PromptItem>>.from(state.chatItems);
        newChatItemsMap[chatId] = chatItems;
        state = state.copyWith(chatItems: newChatItemsMap);
        await _saveChatItems();
      }
    }
  }

  Future<void> deletePromptItem(String id, bool isGlobal, int chatId) async {
    if (isGlobal) {
      state = state.copyWith(
        globalItems: state.globalItems.where((item) => item.id != id).toList(),
        chatStatuses: state.chatStatuses.map((chatId, statusMap) {
          statusMap.remove(id);
          return MapEntry(chatId, statusMap);
        }),
      );
      await _saveGlobalItems();
      await _saveStatuses();
    } else {
      final chatItems = List<PromptItem>.from(state.chatItems[chatId] ?? []);
      chatItems.removeWhere((item) => item.id == id);
      final newChatItemsMap = Map<int, List<PromptItem>>.from(state.chatItems);
      newChatItemsMap[chatId] = chatItems;
      state = state.copyWith(chatItems: newChatItemsMap);
      await _saveChatItems();
    }
  }

  Future<void> reorderChatPromptItem(
      int chatId, int oldIndex, int newIndex) async {
    final chatItems = List<PromptItem>.from(state.chatItems[chatId] ?? []);
    if (chatItems.isEmpty) return;

    if (oldIndex < newIndex) newIndex -= 1;
    final item = chatItems.removeAt(oldIndex);
    chatItems.insert(newIndex, item);

    final updatedItems = [
      for (int i = 0; i < chatItems.length; i++) chatItems[i].copyWith(order: i)
    ];

    final newChatItemsMap = Map<int, List<PromptItem>>.from(state.chatItems);
    newChatItemsMap[chatId] = updatedItems;
    state = state.copyWith(chatItems: newChatItemsMap);
    await _saveChatItems();
  }

  Future<void> reorderGlobalPromptItem(int oldIndex, int newIndex) async {
    final globalItems = List<PromptItem>.from(state.globalItems);
    if (globalItems.isEmpty) return;

    if (oldIndex < newIndex) newIndex -= 1;
    final item = globalItems.removeAt(oldIndex);
    globalItems.insert(newIndex, item);

    final updatedItems = [
      for (int i = 0; i < globalItems.length; i++)
        globalItems[i].copyWith(order: i)
    ];

    state = state.copyWith(globalItems: updatedItems);
    await _saveGlobalItems();
  }

  // --- Import/Export Logic ---

  String exportGlobalPrompts() {
    final items = state.globalItems;
    final jsonList = items.map((item) => item.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert(jsonList);
  }

  String exportGlobalPromptsWithStatuses() {
    final Map<String, dynamic> exportData = {
      'prompts': state.globalItems.map((p) => p.toJson()).toList(),
      'statuses': state.chatStatuses.map((chatId, statusMap) => MapEntry(
            chatId.toString(),
            statusMap.map((promptId, status) => MapEntry(promptId, status.index)),
          )),
    };
    return const JsonEncoder.withIndent('  ').convert(exportData);
  }

  String exportChatPrompts(int chatId) {
    final items = state.chatItems[chatId] ?? [];
    final jsonList = items.map((item) => item.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert(jsonList);
  }

  Future<bool> importGlobalPrompts(String jsonString) async {
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      final itemsToImport = jsonList
          .map((json) => PromptItem.fromJson(json as Map<String, dynamic>))
          .toList();

      final mergeResult =
          _mergePrompts(state.globalItems, itemsToImport);

      state = state.copyWith(globalItems: mergeResult.items);
      await _saveGlobalItems();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> importGlobalPromptsWithStatuses(String jsonString,
      {bool importStatuses = true}) async {
    try {
      final Map<String, dynamic> decodedJson = jsonDecode(jsonString);
      final List<dynamic> promptListJson = decodedJson['prompts'] ?? [];
      final Map<String, dynamic> statusesJson = decodedJson['statuses'] ?? {};

      final itemsToImport = promptListJson
          .map((p) => PromptItem.fromJson(p as Map<String, dynamic>))
          .toList();

      final mergeResult =
          _mergePrompts(state.globalItems, itemsToImport);
      final idMap = mergeResult.idMap;
      
      var updatedChatStatuses = state.chatStatuses;

      if (importStatuses) {
        updatedChatStatuses = Map.from(state.chatStatuses);
        statusesJson.forEach((chatIdStr, statusMapJson) {
          final chatId = int.parse(chatIdStr);
          final currentStatusMap =
              Map<String, PromptItemStatus>.from(updatedChatStatuses[chatId] ?? {});
          (statusMapJson as Map<String, dynamic>).forEach((oldPromptId, statusIndex) {
            final newPromptId = idMap[oldPromptId];
            if (newPromptId != null) {
              currentStatusMap[newPromptId] = PromptItemStatus.values[statusIndex];
            }
          });
          updatedChatStatuses[chatId] = currentStatusMap;
        });
      }

      state = state.copyWith(
        globalItems: mergeResult.items,
        chatStatuses: updatedChatStatuses,
      );

      await _saveGlobalItems();
      if (importStatuses) {
        await _saveStatuses();
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> importChatPrompts(String jsonString, int chatId) async {
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      final itemsToImport = jsonList
          .map((json) => PromptItem.fromJson(json as Map<String, dynamic>))
          .toList();
      
      final currentChatItems = state.chatItems[chatId] ?? [];
      final mergeResult = _mergePrompts(currentChatItems, itemsToImport);

      final newChatItemsMap = Map<int, List<PromptItem>>.from(state.chatItems);
      newChatItemsMap[chatId] = mergeResult.items;
      state = state.copyWith(chatItems: newChatItemsMap);
      await _saveChatItems();
      return true;
    } catch (e) {
      return false;
    }
  }

  _MergeResult _mergePrompts(
      List<PromptItem> existingItems, List<PromptItem> itemsToImport) {
    final updatedItems = List<PromptItem>.from(existingItems);
    final idMap = <String, String>{};

    for (final itemToImport in itemsToImport) {
      final existingItem = updatedItems
          .firstWhereOrNull((e) => e.text == itemToImport.text);

      if (existingItem != null) {
        // Case 1 & 2: Text matches, item exists.
        idMap[itemToImport.id] = existingItem.id;
        final itemIndex = updatedItems.indexOf(existingItem);
        
        final existingKeywords = existingItem.keyword.split(',').map((k) => k.trim()).where((k) => k.isNotEmpty).toSet();
        final importKeywords = itemToImport.keyword.split(',').map((k) => k.trim()).where((k) => k.isNotEmpty).toSet();

        if (const SetEquality().equals(existingKeywords, importKeywords)) {
          // Case 1: Keywords also match -> Overwrite config
          updatedItems[itemIndex] = existingItem.copyWith(
            status: itemToImport.status,
            injectionRole: itemToImport.injectionRole,
            injectionPosition: itemToImport.injectionPosition,
            matchMessageCount: itemToImport.matchMessageCount,
          );
        } else {
          // Case 2: Keywords differ -> Merge keywords
          existingKeywords.addAll(importKeywords);
          updatedItems[itemIndex] =
              existingItem.copyWith(keyword: existingKeywords.join(', '));
        }
      } else {
        // Case 3: New text -> Add as new item
        final newItem = itemToImport.copyWith(
          id: _uuid.v4(),
          order: updatedItems.length,
        );
        idMap[itemToImport.id] = newItem.id;
        updatedItems.add(newItem);
      }
    }
    return _MergeResult(items: updatedItems, idMap: idMap);
  }

  // --- Chat Duplication Logic ---
  Future<void> duplicateChatSettings(int fromChatId, int toChatId) async {
    // 1. Duplicate chat-specific items
    final originalChatItems = state.chatItems[fromChatId] ?? [];
    final newChatItems = originalChatItems.map((item) {
      // Assign a new unique ID to each copied item to avoid conflicts
      return item.copyWith(id: _uuid.v4());
    }).toList();

    final newChatItemsMap = Map<int, List<PromptItem>>.from(state.chatItems);
    if (newChatItems.isNotEmpty) {
      newChatItemsMap[toChatId] = newChatItems;
    }

    // 2. Duplicate global item statuses
    final originalStatuses = state.chatStatuses[fromChatId];
    final newChatStatusesMap =
        Map<int, Map<String, PromptItemStatus>>.from(state.chatStatuses);
    if (originalStatuses != null) {
      newChatStatusesMap[toChatId] =
          Map<String, PromptItemStatus>.from(originalStatuses);
    }

    // 3. Update state and persist
    state = state.copyWith(
      chatItems: newChatItemsMap,
      chatStatuses: newChatStatusesMap,
    );

    await _saveChatItems();
    await _saveStatuses();
  }
}

class _MergeResult {
  final List<PromptItem> items;
  final Map<String, String> idMap;
  _MergeResult({required this.items, required this.idMap});
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/prompt_item.dart';
import '../providers/core_providers.dart';

@immutable
class PromptState {
  final List<PromptItem> items;
  final Map<int, Map<String, PromptItemStatus>> chatStatuses;

  const PromptState({this.items = const [], this.chatStatuses = const {}});

  PromptState copyWith({
    List<PromptItem>? items,
    Map<int, Map<String, PromptItemStatus>>? chatStatuses,
  }) {
    return PromptState(
      items: items ?? this.items,
      chatStatuses: chatStatuses ?? this.chatStatuses,
    );
  }
}

final promptServiceProvider = StateNotifierProvider<PromptService, PromptState>(
  (ref) {
    final sharedPreferencesAsyncValue = ref.watch(sharedPreferencesProvider);
    return sharedPreferencesAsyncValue.when(
      data: (sharedPreferences) =>
          PromptService(sharedPreferences, const Uuid()),
      loading: () => PromptService(_DummySharedPreferences(), const Uuid()),
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
  static const _promptItemsKey = 'prompt_items_global';
  static const _promptStatusesKey = 'prompt_statuses_by_chat';

  PromptService(this._prefs, this._uuid) : super(const PromptState()) {
    _loadData();
  }

  Future<void> _loadData() async {
    // Load global items
    final itemsJson = _prefs.getStringList(_promptItemsKey) ?? [];
    final items = itemsJson
        .map((json) => PromptItem.fromJson(jsonDecode(json)))
        .toList();

    // Load chat-specific statuses
    final statusesJson = _prefs.getString(_promptStatusesKey) ?? '{}';
    final decodedStatuses = jsonDecode(statusesJson) as Map<String, dynamic>;
    final chatStatuses = decodedStatuses.map((chatIdStr, statusMap) {
      final chatId = int.parse(chatIdStr);
      final statuses = (statusMap as Map<String, dynamic>).map(
        (itemId, status) => MapEntry(itemId, PromptItemStatus.values[status]),
      );
      return MapEntry(chatId, statuses);
    });

    state = PromptState(items: items, chatStatuses: chatStatuses);
  }

  Future<void> _saveItems() async {
    final itemsJson = state.items
        .map((item) => jsonEncode(item.toJson()))
        .toList();
    await _prefs.setStringList(_promptItemsKey, itemsJson);
  }

  Future<void> _saveStatuses() async {
    final encodedStatuses = state.chatStatuses.map((chatId, statusMap) {
      final statuses = statusMap.map(
        (itemId, status) => MapEntry(itemId, status.index),
      );
      return MapEntry(chatId.toString(), statuses);
    });
    await _prefs.setString(_promptStatusesKey, jsonEncode(encodedStatuses));
  }

  List<PromptItem> getItemsForChat(int chatId) {
    final chatStatusMap = state.chatStatuses[chatId] ?? {};
    return state.items.map((item) {
      return item.copyWith(status: chatStatusMap[item.id] ?? item.status);
    }).toList();
  }

  Future<void> addPromptItem() async {
    final newItem = PromptItem(id: _uuid.v4());
    state = state.copyWith(items: [...state.items, newItem]);
    await _saveItems();
  }

  Future<void> updatePromptItem(PromptItem item) async {
    state = state.copyWith(
      items: [
        for (final i in state.items)
          if (i.id == item.id)
            // Save all global properties, not status
            i.copyWith(
              keyword: item.keyword,
              text: item.text,
              injectionRole: item.injectionRole,
              injectionPosition: item.injectionPosition,
              matchMessageCount: item.matchMessageCount,
            )
          else
            i,
      ],
    );
    await _saveItems();
  }

  Future<void> updateStatusForChat(
    int chatId,
    String itemId,
    PromptItemStatus newStatus,
  ) async {
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
  }

  Future<void> deletePromptItem(String id) async {
    state = state.copyWith(
      items: state.items.where((item) => item.id != id).toList(),
      chatStatuses: state.chatStatuses.map((chatId, statusMap) {
        statusMap.remove(id);
        return MapEntry(chatId, statusMap);
      }),
    );
    await _saveItems();
    await _saveStatuses();
  }
}

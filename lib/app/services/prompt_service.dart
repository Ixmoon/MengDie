import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../domain/enums.dart';

import '../../domain/models/prompt_item.dart';
import '../providers/auth_providers.dart';
import '../providers/core_providers.dart';

@immutable
class PromptState {
  final List<PromptItem> globalItems;
  final Map<int, List<PromptItem>> chatItems;
  final Map<int, Map<String, PromptItemStatus>> chatStatuses;
  final Map<int, bool> structuredOutputEnabledChats;

  const PromptState({
    this.globalItems = const [],
    this.chatItems = const {},
    this.chatStatuses = const {},
    this.structuredOutputEnabledChats = const {},
  });

  PromptState copyWith({
    List<PromptItem>? globalItems,
    Map<int, List<PromptItem>>? chatItems,
    Map<int, Map<String, PromptItemStatus>>? chatStatuses,
    Map<int, bool>? structuredOutputEnabledChats,
  }) {
    return PromptState(
      globalItems: globalItems ?? this.globalItems,
      chatItems: chatItems ?? this.chatItems,
      chatStatuses: chatStatuses ?? this.chatStatuses,
      structuredOutputEnabledChats:
          structuredOutputEnabledChats ?? this.structuredOutputEnabledChats,
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
  String get _structuredOutputEnabledChatsKey =>
      'structured_output_enabled_chats_userId_$_userId';

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

    // 4. Load structured output enabled statuses
    final structuredOutputJson =
        _prefs.getString(_structuredOutputEnabledChatsKey) ?? '{}';
    final decodedStructuredOutput =
        jsonDecode(structuredOutputJson) as Map<String, dynamic>;
    final structuredOutputEnabledChats =
        decodedStructuredOutput.map((chatIdStr, isEnabled) {
      return MapEntry(int.parse(chatIdStr), isEnabled as bool);
    });

    state = PromptState(
      globalItems: globalItems,
      chatItems: chatItems,
      chatStatuses: chatStatuses,
      structuredOutputEnabledChats: structuredOutputEnabledChats,
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

  Future<void> _saveStructuredOutputEnabledChats() async {
    final encoded = state.structuredOutputEnabledChats.map((chatId, isEnabled) {
      return MapEntry(chatId.toString(), isEnabled);
    });
    await _prefs.setString(_structuredOutputEnabledChatsKey, jsonEncode(encoded));
  }

  /// NEW: A private helper to recursively build a flattened list for the UI.
  List<PromptItem> _getFlattenedItems({
    required List<PromptItem> allItems,
    required bool isGlobal,
    Map<String, PromptItemStatus>? chatStatusMap,
    String? parentId,
    PromptItemStatus? parentStatus,
  }) {
    final List<PromptItem> result = [];
    final children = allItems
        .where((item) => item.parentId == parentId)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    for (final item in children) {
      var effectiveStatus = item.status;
      if (isGlobal) {
        effectiveStatus = chatStatusMap?[item.id] ?? item.status;
      }
      
      // Folder status overrides children's status if the folder is off.
      if (parentStatus == PromptItemStatus.off) {
        effectiveStatus = PromptItemStatus.off;
      }

      final updatedItem = item.copyWith(
        status: effectiveStatus,
        isGlobal: isGlobal,
      );
      result.add(updatedItem);

      if (item.type == PromptItemType.folder) {
        result.addAll(_getFlattenedItems(
          allItems: allItems,
          isGlobal: isGlobal,
          chatStatusMap: chatStatusMap,
          parentId: item.id,
          parentStatus: effectiveStatus, // Pass down the folder's effective status
        ));
      }
    }
    return result;
  }
  
  List<PromptItem> getItemsForChat(int chatId) {
    final chatSpecificItems = state.chatItems[chatId] ?? [];
    final chatStatusMap = state.chatStatuses[chatId] ?? {};
    final globalItems = state.globalItems;

    final flattenedChatItems = _getFlattenedItems(
      allItems: chatSpecificItems,
      isGlobal: false,
      parentId: null, // Start from the root
    );
    
    final flattenedGlobalItems = _getFlattenedItems(
      allItems: globalItems,
      isGlobal: true,
      chatStatusMap: chatStatusMap,
      parentId: null, // Start from the root
    );

    // The sorting is now handled by the recursive flattening function.
    // We just need to combine the two lists.
    return [...flattenedChatItems, ...flattenedGlobalItems];
  }

  Future<void> addGlobalPromptItem({String? parentId}) async {
    final siblings = state.globalItems.where((i) => i.parentId == parentId);
    final newItem = PromptItem(
      id: _uuid.v4(),
      order: siblings.length,
      parentId: parentId,
      isGlobal: true, // FIX: Explicitly set isGlobal flag
    );
    state = state.copyWith(globalItems: [...state.globalItems, newItem]);
    await _saveGlobalItems();
  }

  Future<void> addGlobalPromptFolder({String? parentId}) async {
    final siblings = state.globalItems.where((i) => i.parentId == parentId);
    final newItem = PromptItem(
      id: _uuid.v4(),
      order: siblings.length,
      parentId: parentId,
      type: PromptItemType.folder,
      keyword: 'New Folder', // Default name
      isGlobal: true, // FIX: Explicitly set isGlobal flag
    );
    state = state.copyWith(globalItems: [...state.globalItems, newItem]);
    await _saveGlobalItems();
  }

  Future<void> addChatPromptItem(int chatId, {String? parentId}) async {
    final currentChatItems = state.chatItems[chatId] ?? [];
    final siblings = currentChatItems.where((i) => i.parentId == parentId);
    final newItem = PromptItem(
      id: _uuid.v4(),
      order: siblings.length,
      parentId: parentId,
    );
    final newChatItemsMap = Map<int, List<PromptItem>>.from(state.chatItems);
    newChatItemsMap[chatId] = [...currentChatItems, newItem];
    state = state.copyWith(chatItems: newChatItemsMap);
    await _saveChatItems();
  }

  Future<void> addChatPromptFolder(int chatId, {String? parentId}) async {
    final currentChatItems = state.chatItems[chatId] ?? [];
    final siblings = currentChatItems.where((i) => i.parentId == parentId);
    final newItem = PromptItem(
      id: _uuid.v4(),
      order: siblings.length,
      parentId: parentId,
      type: PromptItemType.folder,
      keyword: 'New Folder', // Default name
    );
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
              // Ensure we don't overwrite parentId/type unintentionally
              i.copyWith(
                keyword: item.keyword,
                text: item.text,
                comment: item.comment,
                injectionRole: item.injectionRole,
                injectionPosition: item.injectionPosition,
                matchMessageCount: item.matchMessageCount,
                injectionTag: item.injectionTag,
                critical: item.critical,
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
          comment: item.comment,
          injectionRole: item.injectionRole,
          injectionPosition: item.injectionPosition,
          matchMessageCount: item.matchMessageCount,
          injectionTag: item.injectionTag,
          critical: item.critical,
        );
        final newChatItemsMap = Map<int, List<PromptItem>>.from(state.chatItems);
        newChatItemsMap[chatId] = chatItems;
        state = state.copyWith(chatItems: newChatItemsMap);
        await _saveChatItems();
      }
    }
  }

  Future<void> renameFolder({
    required int chatId,
    required bool isGlobal,
    required String folderId,
    required String newName,
  }) async {
    if (isGlobal) {
      final newGlobalItems = state.globalItems.map((item) {
        if (item.id == folderId && item.type == PromptItemType.folder) {
          return item.copyWith(keyword: newName);
        }
        return item;
      }).toList();
      state = state.copyWith(globalItems: newGlobalItems);
      await _saveGlobalItems();
    } else {
      final currentChatItems = state.chatItems[chatId] ?? [];
      final newChatItems = currentChatItems.map((item) {
        if (item.id == folderId && item.type == PromptItemType.folder) {
          return item.copyWith(keyword: newName);
        }
        return item;
      }).toList();
      
      final newChatItemsMap = Map<int, List<PromptItem>>.from(state.chatItems);
      newChatItemsMap[chatId] = newChatItems;
      state = state.copyWith(chatItems: newChatItemsMap);
      await _saveChatItems();
    }
  }

  Future<void> applyConfigsToFolderItems({
    required int chatId,
    required bool isGlobal,
    required String folderId,
    PromptItemStatus? status,
    PromptInjectionRole? injectionRole,
    int? injectionPosition,
    int? matchMessageCount,
    String? injectionTag,
    bool? critical,
    String? comment,
  }) async {
    final List<PromptItem> sourceList =
        isGlobal ? state.globalItems : (state.chatItems[chatId] ?? []);

    final updatedList = sourceList.map((item) {
      if (item.parentId == folderId && item.type == PromptItemType.item) {
        return item.copyWith(
          status: status,
          injectionRole: injectionRole,
          injectionPosition: injectionPosition,
          matchMessageCount: matchMessageCount,
          injectionTag: injectionTag,
          critical: critical,
          comment: comment,
        );
      }
      return item;
    }).toList();

    if (isGlobal) {
      state = state.copyWith(globalItems: updatedList);
      await _saveGlobalItems();
    } else {
      final newChatItemsMap = Map<int, List<PromptItem>>.from(state.chatItems);
      newChatItemsMap[chatId] = updatedList;
      state = state.copyWith(chatItems: newChatItemsMap);
      await _saveChatItems();
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

  Future<void> updateStructuredOutputStatus(
      int chatId, bool isEnabled) async {
    final newStatuses =
        Map<int, bool>.from(state.structuredOutputEnabledChats);
    newStatuses[chatId] = isEnabled;
    state = state.copyWith(structuredOutputEnabledChats: newStatuses);
    await _saveStructuredOutputEnabledChats();
  }

  Future<void> deletePromptItem(String id, bool isGlobal, int chatId) async {
    debugPrint(
        '[PromptService] Deleting item. ID: $id, isGlobal: $isGlobal, chatId: $chatId');

    // Helper to find all descendants of a folder
    List<String> findAllDescendantIds(String folderId, List<PromptItem> items) {
      final List<String> idsToDelete = [folderId];
      // Use a queue for iterative traversal to avoid deep recursion issues
      final queue = <String>[folderId];
      while (queue.isNotEmpty) {
        final currentFolderId = queue.removeAt(0);
        final children =
            items.where((item) => item.parentId == currentFolderId).toList();
        for (final child in children) {
          idsToDelete.add(child.id);
          if (child.type == PromptItemType.folder) {
            queue.add(child.id);
          }
        }
      }
      return idsToDelete;
    }

    if (isGlobal) {
      final itemToDelete = state.globalItems.firstWhereOrNull((i) => i.id == id);
      if (itemToDelete == null) return;
      
      final idsToDelete = itemToDelete.type == PromptItemType.folder
          ? findAllDescendantIds(id, state.globalItems)
          : [id];

      state = state.copyWith(
        globalItems: state.globalItems.where((item) => !idsToDelete.contains(item.id)).toList(),
        chatStatuses: state.chatStatuses.map((chatId, statusMap) {
          idsToDelete.forEach(statusMap.remove);
          return MapEntry(chatId, statusMap);
        }),
      );
      await _saveGlobalItems();
      await _saveStatuses();
    } else {
      final chatItems = List<PromptItem>.from(state.chatItems[chatId] ?? []);
      final itemToDelete = chatItems.firstWhereOrNull((i) => i.id == id);
      if (itemToDelete == null) return;

      final idsToDelete = itemToDelete.type == PromptItemType.folder
          ? findAllDescendantIds(id, chatItems)
          : [id];

      final updatedChatItems = chatItems.where((item) => !idsToDelete.contains(item.id)).toList();
      final newChatItemsMap = Map<int, List<PromptItem>>.from(state.chatItems);
      newChatItemsMap[chatId] = updatedChatItems;
      state = state.copyWith(chatItems: newChatItemsMap);
      await _saveChatItems();
    }
  }

  Future<void> movePromptItem({
    required int chatId,
    required bool isGlobal,
    required String itemId,
    required String? newParentId,
    required int newIndex,
  }) async {
    final List<PromptItem> sourceList = isGlobal
        ? List.from(state.globalItems)
        : List.from(state.chatItems[chatId] ?? []);

    final itemToMove = sourceList.firstWhereOrNull((i) => i.id == itemId);
    if (itemToMove == null) return;

    // Prevent dragging a folder into itself
    var currentParentId = newParentId;
    while(currentParentId != null) {
      if (currentParentId == itemId) {
        return; // Invalid move
      }
      currentParentId = sourceList.firstWhereOrNull((i) => i.id == currentParentId)?.parentId;
    }

    // --- Main Logic ---
    // 1. Remove the item from the list first.
    sourceList.removeWhere((i) => i.id == itemId);

    // 2. Reorder the original siblings if the parent has changed.
    if (itemToMove.parentId != newParentId) {
      final originalSiblings = sourceList
          .where((i) => i.parentId == itemToMove.parentId)
          .sortedBy<num>((i) => i.order)
          .toList();

      for (int i = 0; i < originalSiblings.length; i++) {
        final index = sourceList.indexWhere((item) => item.id == originalSiblings[i].id);
        if (index != -1) {
          sourceList[index] = sourceList[index].copyWith(order: i);
        }
      }
    }

    // 3. Get the new siblings and determine the correct insertion point.
    final newSiblings = sourceList
        .where((i) => i.parentId == newParentId)
        .sortedBy<num>((i) => i.order)
        .toList();

    // Clamp newIndex to be within bounds
    int targetIndex = newIndex.clamp(0, newSiblings.length);

    // 4. Insert the moved item with its new parent and temporary order.
    final updatedItem = itemToMove.copyWith(
      parentId: newParentId,
      order: -1, // Temporary order
      setParentIdToNull: newParentId == null,
    );
    newSiblings.insert(targetIndex, updatedItem);

    // 5. Reorder all items in the new sibling list.
    for (int i = 0; i < newSiblings.length; i++) {
      final item = newSiblings[i];
      // If it's the item we just moved, we add it back to the source list.
      if (item.id == itemId) {
         // This is the new, updated item. We add it back.
         sourceList.add(item.copyWith(order: i));
      } else {
        // Otherwise, we find the existing item and update its order.
        final index = sourceList.indexWhere((sourceItem) => sourceItem.id == item.id);
        if (index != -1) {
          sourceList[index] = sourceList[index].copyWith(order: i);
        }
      }
    }

    // --- Update state ---
    if (isGlobal) {
      state = state.copyWith(globalItems: sourceList);
      await _saveGlobalItems();
    } else {
      final newChatItemsMap = Map<int, List<PromptItem>>.from(state.chatItems);
      newChatItemsMap[chatId] = sourceList;
      state = state.copyWith(chatItems: newChatItemsMap);
      await _saveChatItems();
    }
  }

  Future<void> convertPromptType({
    required int chatId,
    required String itemId,
    required bool isSourceGlobal,
  }) async {
    final List<PromptItem> sourceList = isSourceGlobal
        ? List.from(state.globalItems)
        : List.from(state.chatItems[chatId] ?? []);
    
    final List<PromptItem> targetList = isSourceGlobal
        ? List.from(state.chatItems[chatId] ?? [])
        : List.from(state.globalItems);

    final itemToConvert = sourceList.firstWhereOrNull((i) => i.id == itemId);
    if (itemToConvert == null) return;

    // 1. Find all descendants if it's a folder
    final idsToConvert = <String>[];
    final itemsToConvert = <PromptItem>[];

    if (itemToConvert.type == PromptItemType.folder) {
      final descendants = _findAllDescendants(itemId, sourceList);
      itemsToConvert.addAll(descendants);
    } else {
      itemsToConvert.add(itemToConvert);
    }
    idsToConvert.addAll(itemsToConvert.map((e) => e.id));


    // 2. Remove items from the source list and re-order siblings
    final originalParentId = itemToConvert.parentId;
    sourceList.removeWhere((i) => idsToConvert.contains(i.id));
    
    final originalSiblings = sourceList
        .where((i) => i.parentId == originalParentId)
        .sortedBy<num>((i) => i.order)
        .toList();
    for (int i = 0; i < originalSiblings.length; i++) {
      final index = sourceList.indexWhere((item) => item.id == originalSiblings[i].id);
      if (index != -1) {
        sourceList[index] = sourceList[index].copyWith(order: i);
      }
    }

    // 3. Update items and add to the target list
    final newOrderStart = targetList.where((i) => i.parentId == null).length;
    final convertedItems = itemsToConvert.map((item) {
      // Reset parentId for the top-level item being moved
      final newParentId = (item.id == itemId) ? null : item.parentId;
      // Reset status to default when moving from chat-specific to global
      final newStatus = isSourceGlobal ? item.status : PromptItemStatus.on;
      final newIsGlobal = !isSourceGlobal; // FIX: Invert the isGlobal flag

      return item.copyWith(
        parentId: newParentId,
        status: newStatus,
        isGlobal: newIsGlobal, // FIX: Apply the correct isGlobal status
        order:
            newOrderStart + itemsToConvert.indexWhere((e) => e.id == item.id),
        setParentIdToNull: newParentId == null,
      );
    }).toList();

    targetList.addAll(convertedItems);

    // 4. Update state
    if (isSourceGlobal) {
      // Moved from Global to Chat
      final newChatItemsMap = Map<int, List<PromptItem>>.from(state.chatItems);
      newChatItemsMap[chatId] = targetList;
      state = state.copyWith(globalItems: sourceList, chatItems: newChatItemsMap);
    } else {
      // Moved from Chat to Global
      final newChatItemsMap = Map<int, List<PromptItem>>.from(state.chatItems);
      newChatItemsMap[chatId] = sourceList;
      state = state.copyWith(globalItems: targetList, chatItems: newChatItemsMap);
    }

    await _saveGlobalItems();
    await _saveChatItems();
  }

  // Helper to find all descendants including the parent
  List<PromptItem> _findAllDescendants(String folderId, List<PromptItem> items) {
    final List<PromptItem> result = [];
    final parent = items.firstWhereOrNull((item) => item.id == folderId);
    if (parent == null) return [];
    
    result.add(parent);
    final children = items.where((item) => item.parentId == folderId).toList();
    for (final child in children) {
      if (child.type == PromptItemType.folder) {
        result.addAll(_findAllDescendants(child.id, items));
      } else {
        result.add(child);
      }
    }
    return result;
  }


  // --- Import/Export Logic ---

  String exportPrompts({
    required bool isGlobal,
    required int chatId,
    String? parentId,
  }) {
    final sourceList =
        isGlobal ? state.globalItems : (state.chatItems[chatId] ?? []);

    if (parentId == null) {
      // Export all items
      final jsonList = sourceList.map((item) => item.toJson()).toList();
      return const JsonEncoder.withIndent('  ').convert(jsonList);
    } else {
      // Export specific folder and its descendants
      final itemsToExport = _findAllDescendants(parentId, sourceList);
      
      // We need to adjust the parentId of the top-level folder to be null
      // so it can be imported into other folders correctly.
      final processedItems = itemsToExport.map((item) {
        if (item.id == parentId) {
          // Use a temporary object for JSON conversion without modifying the state
          return item.copyWith(setParentIdToNull: true).toJson();
        }
        return item.toJson();
      }).toList();

      return const JsonEncoder.withIndent('  ').convert(processedItems);
    }
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

  Future<bool> importGlobalPrompts(String jsonString,
      {String? parentId, String? fileName}) async {
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      final itemsToImport = jsonList
          .map((json) => PromptItem.fromJson(json as Map<String, dynamic>))
          .toList();

      final newParentId = _createNewFolderForImport(
        fileName: fileName,
        targetParentId: parentId,
        isTargetGlobal: true,
      );

      final updatedItems = _mergePrompts(
        existingItems: state.globalItems,
        itemsToImport: itemsToImport,
        targetParentId: newParentId,
        isTargetGlobal: true,
      );

      state = state.copyWith(globalItems: updatedItems);
      await _saveGlobalItems();
      return true;
    } catch (e) {
      debugPrint('Error importing global prompts: $e');
      return false;
    }
  }

  Future<bool> importGlobalPromptsWithStatuses(String jsonString,
      {bool importStatuses = true, String? parentId, String? fileName}) async {
    try {
      final Map<String, dynamic> decodedJson = jsonDecode(jsonString);
      final List<dynamic> promptListJson = decodedJson['prompts'] ?? [];
      final Map<String, dynamic> statusesJson = decodedJson['statuses'] ?? {};

      final itemsToImport = promptListJson
          .map((p) => PromptItem.fromJson(p as Map<String, dynamic>))
          .toList();

      // Note: With hierarchical import, merging statuses becomes complex if only a sub-folder is imported.
      // For now, we only merge statuses when importing to the root.
      final shouldMergeStatuses = importStatuses && parentId == null;

      final idMap = <String, String>{};
      final newParentId = _createNewFolderForImport(
        fileName: fileName,
        targetParentId: parentId,
        isTargetGlobal: true,
      );
      final updatedItems = _mergePrompts(
        existingItems: state.globalItems,
        itemsToImport: itemsToImport,
        targetParentId: newParentId,
        isTargetGlobal: true,
        idMap: idMap,
      );

      var updatedChatStatuses = state.chatStatuses;

      if (shouldMergeStatuses) {
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
        globalItems: updatedItems,
        chatStatuses: updatedChatStatuses,
      );

      await _saveGlobalItems();
      if (shouldMergeStatuses) {
        await _saveStatuses();
      }
      return true;
    } catch (e) {
      debugPrint('Error importing global prompts with statuses: $e');
      return false;
    }
  }

  Future<bool> importChatPrompts(String jsonString, int chatId,
      {String? parentId, String? fileName}) async {
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      final itemsToImport = jsonList
          .map((json) => PromptItem.fromJson(json as Map<String, dynamic>))
          .toList();

      final newParentId = _createNewFolderForImport(
        fileName: fileName,
        targetParentId: parentId,
        isTargetGlobal: false,
        chatId: chatId,
      );

      final currentChatItems = state.chatItems[chatId] ?? [];
      final updatedItems = _mergePrompts(
        existingItems: currentChatItems,
        itemsToImport: itemsToImport,
        targetParentId: newParentId,
        isTargetGlobal: false,
      );

      final newChatItemsMap = Map<int, List<PromptItem>>.from(state.chatItems);
      newChatItemsMap[chatId] = updatedItems;
      state = state.copyWith(chatItems: newChatItemsMap);
      await _saveChatItems();
      return true;
    } catch (e) {
      debugPrint('Error importing chat prompts: $e');
      return false;
    }
  }

  Future<bool> importCompatiblePrompts(
    String jsonString, {
    required bool isGlobal,
    int? chatId,
    String? parentId,
    String? fileName,
  }) async {
    try {
      final Map<String, dynamic> decodedJson = jsonDecode(jsonString);
      Map<String, dynamic> entries;

      // Check for character_book format
      if (decodedJson['data'] is Map &&
          decodedJson['data']['character_book'] is Map &&
          decodedJson['data']['character_book']['entries'] is List) {
        final List<dynamic> bookEntries =
            decodedJson['data']['character_book']['entries'];
        entries = {
          for (var i = 0; i < bookEntries.length; i++)
            i.toString(): bookEntries[i]
        };
      } else if (decodedJson['entries'] is Map) {
        entries = decodedJson['entries'] as Map<String, dynamic>;
      } else {
        return false; // Not a compatible format
      }

      final List<PromptItem> itemsToImport = [];
      final Map<String, String> groupNameToTempFolderId = {};

      // 1. Parse all entries and sort them by the 'insertion_order' or 'order' field to preserve internal order.
      final sortedEntries = entries.values.toList()
        ..sort((a, b) {
          final orderA = (a['insertion_order'] as int?) ?? (a['order'] as int?) ?? 0;
          final orderB = (b['insertion_order'] as int?) ?? (b['order'] as int?) ?? 0;
          return orderA.compareTo(orderB);
        });

      // 2. Process sorted entries to create PromptItems
      for (final entry in sortedEntries) {
        final groupName = entry['group'] as String?;
        String? tempParentId;

        if (groupName != null && groupName.isNotEmpty) {
          if (!groupNameToTempFolderId.containsKey(groupName)) {
            final tempFolderId = 'folder_${groupName.hashCode}';
            groupNameToTempFolderId[groupName] = tempFolderId;
            final folderItem = PromptItem(
              id: tempFolderId,
              type: PromptItemType.folder,
              keyword: groupName,
              parentId: null,
              status: PromptItemStatus.on,
            );
            itemsToImport.add(folderItem);
          }
          tempParentId = groupNameToTempFolderId[groupName];
        }

        final keys = (entry['keys'] as List<dynamic>? ?? entry['key'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        final secondaryKeys = (entry['secondary_keys'] as List<dynamic>? ?? entry['keysecondary'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        final allKeys = [...keys, ...secondaryKeys];
        final hasKeywords = allKeys.any((k) => k.isNotEmpty);

        // 3. Apply new status and role conversion rules
        PromptItemStatus status;
        PromptInjectionRole role;

        if (hasKeywords) {
          status = PromptItemStatus.match;
          final roleInt = entry['role'] as int?;
          switch (roleInt) {
            case null:
            case 0: // system
              role = PromptInjectionRole.system;
              break;
            case 1: // user
              role = PromptInjectionRole.user;
              break;
            case 2: // assistant
              role = PromptInjectionRole.model;
              break;
            default:
              role = PromptInjectionRole.user;
          }
        } else {
          status = PromptItemStatus.on;
          role = PromptInjectionRole.system; // Default to system if no keywords
        }

        // Override status based on 'enabled' flag
        if (entry['enabled'] == false) {
          status = PromptItemStatus.off;
        }
        
        // 4. Check for and apply 'extensions' overrides
        var injectionPosition = entry['depth'] as int? ?? 2;
        var matchMessageCount = entry['scanDepth'] as int? ?? 6;
        var critical = entry['matchWholeWords'] as bool? ?? false;

        if (entry['extensions'] is Map<String, dynamic>) {
          final extensions = entry['extensions'] as Map<String, dynamic>;
          injectionPosition = extensions['depth'] as int? ?? injectionPosition;
          matchMessageCount = extensions['scan_depth'] as int? ?? matchMessageCount;
          critical = extensions['match_whole_words'] as bool? ?? critical;
          // You can add more overrides here as needed, for example:
          // role = extensions['role'] ...
        }

        final newItem = PromptItem(
          id: 'item_${entry['uid'] ?? entry['id']}',
          keyword: allKeys.join(', '),
          text: entry['content'] as String? ?? '',
          comment: entry['comment'] as String? ?? '',
          critical: critical,
          injectionRole: role,
          order: entry['insertion_order'] as int? ?? entry['order'] as int? ?? 0, // Keep original for reference, _mergePrompts will re-order
          injectionPosition: injectionPosition,
          matchMessageCount: matchMessageCount, // New mapping
          parentId: tempParentId,
          status: status,
        );
        itemsToImport.add(newItem);
      }

      // Now, use the existing _mergePrompts logic
      if (isGlobal) {
        final newParentId = _createNewFolderForImport(
            fileName: fileName, targetParentId: parentId, isTargetGlobal: true);
        final updatedItems = _mergePrompts(
          existingItems: state.globalItems,
          itemsToImport: itemsToImport,
          targetParentId: newParentId,
          isTargetGlobal: true,
        );
        state = state.copyWith(globalItems: updatedItems);
        await _saveGlobalItems();
      } else {
        if (chatId == null) return false;
        final newParentId = _createNewFolderForImport(
            fileName: fileName,
            targetParentId: parentId,
            isTargetGlobal: false,
            chatId: chatId);
        final currentChatItems = state.chatItems[chatId] ?? [];
        final updatedItems = _mergePrompts(
          existingItems: currentChatItems,
          itemsToImport: itemsToImport,
          targetParentId: newParentId,
          isTargetGlobal: false,
        );
        final newChatItemsMap =
            Map<int, List<PromptItem>>.from(state.chatItems);
        newChatItemsMap[chatId] = updatedItems;
        state = state.copyWith(chatItems: newChatItemsMap);
        await _saveChatItems();
      }

      return true;
    } catch (e) {
      debugPrint('Error importing compatible prompts: $e');
      return false;
    }
  }

  String? _createNewFolderForImport({
    required String? fileName,
    required String? targetParentId,
    required bool isTargetGlobal,
    int? chatId,
  }) {
    if (fileName == null || fileName.isEmpty) return targetParentId;

    final folderName = fileName.replaceAll(RegExp(r'\.json$'), '');
    final newFolderId = _uuid.v4();

    if (isTargetGlobal) {
      final siblings =
          state.globalItems.where((i) => i.parentId == targetParentId);
      final newFolder = PromptItem(
        id: newFolderId,
        type: PromptItemType.folder,
        keyword: folderName,
        parentId: targetParentId,
        order: siblings.length,
        isGlobal: true,
      );
      state = state.copyWith(globalItems: [...state.globalItems, newFolder]);
    } else {
      assert(chatId != null, 'chatId must be provided for chat import');
      final currentChatItems = state.chatItems[chatId] ?? [];
      final siblings =
          currentChatItems.where((i) => i.parentId == targetParentId);
      final newFolder = PromptItem(
        id: newFolderId,
        type: PromptItemType.folder,
        keyword: folderName,
        parentId: targetParentId,
        order: siblings.length,
        isGlobal: false,
      );
      final newChatItemsMap = Map<int, List<PromptItem>>.from(state.chatItems);
      newChatItemsMap[chatId!] = [...currentChatItems, newFolder];
      state = state.copyWith(chatItems: newChatItemsMap);
    }
    return newFolderId;
  }

  List<PromptItem> _mergePrompts({
    required List<PromptItem> existingItems,
    required List<PromptItem> itemsToImport,
    required String? targetParentId,
    required bool isTargetGlobal, // Know where we are importing to.
    Map<String, String>? idMap, // Optional: for status merging
  }) {
    debugPrint(
        '[PromptService] Merging prompts. TargetParentID: $targetParentId. Items to import: ${itemsToImport.length}');
    final updatedItems = List<PromptItem>.from(existingItems);
    final newIdMap = idMap ?? <String, String>{};

    // 1. Create a map of old parentId to list of children.
    final importParentMap = <String?, List<PromptItem>>{};
    for (final item in itemsToImport) {
      (importParentMap[item.parentId] ??= []).add(item);
    }

    // 2. Generate new IDs and create a map from old ID to new PromptItem.
    //    This is the ideal place to fix the isGlobal flag.
    final oldIdToNewItemMap = <String, PromptItem>{};
    for (final item in itemsToImport) {
      final newId = _uuid.v4();
      newIdMap[item.id] = newId;
      oldIdToNewItemMap[item.id] =
          item.copyWith(id: newId, isGlobal: isTargetGlobal);
    }

    // 3. Recursively build the new structure.
    final List<PromptItem> itemsToAdd = [];
    final int orderStart =
        updatedItems.where((i) => i.parentId == targetParentId).length;

    void buildHierarchy(String? oldParentId, String? newParentId, int depth) {
      final children = importParentMap[oldParentId] ?? [];
      int orderOffset = 0;
      for (final oldChild in children) {
        final newChild = oldIdToNewItemMap[oldChild.id];
        if (newChild == null) continue;

        // The order for root items starts from orderStart, for nested items it's relative to their siblings.
        final order = (depth == 0) ? orderStart + orderOffset : orderOffset;

        itemsToAdd.add(newChild.copyWith(
          parentId: newParentId,
          order: order,
          setParentIdToNull: newParentId == null,
        ));
        orderOffset++;

        // Recurse for grandchildren
        buildHierarchy(oldChild.id, newChild.id, depth + 1);
      }
    }

    // Start building from the root of the imported items (old parentId = null)
    buildHierarchy(null, targetParentId, 0);

    debugPrint('[PromptService] Finished merging. Total items to add: ${itemsToAdd.length}');

    updatedItems.addAll(itemsToAdd);
    return updatedItems;
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

    // 3. Duplicate structured output status
    final newStructuredOutputMap =
        Map<int, bool>.from(state.structuredOutputEnabledChats);
    final originalStructuredOutputStatus =
        state.structuredOutputEnabledChats[fromChatId];
    if (originalStructuredOutputStatus != null) {
      newStructuredOutputMap[toChatId] = originalStructuredOutputStatus;
    }

    // 4. Update state and persist
    state = state.copyWith(
      chatItems: newChatItemsMap,
      chatStatuses: newChatStatusesMap,
      structuredOutputEnabledChats: newStructuredOutputMap,
    );

    await _saveChatItems();
    await _saveStatuses();
    await _saveStructuredOutputEnabledChats();
  }

  // --- Data Cleanup ---
  Future<void> clearDataForChat(int chatId) async {
    debugPrint('[PromptService] Clearing all prompt data for chatId: $chatId');
    final newChatItems = Map<int, List<PromptItem>>.from(state.chatItems)..remove(chatId);
    final newChatStatuses = Map<int, Map<String, PromptItemStatus>>.from(state.chatStatuses)..remove(chatId);
    final newStructuredOutputMap = Map<int, bool>.from(state.structuredOutputEnabledChats)..remove(chatId);

    state = state.copyWith(
      chatItems: newChatItems,
      chatStatuses: newChatStatuses,
      structuredOutputEnabledChats: newStructuredOutputMap,
    );

    await _saveChatItems();
    await _saveStatuses();
    await _saveStructuredOutputEnabledChats();
  }
}

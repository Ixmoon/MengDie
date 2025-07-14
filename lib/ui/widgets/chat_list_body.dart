// --- 文件功能 ---
// 本文件定义了 ChatListScreen 的主体内容区域。
//
// --- 主要功能 ---
// 1. **状态渲染**: 根据传入的数据、加载和错误状态，渲染不同的UI（加载指示器、错误信息、空状态提示或聊天列表）。
// 2. **视图切换**: 根据 `isGridView` 状态，动态构建 `ListView` 或 `GridView`。
// 3. **逻辑内聚**: 封装了所有与列表/网格视图构建相关的逻辑，包括数据过滤、项构建和拖拽回调的连接。
// 4. **解耦**: 通过构造函数接收所有必要的状态和回调，与主屏幕的状态管理逻辑解耦。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

import '../../data/models/models.dart';
import '../providers/chat_state_providers.dart';
import 'chat_grid_item.dart';
import 'chat_list_item.dart';
import 'move_up_target.dart';

class ChatListBody extends StatelessWidget {
  final ChatListMode mode;
  final bool isGridView;
  final List<Chat>? localChats;
  final AsyncValue<List<Chat>> chatListAsync;
  final int? currentFolderId;
  final Set<int> selectedItemIds;
  final int? draggedItemId;
  final bool isMultiSelectMode;

  final Widget Function(Widget, int, Animation<double>) proxyDecorator;
  final Future<void> Function(int, int) onListViewReorder;
  final Future<void> Function(int, int) onGridViewReorder;
  final void Function(int) onReorderStart;
  final void Function(int) onReorderEnd;
  final void Function(Chat) onItemTap;
  final DragWidgetBuilderV2? dragWidgetBuilder;
  
  const ChatListBody({
    super.key,
    required this.mode,
    required this.isGridView,
    required this.localChats,
    required this.chatListAsync,
    required this.currentFolderId,
    required this.selectedItemIds,
    required this.draggedItemId,
    required this.isMultiSelectMode,
    required this.proxyDecorator,
    required this.onListViewReorder,
    required this.onGridViewReorder,
    required this.onReorderStart,
    required this.onReorderEnd,
    required this.onItemTap,
    this.dragWidgetBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (localChats != null) {
      if (localChats!.isEmpty && currentFolderId == null) {
        switch (mode) {
          case ChatListMode.normal:
            return const Center(child: Text('点击右下角 + 开始新聊天'));
          case ChatListMode.templateSelection:
            return const Center(child: Text('没有可用的模板'));
          case ChatListMode.templateManagement:
            return const Center(child: Text('没有可用的模板，点击右下角 + 新建'));
        }
      } else if (localChats!.isEmpty && currentFolderId != null) {
        return const Center(child: Text('此文件夹为空'));
      } else {
        return isGridView
            ? _buildGridView(localChats!)
            : _buildListView(localChats!);
      }
    } else if (chatListAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    } else if (chatListAsync.hasError) {
      return Center(child: Text('无法加载列表: ${chatListAsync.error}'));
    } else {
      return const Center(child: Text('没有内容'));
    }
  }

  Widget _buildListView(List<Chat> chats) {
    final inFolder = currentFolderId != null;
    final displayChats = chats;
    final itemCount = inFolder ? displayChats.length + 1 : displayChats.length;

    return ReorderableListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: itemCount,
      buildDefaultDragHandles: false,
      proxyDecorator: proxyDecorator,
      onReorder: onListViewReorder,
      onReorderEnd: onReorderEnd,
      onReorderStart: onReorderStart,
      itemBuilder: (context, index) {
        if (inFolder && index == 0) {
          return const MoveUpTarget(key: ValueKey('move-up-target-list'), isListView: true);
        }
        final chatIndex = inFolder ? index - 1 : index;
        final chat = displayChats[chatIndex];
        
        final bool shouldHide = isMultiSelectMode &&
                                draggedItemId != null &&
                                selectedItemIds.contains(chat.id);

        if (shouldHide) {
          return SizedBox.shrink(key: ValueKey(chat.id));
        }
        
        return ReorderableDelayedDragStartListener(
          key: ValueKey(chat.id),
          index: index,
          child: ChatListItem(
            chat: chat,
            isSelected: selectedItemIds.contains(chat.id),
            isMultiSelectMode: isMultiSelectMode,
            onTap: () => onItemTap(chat),
          ),
        );
      },
    );
  }

  Widget _buildGridView(List<Chat> chats) {
    final inFolder = currentFolderId != null;
    final List<Chat> displayChats;
    if (isMultiSelectMode && draggedItemId != null) {
      displayChats = chats.where((chat) => !selectedItemIds.contains(chat.id)).toList();
    } else {
      displayChats = chats;
    }
    final itemCount = inFolder ? displayChats.length + 1 : displayChats.length;

    return ReorderableGridView.builder(
      onReorder: onGridViewReorder,
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
        childAspectRatio: 1 / 1.5,
      ),
      itemCount: itemCount,
      dragWidgetBuilderV2: dragWidgetBuilder,
      itemBuilder: (context, index) {
        if (inFolder && index == 0) {
          return const MoveUpTarget(key: ValueKey('move-up-target-grid'), isListView: false);
        }
        final chatIndex = inFolder ? index - 1 : index;
        final chat = displayChats[chatIndex];

        return ReorderableDelayedDragStartListener(
          key: ValueKey(chat.id),
          index: index,
          enabled: !isMultiSelectMode || selectedItemIds.contains(chat.id),
          child: ChatGridItem(
            chat: chat,
            isSelected: selectedItemIds.contains(chat.id),
            onTap: () => onItemTap(chat),
          ),
        );
      },
    );
  }
}
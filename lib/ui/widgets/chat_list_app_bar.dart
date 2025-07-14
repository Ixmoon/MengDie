// --- 文件功能 ---
// 本文件定义了 ChatListScreen 的 AppBar 组件。
//
// --- 主要功能 ---
// 1. **双模式渲染**: 根据 `isMultiSelectMode` 状态，动态构建普通模式或多选模式的 AppBar。
// 2. **状态驱动**: 接收来自父级 Widget 的所有必要状态（如模式、文件夹信息、选择项）和回调函数，实现解耦。
// 3. **逻辑内聚**: 封装了所有与 AppBar 相关的 UI 元素和交互逻辑，包括标题、返回按钮、视图切换、多选操作等。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/models.dart';
import '../providers/chat_state_providers.dart';

class ChatListAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final ChatListMode mode;
  final bool isMultiSelectMode;
  final bool isGridView;
  final int? currentFolderId;
  final AsyncValue<Chat?> currentFolderAsync;
  final int selectedItemCount;
  final List<Chat> allItems;

  final VoidCallback onToggleMultiSelectMode;
  final VoidCallback onToggleViewMode;
  final VoidCallback onImport;
  final VoidCallback onSelectAll;
  final VoidCallback onDeselectAll;
  final VoidCallback onInvertSelection;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  const ChatListAppBar({
    super.key,
    required this.mode,
    required this.isMultiSelectMode,
    required this.isGridView,
    required this.currentFolderId,
    required this.currentFolderAsync,
    required this.selectedItemCount,
    required this.allItems,
    required this.onToggleMultiSelectMode,
    required this.onToggleViewMode,
    required this.onImport,
    required this.onSelectAll,
    required this.onDeselectAll,
    required this.onInvertSelection,
    required this.onExport,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return isMultiSelectMode
        ? _buildMultiSelectAppBar(context)
        : _buildNormalAppBar(context, ref);
  }

  AppBar _buildNormalAppBar(BuildContext context, WidgetRef ref) {
    String title;
    switch (mode) {
      case ChatListMode.normal:
        title = currentFolderId != null ? (currentFolderAsync.whenData((folder) => folder?.title).value ?? '文件夹') : '梦蝶';
        break;
      case ChatListMode.templateSelection:
        title = '从模板新建';
        break;
      case ChatListMode.templateManagement:
        title = '管理模板';
        break;
    }

    return AppBar(
      leading: mode != ChatListMode.normal || currentFolderId != null
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: '返回',
              onPressed: () {
                if (currentFolderId != null) {
                  final parentId = currentFolderAsync.whenData((folder) => folder?.parentFolderId).value;
                  ref.read(currentFolderIdProvider.notifier).state = parentId;
                } else if (mode != ChatListMode.normal) {
                  context.pop();
                }
              },
            )
          : null,
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text(
        title,
        style: TextStyle(
          shadows: <Shadow>[
            Shadow(color: Colors.black.withAlpha((255 * 0.5).round()), blurRadius: 1.0)
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.select_all),
          tooltip: '选择项目',
          onPressed: onToggleMultiSelectMode,
        ),
        IconButton(
          icon: Icon(isGridView ? Icons.view_list : Icons.grid_view),
          tooltip: isGridView ? '切换到列表视图' : '切换到网格视图',
          onPressed: onToggleViewMode,
        ),
        if (mode == ChatListMode.normal || mode == ChatListMode.templateManagement)
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: mode == ChatListMode.normal ? '导入聊天' : '导入模板',
            onPressed: onImport,
          ),
        if (mode == ChatListMode.normal)
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '全局设置',
            onPressed: () => context.push('/settings'),
          ),
      ],
    );
  }

  AppBar _buildMultiSelectAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: '取消选择',
        onPressed: onToggleMultiSelectMode,
      ),
      title: Text(
        '已选择 $selectedItemCount 项',
        style: TextStyle(
          shadows: <Shadow>[
            Shadow(color: Colors.black.withAlpha((255 * 0.5).round()), blurRadius: 1.0)
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.select_all),
          tooltip: '全选',
          onPressed: onSelectAll,
        ),
        IconButton(
          icon: const Icon(Icons.deselect),
          tooltip: '全不选',
          onPressed: onDeselectAll,
        ),
        IconButton(
          icon: const Icon(Icons.flip_to_back_outlined),
          tooltip: '反选',
          onPressed: onInvertSelection,
        ),
        IconButton(
          icon: const Icon(Icons.upload_file_outlined),
          tooltip: '导出所选',
          onPressed: selectedItemCount == 0 ? null : onExport,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: '删除所选',
          onPressed: selectedItemCount == 0 ? null : onDelete,
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
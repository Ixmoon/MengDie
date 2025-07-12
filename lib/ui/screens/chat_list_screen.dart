import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 导入触觉反馈服务
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // 用于导航
import 'package:intl/intl.dart'; // 用于日期格式化
import 'package:reorderable_grid_view/reorderable_grid_view.dart'; // 导入拖放网格视图包

// 导入模型、Provider 和 Widget
import '../../data/models/models.dart';
import '../providers/chat_state_providers.dart';
import '../providers/repository_providers.dart';
import '../../service/process/chat_export_import.dart'; // 导入导出/导入服务
import '../widgets/cached_image.dart'; // 导入缓存图片组件
import '../providers/core_providers.dart'; // 导入 SharedPreferences Provider
// import '../widgets/chat_list_item.dart'; // 不再直接使用 ChatListItem

// 本文件包含显示聊天列表的主屏幕。
//
// --- 主要功能 ---
// 1. **多模式支持**: 支持普通、模板选择、模板管理三种模式，适配不同业务场景。
// 2. **双视图显示**: 能以列表 (ListView) 或网格 (GridView) 形式显示聊天会话和文件夹。
// 3. **多选操作**: 提供完整的批量操作能力，包括选择、全选、反选、删除和导出。
// 4. **高级拖放排序**:
//    - **统一排序逻辑**: 实现了一个健壮的、统一的排序处理方法 `_handleReorder`，精确处理单选和多选在不同视图下的排序。
//    - **文件夹操作**: 支持将项目拖入文件夹、在文件夹内排序以及从文件夹中拖出至上一级。
//    - **多选拖动动画**: 在列表视图中，为多选拖动提供了平滑的堆叠卡片动画效果。
// 5. **状态管理**:
//    - **乐观更新**: 使用本地缓存 `_localChats` 进行UI的乐观更新，提升拖拽等操作的流畅度。
//    - **状态隔离**: 通过 `_isReordering` 标志位和 `ref.listen`，有效隔离本地UI状态和远程数据流，防止在用户交互时发生UI跳变。
// 6. **内容创建与导入**: 支持新建聊天、模板、文件夹，并能从外部文件导入数据到当前文件夹。
//
// --- 代码结构 ---
// - **`_ChatListScreenState`**: 管理所有UI状态和业务逻辑。
// - **`_build...` 方法**: 构建UI的各个部分，如 `_buildAppBar`, `_buildListView` 等。
// - **`_handle...` 方法**: 处理用户交互事件，如 `_handleReorder`, `_handleItemTap`。
// - **私有 Widget**: 封装了如 `_ChatListItem`, `_ChatGridItem` 等独立的UI组件。


// --- 聊天列表屏幕 ---
// 使用 ConsumerStatefulWidget 以便访问 Ref 并管理本地状态（如视图模式、多选）。
class ChatListScreen extends ConsumerStatefulWidget {
  final ChatListMode mode;
  final int? fromFolderId; // 新增：用于从模板创建时指定父文件夹

  const ChatListScreen({
    super.key,
    this.mode = ChatListMode.normal,
    this.fromFolderId, // 新增
  });

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  // 本地状态变量
  bool _isGridView = false; // 控制列表视图或网格视图
  bool _isMultiSelectMode = false; // 控制是否处于多选模式
  final Set<int> _selectedItemIds = {}; // 存储选中的项目 ID (改为 final)

  // --- 用于优化拖拽动画 ---
  // 本地列表缓存，用于实现乐观更新，避免拖拽后闪烁
  List<Chat>? _localChats;
  // 拖拽状态标志位，防止在拖拽过程中被外部数据流干扰
  bool _isReordering = false;
  // 当前被拖动的项目ID，用于在多选拖动时隐藏其他选中项
  int? _draggedItemId;

  // --- 切换多选模式 ---
  void _toggleMultiSelectMode({bool? enable, int? initialSelectionId}) {
    setState(() {
      if (enable != null) {
        _isMultiSelectMode = enable;
      } else {
        _isMultiSelectMode = !_isMultiSelectMode;
      }
      // 进入或退出多选模式时清空选择
      _selectedItemIds.clear();
      // 如果是进入模式且有初始选中项
      if (_isMultiSelectMode && initialSelectionId != null) {
        _selectedItemIds.add(initialSelectionId);
      }
    });
  }

  // --- 切换项目选中状态 ---
  void _toggleItemSelection(int id) {
    setState(() {
      if (_selectedItemIds.contains(id)) {
        _selectedItemIds.remove(id);
        // 如果取消最后一个选中项，则退出多选模式
        if (_selectedItemIds.isEmpty) {
          _isMultiSelectMode = false;
        }
      } else {
        _selectedItemIds.add(id);
      }
    });
  }

  // --- 多选删除确认对话框 ---
   Future<void> _showMultiDeleteConfirmationDialog() async {
     if (_selectedItemIds.isEmpty) return; // 没有选中项则不显示
 
     // 在调用异步方法前检查 mounted
     if (!context.mounted) return;
 
     final confirm = await showDialog<bool>(
       context: context,
       builder: (ctx) => AlertDialog(
        title: Text('确认删除 (${_selectedItemIds.length})'),
        content: const Text('确定删除选中的项目吗？此操作无法撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('删除', style: TextStyle(color: Colors.red.shade700)),
          ),
        ],
      ),
    );

        if (confirm == true) {
          // 异步操作前再次检查 mounted
          if (!mounted) return; // 增加额外的 mounted 检查
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          try {
            final repo = ref.read(chatRepositoryProvider);
            final deletedCount = await repo.deleteChats(_selectedItemIds.toList());
            // 异步操作后，再次检查 State 是否挂载
            if (mounted) { // 使用 State 的 mounted 属性
              scaffoldMessenger.showSnackBar( // 使用捕获的 scaffoldMessenger
                SnackBar(content: Text('已删除 $deletedCount 个项目'), duration: const Duration(seconds: 2)),
              );
              // 退出多选模式
              _toggleMultiSelectMode(enable: false);
            }
          } catch (e) {
            // 异步操作后，再次检查 State 是否挂载
            if (mounted) { // 使用 State 的 mounted 属性
              scaffoldMessenger.showSnackBar( // 使用捕获的 scaffoldMessenger
                SnackBar(content: Text('删除失败: $e'), backgroundColor: Colors.red),
              );
            }
          }
        }
  }
  
  // --- 新增：多选操作方法 ---
  void _selectAll(List<Chat> allItems) {
    setState(() {
      _selectedItemIds.addAll(allItems.map((item) => item.id));
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedItemIds.clear();
    });
  }

  void _invertSelection(List<Chat> allItems) {
    setState(() {
      final allIds = allItems.map((item) => item.id).toSet();
      final currentSelection = Set<int>.from(_selectedItemIds);
      _selectedItemIds.clear();
      _selectedItemIds.addAll(allIds.difference(currentSelection));
    });
  }

  Future<void> _exportSelected() async {
    if (_selectedItemIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有选择任何项目'), duration: Duration(seconds: 2)),
      );
      return;
    }

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      SnackBar(content: Text('正在打包 ${_selectedItemIds.length} 个项目...'), duration: const Duration(days: 1)),
    );

    try {
      final service = ref.read(chatExportImportServiceProvider);
      final savePath = await service.exportChatsToZip(_selectedItemIds.toList());
      
      if (mounted) {
        scaffoldMessenger.hideCurrentSnackBar();
        if (savePath != null) {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('已成功导出到: $savePath'), backgroundColor: Colors.green),
          );
        } else {
           scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('导出操作已取消'), duration: Duration(seconds: 2)),
          );
        }
        _toggleMultiSelectMode(enable: false);
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.hideCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('导出失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- 拖动预览装饰器 (用于多选拖动动画) ---
  Widget _buildDragProxy(Widget child, int index, Animation<double> animation) {
    final key = child.key;

    // 安全检查：仅当拖动的项目有整数类型的ValueKey，并且处于多选模式，并且该项目被选中时，才应用堆叠动画
    if (_isMultiSelectMode && key is ValueKey<int> && _selectedItemIds.contains(key.value)) {
      final selectedCount = _selectedItemIds.length;

      // 创建一个基础的卡片包裹被拖动的项，使其具有阴影和边界
      // 这是实现堆叠视觉效果的关键
      final Widget proxyItem = Card(
        elevation: 4.0,
        child: child,
      );

      // 使用 AnimatedBuilder 来根据拖动动画的进程构建UI
      return AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final factor = animation.value; // 动画值 (0.0 to 1.0)
          return Stack(
            alignment: Alignment.center,
            children: [
              // 背景卡片 2 (如果选中项超过2个)
              if (selectedCount > 2)
                Transform.translate(
                  offset: Offset(8.0 * factor, -8.0 * factor), // 使用更明显的偏移
                  child: Opacity(opacity: 0.6, child: proxyItem),
                ),
              // 背景卡片 1 (如果选中项超过1个)
              if (selectedCount > 1)
                Transform.translate(
                  offset: Offset(4.0 * factor, -4.0 * factor), // 使用更明显的偏移
                  child: Opacity(opacity: 0.8, child: proxyItem),
                ),
              // 最顶层的、被拖动的原始项目
              proxyItem,
            ],
          );
        },
      );
    }
    
    // 对于其他情况（如单选模式、拖动未选中项、或拖动的是没有ValueKey<int>的控件如“上移”按钮），返回默认代理
    // 使用 Material 和 elevation 可以确保拖动项浮动在其他列表项之上
    return Material(
      elevation: 4.0,
      color: Colors.transparent, // 设置背景透明，避免遮挡
      child: child,
    );
  }

  // --- 拖放处理逻辑 (V4 - 视图分离) ---

  /// ListView 的拖放处理逻辑
  Future<void> _handleListViewReorder(int oldIndex, int newIndex) async {
    if (_localChats == null) return;
    setState(() => _isReordering = true);
    HapticFeedback.mediumImpact();

    try {
      final inFolder = ref.read(currentFolderIdProvider) != null;
      final dataOldIndex = inFolder ? oldIndex - 1 : oldIndex;

      // 安全检查
      if (dataOldIndex < 0 || dataOldIndex >= _localChats!.length) return;
      
      final draggedItemId = _localChats![dataOldIndex].id;
      final isMultiDrag = _isMultiSelectMode && _selectedItemIds.contains(draggedItemId);

      final List<Chat> itemsToMove = isMultiDrag
          ? _localChats!.where((c) => _selectedItemIds.contains(c.id)).toList()
          : [_localChats![dataOldIndex]];

      // --- 特殊目标处理 ---
      if (inFolder && newIndex == 0) {
        await _handleMoveToParent(itemsToMove);
        return;
      }
      
      final potentialTargetIndex = (newIndex > oldIndex) ? newIndex - 1 : newIndex;
      final dataTargetIndex = inFolder ? potentialTargetIndex - 1 : potentialTargetIndex;
      if (dataTargetIndex >= 0 && dataTargetIndex < _localChats!.length) {
        final targetItem = _localChats![dataTargetIndex];
        final validItemsToMove = itemsToMove.where((item) => item.id != targetItem.id && item.parentFolderId != targetItem.id).toList();
        if (targetItem.isFolder && validItemsToMove.isNotEmpty) {
          await _handleMoveIntoFolder(validItemsToMove, targetItem);
          return;
        }
      }

      // --- 常规排序逻辑 ---
      final reorderedChats = List<Chat>.from(_localChats!);
      if (isMultiDrag) {
        // 多选排序
        reorderedChats.removeWhere((c) => itemsToMove.map((i) => i.id).contains(c.id));
        
        final int stableItemsBeforeNewIndex = _localChats!
            .take(newIndex)
            .where((c) => !_selectedItemIds.contains(c.id))
            .length;
        
        final insertionIndex = inFolder ? stableItemsBeforeNewIndex - 1 : stableItemsBeforeNewIndex;
        reorderedChats.insertAll(insertionIndex.clamp(0, reorderedChats.length), itemsToMove);
      } else {
        // 单选排序
        final movedItem = reorderedChats.removeAt(dataOldIndex);
        final insertionIndex = (newIndex > oldIndex) ? newIndex - 1 : newIndex;
        final dataNewIndex = inFolder ? insertionIndex - 1 : insertionIndex;
        reorderedChats.insert(dataNewIndex.clamp(0, reorderedChats.length), movedItem);
      }

      // 应用乐观更新并更新数据库
      _localChats = reorderedChats;
      setState(() {});

      final List<Chat> chatsToUpdate = [];
      for (int i = 0; i < reorderedChats.length; i++) {
        if (reorderedChats[i].orderIndex != i) {
          chatsToUpdate.add(reorderedChats[i].copyWith({'orderIndex': i}));
        }
      }

      if (chatsToUpdate.isNotEmpty) {
        await ref.read(chatRepositoryProvider).updateChatOrder(chatsToUpdate);
      }

    } catch (e) {
      ref.invalidate(chatListProvider((parentFolderId: ref.read(currentFolderIdProvider), mode: widget.mode)));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失败: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        HapticFeedback.mediumImpact();
        setState(() {
          _isReordering = false;
          _draggedItemId = null;
        });
      }
    }
  }

  /// 处理“移至上一级”的逻辑
  Future<void> _handleMoveToParent(List<Chat> itemsToMove) async {
    final currentFolderId = ref.read(currentFolderIdProvider);
    // 安全修复：在调用前确保 currentFolderId 不为 null
    if (currentFolderId == null) return;
    final parentFolder = ref.read(currentChatProvider(currentFolderId)).value;
    if (parentFolder == null) return;

    // 乐观更新
    _localChats!.removeWhere((c) => itemsToMove.map((i) => i.id).contains(c.id));
    setState(() {});

    await ref.read(chatRepositoryProvider).moveChatsToNewParent(
      chatIds: itemsToMove.map((c) => c.id).toList(),
      newParentFolderId: parentFolder.parentFolderId,
    );

    if (mounted) {
      _selectedItemIds.clear();
      _isMultiSelectMode = false;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("${itemsToMove.length} 个项目已移至上一级"),
        backgroundColor: Colors.green,
      ));
    }
  }

  /// 处理“拖入文件夹”的逻辑
  Future<void> _handleMoveIntoFolder(List<Chat> itemsToMove, Chat targetFolder) async {
    // 乐观更新
    _localChats!.removeWhere((c) => itemsToMove.map((i) => i.id).contains(c.id));
    setState(() {});
    
    await ref.read(chatRepositoryProvider).moveChatsToNewParent(
      chatIds: itemsToMove.map((c) => c.id).toList(),
      newParentFolderId: targetFolder.id,
    );

    if (mounted) {
      _selectedItemIds.clear();
      _isMultiSelectMode = false;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("${itemsToMove.length} 个项目已移至 '${targetFolder.title}'"),
        backgroundColor: Colors.green,
      ));
    }
  }



  // --- 构建列表视图 ---
  Widget _buildListView(List<Chat> chats, WidgetRef ref) {
    final inFolder = ref.watch(currentFolderIdProvider) != null;

    // 关键修复：保持数据源的稳定性。不过滤列表，以防止 ReorderableListView 状态崩溃。
    // 视觉上的“隐藏”将在 itemBuilder 中通过返回占位符来实现。
    final displayChats = chats;
    final itemCount = inFolder ? displayChats.length + 1 : displayChats.length;

    return ReorderableListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: itemCount,
      buildDefaultDragHandles: false,
      proxyDecorator: _buildDragProxy, // 应用自定义拖动预览
      onReorder: _handleListViewReorder,
      onReorderEnd: (index) {
        // 关键修复：当拖动在 ListView 中结束时（无论是完成排序还是被取消），
        // 都必须清理拖动状态。缺少这个回调是导致“点击消失”问题的根本原因。
        if (_draggedItemId != null) {
          setState(() {
            _draggedItemId = null;
          });
        }
      },
      onReorderStart: (index) {
        final chatIndex = inFolder ? index - 1 : index;
        if (chatIndex >= 0 && chatIndex < displayChats.length) {
          final draggedChat = displayChats[chatIndex];
          // 关键交互修复：仅当在多选模式下，且用户拖动的是一个**已选中**的项目时，
          // 才触发“多选拖动”状态（即设置 _draggedItemId，从而隐藏其他选中项）。
          if (_isMultiSelectMode && _selectedItemIds.contains(draggedChat.id)) {
            setState(() {
              _draggedItemId = draggedChat.id;
            });
          }
          // 如果用户在多选模式下拖动一个“未选中”的项，则不设置 _draggedItemId，
          // 这将使本次拖动表现为普通的单项拖动，符合用户预期。
        }
      },
      itemBuilder: (context, index) {
        if (inFolder && index == 0) {
          return const _MoveUpTarget(key: ValueKey('move-up-target-list'), isListView: true);
        }
        final chatIndex = inFolder ? index - 1 : index;
        final chat = displayChats[chatIndex];
        
        // 关键修复：在多选拖动时，隐藏所有被选中的项目（包括被拖动的那个），
        // 因为它们的视觉呈现已完全由拖动代理 `proxyDecorator` 接管。
        // 这可以防止被拖动项在原位置出现视觉残留，并确保列表索引稳定。
        final bool shouldHide = _isMultiSelectMode &&
                                _draggedItemId != null &&
                                _selectedItemIds.contains(chat.id);

        if (shouldHide) {
          // 最终视觉优化：返回一个零尺寸的占位符，使空间能够折叠。
          // 同时保留 key，以确保 Flutter 能够正确跟踪小部件，保证动画平滑。
          return SizedBox.shrink(key: ValueKey(chat.id));
        }
        
        return ReorderableDelayedDragStartListener(
          key: ValueKey(chat.id),
          index: index,
          child: _ChatListItem(
            chat: chat,
            isSelected: _selectedItemIds.contains(chat.id),
            isMultiSelectMode: _isMultiSelectMode,
            onTap: () => _handleItemTap(chat),
          ),
        );
      },
    );
  }


  // --- 构建网格视图 ---
  Widget _buildGridView(List<Chat> chats, WidgetRef ref) {
    final inFolder = ref.watch(currentFolderIdProvider) != null;

    // 最终修复：对于 GridView，必须在拖动时过滤数据源，以解决占位问题。
    final List<Chat> displayChats;
    if (_isMultiSelectMode && _draggedItemId != null) {
      displayChats = chats.where((chat) => !_selectedItemIds.contains(chat.id)).toList();
    } else {
      displayChats = chats;
    }
    final itemCount = inFolder ? displayChats.length + 1 : displayChats.length;

    return ReorderableGridView.builder(
      onReorder: _handleGridViewReorder,
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
        childAspectRatio: 1 / 1.5,
      ),
      itemCount: itemCount,
      dragWidgetBuilderV2: DragWidgetBuilderV2(
        isScreenshotDragWidget: false,
        builder: (index, child, screenshot) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final chatIndex = inFolder ? index - 1 : index;
            // 安全检查：确保索引在 displayChats 范围内
            if (chatIndex >= 0 && chatIndex < displayChats.length) {
               final draggedChat = displayChats[chatIndex];
               // 触发多选拖动状态
               if (_isMultiSelectMode && _selectedItemIds.contains(draggedChat.id)) {
                 if (_draggedItemId != draggedChat.id) {
                   setState(() {
                     _draggedItemId = draggedChat.id;
                   });
                 }
               }
            }
          });
          return child;
        },
      ),
      itemBuilder: (context, index) {
        if (inFolder && index == 0) {
          return const _MoveUpTarget(key: ValueKey('move-up-target-grid'), isListView: false);
        }
        final chatIndex = inFolder ? index - 1 : index;
        final chat = displayChats[chatIndex];

        // GridView 不需要 shouldHide 逻辑，因为数据源已经被过滤
        return ReorderableDelayedDragStartListener(
          key: ValueKey(chat.id),
          index: index,
          enabled: !_isMultiSelectMode || _selectedItemIds.contains(chat.id),
          child: _ChatGridItem(
            chat: chat,
            isSelected: _selectedItemIds.contains(chat.id),
            onTap: () => _handleItemTap(chat),
          ),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final currentFolderId = ref.watch(currentFolderIdProvider);
    final chatListProviderInstance = chatListProvider((parentFolderId: currentFolderId, mode: widget.mode));
    final chatListAsync = ref.watch(chatListProviderInstance);
    final currentFolderAsync = ref.watch(currentChatProvider(currentFolderId ?? -1));

    // 最终修复方案：使用 ref.listen 隔离状态，并显式处理导航
    // 1. 监听文件夹ID的变化。当用户导航到新文件夹时，主动重置本地状态。
    ref.listen<int?>(currentFolderIdProvider, (previous, next) {
      if (previous != next) {
        setState(() {
          _localChats = null; // 清空本地缓存，强制显示加载指示器
        });
      }
    });

    // 2. 监听列表数据的变化。
    ref.listen(chatListProviderInstance, (previous, next) {
      // 仅当有新数据，并且当前不处于拖动排序状态时，才更新本地状态。
      if (next.hasValue && !_isReordering) {
        setState(() {
          _localChats = next.value;
        });
      }
    });

    return Scaffold(
      appBar: _buildAppBar(context, ref, currentFolderId, currentFolderAsync),
      body: chatListAsync.when(
        data: (chatsFromProvider) {
          // 2. 关键：_localChats 只在首次加载时被初始化。
          //    之后，它的更新完全由 `_handleReorder` (乐观更新) 和 `ref.listen` (外部数据同步) 控制。
          //    这使得 _localChats 成为 UI 的稳定数据源。
          _localChats ??= List.from(chatsFromProvider);
          final chatsForDisplay = _localChats!;

          if (chatsForDisplay.isEmpty && currentFolderId == null) {
            switch (widget.mode) {
              case ChatListMode.normal:
                return const Center(child: Text('点击右下角 + 开始新聊天'));
              case ChatListMode.templateSelection:
                return const Center(child: Text('没有可用的模板'));
              case ChatListMode.templateManagement:
                return const Center(child: Text('没有可用的模板，点击右下角 + 新建'));
            }
          } else if (chatsForDisplay.isEmpty && currentFolderId != null) {
            return const Center(child: Text('此文件夹为空'));
          }

          return _isGridView
              ? _buildGridView(chatsForDisplay, ref)
              : _buildListView(chatsForDisplay, ref);
        },
        loading: () {
          // 3. 优化体验：在重新加载时，如果已有旧数据，则继续显示，避免白屏。
          if (_localChats != null) {
            return _isGridView
                ? _buildGridView(_localChats!, ref)
                : _buildListView(_localChats!, ref);
          }
          return const Center(child: CircularProgressIndicator());
        },
        error: (error, stack) => Center(child: Text('无法加载列表: $error')),
      ),
      floatingActionButton: widget.mode == ChatListMode.templateSelection
        ? null
        : FloatingActionButton(
            onPressed: () => _showCreateMenu(context, ref, currentFolderId),
            tooltip: '新建',
            child: const Icon(Icons.add),
          ),
    );
  }

  // --- 构建 AppBar (重构后) ---
  /// GridView 的拖放处理逻辑 (V2 - 最终修复)
  Future<void> _handleGridViewReorder(int oldIndex, int newIndex) async {
    if (_localChats == null) return;
    setState(() => _isReordering = true);
    HapticFeedback.mediumImpact();

    try {
      final inFolder = ref.read(currentFolderIdProvider) != null;
      final isMultiDrag = _isMultiSelectMode && _draggedItemId != null;

      // 1. 识别需要移动的项
      //    - 多选：所有选中的项
      //    - 单选：通过 oldIndex 从 *完整列表* 中安全地找到被拖动的项
      final List<Chat> itemsToMove;
      if (isMultiDrag) {
        itemsToMove = _localChats!.where((c) => _selectedItemIds.contains(c.id)).toList();
      } else {
        final dataOldIndex = inFolder ? oldIndex - 1 : oldIndex;
        if (dataOldIndex < 0 || dataOldIndex >= _localChats!.length) return;
        itemsToMove = [_localChats![dataOldIndex]];
      }

      // 2. 处理特殊目标（移至上一级 或 拖入文件夹）
      //    - 目标项的识别基于 *稳定项列表*
      final stableChats = _localChats!.where((c) => !itemsToMove.map((i) => i.id).contains(c.id)).toList();
      
      // 2a. 移至上一级
      if (inFolder && newIndex == 0) {
        await _handleMoveToParent(itemsToMove);
        return;
      }

      // 2b. 拖入文件夹
      final potentialTargetIndex = (newIndex > oldIndex) ? newIndex - 1 : newIndex;
      final stableTargetIndex = inFolder ? potentialTargetIndex - 1 : potentialTargetIndex;
      
      if (stableTargetIndex >= 0 && stableTargetIndex < stableChats.length) {
        final Chat targetItem = stableChats[stableTargetIndex];
        final validItemsToMove = itemsToMove.where((item) => item.id != targetItem.id && item.parentFolderId != targetItem.id).toList();

        if (targetItem.isFolder && validItemsToMove.isNotEmpty) {
          await _handleMoveIntoFolder(validItemsToMove, targetItem);
          return;
        }
      }
      
      // 3. 处理常规排序
      final reorderedChats = List<Chat>.from(_localChats!);
      reorderedChats.removeWhere((c) => itemsToMove.map((i) => i.id).contains(c.id));

      // 找到目标位置项在 reorderedChats 中的正确索引
      int insertionIndex;
      if (stableTargetIndex >= 0 && stableTargetIndex < stableChats.length) {
        final targetItem = stableChats[stableTargetIndex];
        insertionIndex = reorderedChats.indexWhere((c) => c.id == targetItem.id);
        
        // 当向下拖动且目标在拖动项原位置之后时，插入点需要+1
        final originalDraggedItemIndex = _localChats!.indexWhere((c) => c.id == itemsToMove.first.id);
        final originalTargetItemIndex = _localChats!.indexWhere((c) => c.id == targetItem.id);
        if (originalTargetItemIndex > originalDraggedItemIndex) {
           insertionIndex++;
        }
      } else {
        // 拖到末尾
        insertionIndex = reorderedChats.length;
      }

      reorderedChats.insertAll(insertionIndex.clamp(0, reorderedChats.length), itemsToMove);
      
      // 4. 应用乐观更新并更新数据库
      _localChats = reorderedChats;
      setState(() {});

      final List<Chat> chatsToUpdate = [];
      for (int i = 0; i < reorderedChats.length; i++) {
        if (reorderedChats[i].orderIndex != i) {
          chatsToUpdate.add(reorderedChats[i].copyWith({'orderIndex': i}));
        }
      }

      if (chatsToUpdate.isNotEmpty) {
        await ref.read(chatRepositoryProvider).updateChatOrder(chatsToUpdate);
      }

    } catch (e) {
      ref.invalidate(chatListProvider((parentFolderId: ref.read(currentFolderIdProvider), mode: widget.mode)));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失败: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        HapticFeedback.mediumImpact();
        setState(() {
          _isReordering = false;
          _draggedItemId = null;
        });
      }
    }
  }

  // --- 项目点击处理逻辑 (重构后提取) ---
  void _handleItemTap(Chat chat) async {
    if (_isMultiSelectMode) {
      _toggleItemSelection(chat.id);
    } else {
      // --- 根据模式执行不同操作 ---
      switch (widget.mode) {
        case ChatListMode.normal:
          if (chat.isFolder) {
            ref.read(currentFolderIdProvider.notifier).state = chat.id;
          } else {
            final prefs = await ref.read(sharedPreferencesProvider.future);
            await prefs.setInt('last_open_chat_id', chat.id);
            ref.read(activeChatIdProvider.notifier).state = chat.id;
            if (!context.mounted) return;
            context.go('/chat');
          }
          break;
        case ChatListMode.templateSelection:
          // 从模板创建新聊天
          final repo = ref.read(chatRepositoryProvider);
          // 关键修复：将 fromFolderId 传递给创建方法
          final newChatId = await repo.createChatFromTemplate(chat.id, parentFolderId: widget.fromFolderId);
          if (context.mounted) {
            ref.read(activeChatIdProvider.notifier).state = newChatId;
            // 关键修复：创建后重置 currentFolderIdProvider，确保返回时回到正确的聊天列表层级
            ref.read(currentFolderIdProvider.notifier).state = widget.fromFolderId;
            context.go('/chat'); // 直接进入新创建的聊天
          }
          break;
        case ChatListMode.templateManagement:
          // 修正：区分文件夹和模板的点击行为
          if (chat.isFolder) {
            // 如果是文件夹，则进入文件夹
            ref.read(currentFolderIdProvider.notifier).state = chat.id;
          } else {
            // 如果是模板，则进入聊天设置页面以编辑
            ref.read(activeChatIdProvider.notifier).state = chat.id;
            context.push('/chat/settings');
          }
          break;
      }
    }
  }

  AppBar _buildAppBar(BuildContext context, WidgetRef ref, int? currentFolderId, AsyncValue<Chat?> currentFolderAsync) {
    // 根据是否处于多选模式，调用不同的构建方法，使逻辑更清晰
    if (_isMultiSelectMode) {
      return _buildMultiSelectAppBar(ref, currentFolderId);
    } else {
      return _buildNormalAppBar(ref, currentFolderId, currentFolderAsync);
    }
  }

  /// 构建普通模式下的 AppBar
  AppBar _buildNormalAppBar(WidgetRef ref, int? currentFolderId, AsyncValue<Chat?> currentFolderAsync) {
    String title;
    switch (widget.mode) {
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
      leading: widget.mode != ChatListMode.normal || currentFolderId != null
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: '返回',
              onPressed: () {
                if (currentFolderId != null) {
                  final parentId = currentFolderAsync.whenData((folder) => folder?.parentFolderId).value;
                  ref.read(currentFolderIdProvider.notifier).state = parentId;
                } else if (widget.mode != ChatListMode.normal) {
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
          onPressed: () => _toggleMultiSelectMode(enable: true),
        ),
        IconButton(
          icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
          tooltip: _isGridView ? '切换到列表视图' : '切换到网格视图',
          onPressed: () {
            setState(() {
              _isGridView = !_isGridView;
            });
          },
        ),
        if (widget.mode == ChatListMode.normal || widget.mode == ChatListMode.templateManagement)
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: widget.mode == ChatListMode.normal ? '导入聊天' : '导入模板',
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final importType = widget.mode == ChatListMode.normal ? '聊天' : '模板';
              scaffoldMessenger.showSnackBar(
                SnackBar(content: Text('正在导入$importType...'), duration: const Duration(seconds: 10)),
              );
              try {
                final count = await ref.read(chatExportImportServiceProvider).importChats(parentFolderId: currentFolderId);
                if (!context.mounted) return;
                scaffoldMessenger.hideCurrentSnackBar();
                if (count > 0) {
                  scaffoldMessenger.showSnackBar(SnackBar(content: Text('成功导入 $count 个$importType！')));
                } else {
                  scaffoldMessenger.showSnackBar(const SnackBar(content: Text('导入已取消或没有导入任何项目'), duration: Duration(seconds: 2)));
                }
              } catch (e) {
                if (!context.mounted) return;
                scaffoldMessenger.hideCurrentSnackBar();
                scaffoldMessenger.showSnackBar(SnackBar(content: Text('导入$importType失败: $e'), backgroundColor: Colors.red));
              }
            },
          ),
        if (widget.mode == ChatListMode.normal)
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '全局设置',
            onPressed: () => context.push('/settings'),
          ),
      ],
    );
  }

  /// 构建多选模式下的 AppBar
  AppBar _buildMultiSelectAppBar(WidgetRef ref, int? currentFolderId) {
    final allItems = ref.watch(chatListProvider((parentFolderId: currentFolderId, mode: widget.mode))).value ?? [];
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: '取消选择',
        onPressed: () => _toggleMultiSelectMode(enable: false),
      ),
      title: Text(
        '已选择 ${_selectedItemIds.length} 项',
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
          onPressed: () => _selectAll(allItems),
        ),
        IconButton(
          icon: const Icon(Icons.deselect),
          tooltip: '全不选',
          onPressed: _deselectAll,
        ),
        IconButton(
          icon: const Icon(Icons.flip_to_back_outlined),
          tooltip: '反选',
          onPressed: () => _invertSelection(allItems),
        ),
        IconButton(
          icon: const Icon(Icons.upload_file_outlined),
          tooltip: '导出所选',
          onPressed: _selectedItemIds.isEmpty ? null : _exportSelected,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: '删除所选',
          onPressed: _selectedItemIds.isEmpty ? null : _showMultiDeleteConfirmationDialog,
        ),
      ],
    );
  }


  // --- 显示创建菜单 (根据是否在文件夹内调整) ---
  void _showCreateMenu(BuildContext context, WidgetRef ref, int? currentFolderId) {
    // 根据模式显示不同的菜单项
    final isNormalMode = widget.mode == ChatListMode.normal;
    final isManageMode = widget.mode == ChatListMode.templateManagement;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: <Widget>[
            if (isNormalMode)
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: const Text('新建聊天'),
                onTap: () {
                  Navigator.pop(ctx);
                  // 关键修复：导航到模板选择时，带上当前文件夹ID作为来源
                  ref.read(currentFolderIdProvider.notifier).state = null;
                  context.push('/list?mode=select&from_folder_id=$currentFolderId');
                },
              ),
            if (isNormalMode)
              ListTile(
                leading: const Icon(Icons.note_add_outlined),
                title: const Text('管理模板'),
                onTap: () {
                  Navigator.pop(ctx);
                  // 关键修复：进入模板管理时，重置文件夹上下文
                  ref.read(currentFolderIdProvider.notifier).state = null;
                  context.push('/list?mode=manage');
                },
              ),
            if (isManageMode)
              ListTile(
                leading: const Icon(Icons.add_box_outlined),
                title: const Text('新建空白模板'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final newChat = Chat(
                    title: '新模板 ${DateFormat.Hm().format(DateTime.now())}',
                    parentFolderId: currentFolderId,
                    createdAt: kTemplateTimestamp, // 使用常量
                    updatedAt: kTemplateTimestamp, // 使用常量
                  );
                  try {
                    final repo = ref.read(chatRepositoryProvider);
                    await repo.saveChat(newChat);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('空白模板已创建')));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('创建失败: $e'), backgroundColor: Colors.red));
                    }
                  }
                },
              ),
            // 创建文件夹功能在普通和管理模式下都可用
            if (isNormalMode || isManageMode)
              ListTile(
                leading: const Icon(Icons.create_new_folder_outlined),
                title: const Text('新建文件夹'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _showCreateFolderDialog(context, ref, currentFolderId);
                },
              ),
          ],
        ),
      ),
    );
  }

  // --- 显示创建文件夹对话框 (接收 parentFolderId) ---
  Future<void> _showCreateFolderDialog(BuildContext context, WidgetRef ref, int? parentFolderId) async {
    final folderNameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final folderName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建文件夹'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: folderNameController,
            autofocus: true,
            decoration: const InputDecoration(hintText: '输入文件夹名称'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '文件夹名称不能为空';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(folderNameController.text.trim());
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (folderName != null && folderName.isNotEmpty) {
      try {
        final repo = ref.read(chatRepositoryProvider);
        final isTemplateMode = widget.mode == ChatListMode.templateManagement;
        
        // 调用仓库中新增的、更清晰的方法来创建文件夹
        await repo.addFolder(
          title: folderName,
          isTemplate: isTemplateMode,
          parentFolderId: parentFolderId,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('文件夹 "$folderName" 已创建'), duration: const Duration(seconds: 1)));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('创建文件夹失败: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }
}

// --- 封装的私有小部件 ---

/// “返回上一级”的拖放目标小部件
class _MoveUpTarget extends StatelessWidget {
  final bool isListView;
  const _MoveUpTarget({super.key, required this.isListView});

  @override
  Widget build(BuildContext context) {
    if (isListView) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        color: Theme.of(context).hoverColor,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.arrow_upward, size: 18),
            SizedBox(width: 8),
            Text('拖动到此处以上移'),
          ],
        ),
      );
    } else {
      return GridTile(
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).hoverColor,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_upward, size: 24),
              SizedBox(height: 8),
              Text('移至上一级', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );
    }
  }
}

/// 列表视图中的聊天项小部件
class _ChatListItem extends ConsumerWidget { // 转换为 ConsumerWidget
  final Chat chat;
  final bool isSelected;
  final bool isMultiSelectMode;
  final VoidCallback onTap;

  const _ChatListItem({
    required this.chat,
    required this.isSelected,
    required this.isMultiSelectMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) { // 添加 WidgetRef
    // 订阅第一条模型消息
    final firstModelMessage = ref.watch(firstModelMessageProvider(chat.id));

    return Container(
      color: isSelected ? Theme.of(context).highlightColor : null,
      child: InkWell(
        onTap: onTap,
        child: chat.isFolder
            ? ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(chat.title ?? '未命名文件夹'),
                // 修正：为文件夹也添加时间戳判断，以防万一
                subtitle: Text(
                  chat.updatedAt.millisecondsSinceEpoch < 1000
                      ? '文件夹' // 修正：不再显示“模板文件夹”，避免语义混淆
                      : '文件夹 - ${DateFormat.yMd().add_Hm().format(chat.updatedAt)}',
                ),
                trailing: isMultiSelectMode ? Icon(isSelected ? Icons.check_box : Icons.check_box_outline_blank) : null,
              )
            : ListTile(
                leading: _buildLeading(context, chat),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 第一行：标题和时间
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            chat.title ?? '无标题聊天',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            // 标题加粗
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        // 使用毫秒数进行比较，避免时区问题 (允许1秒误差)
                        if (chat.updatedAt.millisecondsSinceEpoch >= 1000)
                          Text(
                            DateFormat.yMd().add_jm().format(chat.updatedAt),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4), // 间距
                    // 第二行：第一条模型消息预览
                    Text(
                      chat.updatedAt.millisecondsSinceEpoch < 1000
                          ? '模板' // 如果是模板，显示“模板”
                          : (firstModelMessage?.displayText ?? ''), // 否则显示第一条模型消息, 无消息则为空
                      // 消息内容与标题字号相同
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: chat.updatedAt.millisecondsSinceEpoch < 1000 ? Theme.of(context).colorScheme.primary : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                trailing: isMultiSelectMode ? Icon(isSelected ? Icons.check_box : Icons.check_box_outline_blank) : null,
              ),
      ),
    );
  }

  Widget _buildLeading(BuildContext context, Chat chat) {
    final bool hasImage = chat.coverImageBase64 != null && chat.coverImageBase64!.isNotEmpty;
    Widget leadingWidget;
    if (hasImage) {
      final pixelRatio = MediaQuery.of(context).devicePixelRatio;
      leadingWidget = CachedImageFromBase64(
        base64String: chat.coverImageBase64!,
        width: 50,
        height: 50,
        cacheWidth: (50 * pixelRatio).round(),
        cacheHeight: (50 * pixelRatio).round(),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 50, color: Colors.grey),
      );
    } else {
      leadingWidget = const Icon(Icons.chat_bubble_outline, size: 40, color: Colors.grey);
    }
    return CircleAvatar(
      radius: 25,
      backgroundColor: hasImage ? Colors.transparent : Theme.of(context).colorScheme.primaryContainer,
      child: ClipOval(child: leadingWidget),
    );
  }
}

/// 网格视图中的聊天项小部件
class _ChatGridItem extends ConsumerWidget { // 转换为 ConsumerWidget
  final Chat chat;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChatGridItem({
    required this.chat,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) { // 添加 WidgetRef
    // 订阅第一条模型消息
    final firstModelMessage = ref.watch(firstModelMessageProvider(chat.id));

    Widget displayWidget;
    if (chat.isFolder) {
      displayWidget = Container(
        color: Colors.amber.shade100,
        child: Icon(Icons.folder_outlined, color: Colors.amber.shade800, size: 50),
      );
    } else {
      if (chat.coverImageBase64 != null && chat.coverImageBase64!.isNotEmpty) {
        displayWidget = CachedImageFromBase64(
          base64String: chat.coverImageBase64!,
          fit: BoxFit.cover,
          cacheWidth: 240, // 优化缓存尺寸
          cacheHeight: 360, // 优化缓存尺寸
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.grey.shade300,
            child: const Icon(Icons.broken_image, color: Colors.grey, size: 40),
          ),
        );
      } else {
        displayWidget = Container(
          color: Colors.grey.shade300,
          child: const Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 40),
        );
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: GridTile(
        footer: GridTileBar(
          backgroundColor: Colors.black54,
          title: Column( // 使用 Column 容纳标题和副标题
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                chat.title ?? (chat.isFolder ? '未命名文件夹' : '无标题'),
                textAlign: TextAlign.center,
                // 标题加粗
                style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              // 如果是模板，则不显示消息预览 (允许1秒误差)
              if (!chat.isFolder && chat.updatedAt.millisecondsSinceEpoch >= 1000 && firstModelMessage != null) ...[
                const SizedBox(height: 2),
                Text(
                  firstModelMessage.displayText,
                  textAlign: TextAlign.center,
                  // 调整消息预览字体大小与标题一致
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade300),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: displayWidget,
            ),
            if (isSelected)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha((255 * 0.3).round()),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: Theme.of(context).primaryColor, width: 2),
                ),
                child: Icon(Icons.check_circle, color: Colors.white.withAlpha((255 * 0.8).round()), size: 30),
              ),
          ],
        ),
      ),
    );
  }
}

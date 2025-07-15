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
import '../providers/core_providers.dart'; // 导入 SharedPreferences Provider
import 'package:shared_preferences/shared_preferences.dart'; // 导入 SharedPreferences
import '../widgets/chat_list_app_bar.dart';
import '../widgets/chat_list_body.dart';

// --- 文件功能 ---
// 本文件是聊天列表页面的主屏幕，作为状态管理和业务逻辑的核心协调中心。
//
// --- 核心职责 ---
// 1. **状态管理**:
//    - 管理核心UI状态，如视图模式（列表/网格）、多选模式、选中项集合等。
//    - 通过 `_localChats` 本地缓存和 `_isReordering` 标志位实现拖拽操作的乐观更新。
//    - 使用 `ref.listen` 监听远程数据源 (`chatListProvider`)，并在适当时机（非拖拽时）同步数据到本地缓存，解决UI闪烁问题。
// 2. **业务逻辑处理**:
//    - 实现所有用户交互的核心处理方法，如 `_handleItemTap`, `_handleListViewReorder`, `_handleGridViewReorder`。
//    - 管理多选操作逻辑（全选、删除、导出等）。
//    - 处理新建项目（聊天、模板、文件夹）和导入导出的逻辑。
// 3. **UI组件编排**:
//    - 构建顶层 `Scaffold`。
//    - 将状态和回调函数传递给子组件 `ChatListAppBar` 和 `ChatListBody`，由它们负责具体的UI渲染。
//
// --- 代码结构 (重构后) ---
// - **`ChatListScreen` / `_ChatListScreenState`**: 专注于状态和逻辑。
// - **`ChatListAppBar`**: 独立的 AppBar 组件，负责渲染所有顶部操作栏UI。
// - **`ChatListBody`**: 独立的主体内容组件，负责渲染列表、网格、加载、错误和空状态。
// - **`ChatListItem` / `ChatGridItem`**: 独立的列表/网格项组件。


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

  @override
  void initState() {
    super.initState();
    _loadViewMode();
  }

  // --- 新增：加载视图模式 ---
  Future<void> _loadViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isGridView = prefs.getBool('chat_list_is_grid_view') ?? false;
    });
  }

  // --- 新增：保存视图模式 ---
  Future<void> _saveViewMode(bool isGridView) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('chat_list_is_grid_view', isGridView);
  }

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





  @override
  Widget build(BuildContext context) {
    final currentFolderId = ref.watch(currentFolderIdProvider);
    final chatListProviderInstance = chatListProvider((parentFolderId: currentFolderId, mode: widget.mode));
    
    // 优化：仅在文件夹内（currentFolderId != null）时才订阅 currentChatProvider。
    final currentFolderAsync = currentFolderId != null
        ? ref.watch(currentChatProvider(currentFolderId))
        : const AsyncValue<Chat?>.data(null);

    // 最终闪烁修复：使用 ref.listen 在后台同步数据，而UI始终依赖 _localChats。
    ref.listen(chatListProviderInstance, (previous, next) {
      // 仅在非拖拽状态下接受来自 Provider 的更新
      if (!_isReordering && next.hasValue) {
        setState(() {
          _localChats = next.value;
        });
      }
    });

    // 关键修复：当文件夹改变时，清空本地缓存以触发加载状态
    ref.listen(currentFolderIdProvider, (previous, next) {
      if (previous != next) {
        setState(() {
          _localChats = null;
        });
      }
    });

    // 从 Provider 获取初始状态，用于处理加载和错误情况
    final chatListAsync = ref.watch(chatListProviderInstance);

    // 关键修复：确保在重建时（例如，从其他页面返回），如果本地状态丢失但Provider有数据，能立即恢复。
    if (_localChats == null && chatListAsync.hasValue) {
      _localChats = chatListAsync.value;
    }

    final Widget body = ChatListBody(
      mode: widget.mode,
      isGridView: _isGridView,
      localChats: _localChats,
      chatListAsync: chatListAsync,
      currentFolderId: currentFolderId,
      selectedItemIds: _selectedItemIds,
      draggedItemId: _draggedItemId,
      isMultiSelectMode: _isMultiSelectMode,
      proxyDecorator: _buildDragProxy,
      onListViewReorder: _handleListViewReorder,
      onGridViewReorder: _handleGridViewReorder,
      onReorderStart: (index) {
        final inFolder = ref.read(currentFolderIdProvider) != null;
        final chatIndex = inFolder ? index - 1 : index;
        if (chatIndex >= 0 && chatIndex < (_localChats?.length ?? 0)) {
          final draggedChat = _localChats![chatIndex];
          if (_isMultiSelectMode && _selectedItemIds.contains(draggedChat.id)) {
            setState(() {
              _draggedItemId = draggedChat.id;
            });
          }
        }
      },
      onReorderEnd: (index) {
        if (_draggedItemId != null) {
          setState(() {
            _draggedItemId = null;
          });
        }
      },
      onItemTap: _handleItemTap,
      dragWidgetBuilder: DragWidgetBuilderV2(
        isScreenshotDragWidget: false,
        builder: (index, child, screenshot) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final inFolder = ref.read(currentFolderIdProvider) != null;
            final chatIndex = inFolder ? index - 1 : index;

            final List<Chat> displayChats;
            if (_isMultiSelectMode && _draggedItemId != null) {
              displayChats = _localChats!.where((chat) => !_selectedItemIds.contains(chat.id)).toList();
            } else {
              displayChats = _localChats ?? [];
            }
            
            if (chatIndex >= 0 && chatIndex < displayChats.length) {
               final draggedChat = displayChats[chatIndex];
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
    );

    return Scaffold(
      appBar: ChatListAppBar(
        mode: widget.mode,
        isMultiSelectMode: _isMultiSelectMode,
        isGridView: _isGridView,
        currentFolderId: currentFolderId,
        currentFolderAsync: currentFolderAsync,
        selectedItemCount: _selectedItemIds.length,
        allItems: _localChats ?? [],
        onToggleMultiSelectMode: () => _toggleMultiSelectMode(enable: !_isMultiSelectMode),
        onToggleViewMode: () {
          setState(() {
            _isGridView = !_isGridView;
            _saveViewMode(_isGridView);
          });
        },
        onImport: () async {
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
        onSelectAll: () => _selectAll(_localChats ?? []),
        onDeselectAll: _deselectAll,
        onInvertSelection: () => _invertSelection(_localChats ?? []),
        onExport: _exportSelected,
        onDelete: _showMultiDeleteConfirmationDialog,
      ),
      body: body,
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
            if (context.mounted) {
              context.go('/chat');
            }
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
            if (context.mounted) {
              context.go('/chat'); // 直接进入新创建的聊天
            }
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
                  final now = DateTime.now();
                  final newChat = Chat(
                    title: '新模板 ${DateFormat.Hm().format(now)}',
                    parentFolderId: currentFolderId,
                    createdAt: now,
                    updatedAt: now,
                    orderIndex: null, // 确保新模板置顶
                    backgroundImagePath: '/template/chat', // 新的模板逻辑
                  );
                  try {
                    final repo = ref.read(chatRepositoryProvider);
                    // saveChat 现在会自动处理用户绑定
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
        // addFolder (通过 saveChat) 现在会自动处理用户绑定
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

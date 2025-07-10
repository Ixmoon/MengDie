import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // 用于导航
import 'package:intl/intl.dart'; // 用于日期格式化
import 'package:reorderable_grid_view/reorderable_grid_view.dart'; // 导入拖放网格视图包

// 导入模型、Provider 和 Widget
import '../../data/models/models.dart';
import '../../data/providers/chat_state_providers.dart';
import '../../data/repositories/chat_repository.dart'; // 需要 chatRepositoryProvider
import '../../service/process/chat_export_import.dart'; // 导入导出/导入服务
import '../widgets/cached_image.dart'; // 导入缓存图片组件
import '../../data/providers/core_providers.dart'; // 导入 SharedPreferences Provider
// import '../widgets/chat_list_item.dart'; // 不再直接使用 ChatListItem

// 本文件包含显示聊天列表的主屏幕。

// --- 聊天列表屏幕 ---
// 使用 ConsumerStatefulWidget 以便访问 Ref 并管理本地状态（如视图模式、多选）。
class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  // 本地状态变量
  bool _isGridView = false; // 控制列表视图或网格视图
  bool _isMultiSelectMode = false; // 控制是否处于多选模式
  final Set<int> _selectedItemIds = {}; // 存储选中的项目 ID (改为 final)

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

  // --- 统一的拖放处理逻辑 ---
  Future<void> _handleReorder(int oldIndex, int newIndex) async {
    final currentFolderId = ref.read(currentFolderIdProvider);
    final inFolder = currentFolderId != null;
    final repo = ref.read(chatRepositoryProvider);
    final currentChats = ref.read(chatListProvider(currentFolderId)).value ?? [];

    // 检查 mounted 状态
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // --- Case 1: 移动到上一级文件夹 ---
    if (inFolder && newIndex == 0) {
      final dataOldIndex = oldIndex - 1;
      final parentFolder = ref.read(currentChatProvider(currentFolderId)).value;
      if (dataOldIndex < 0 || dataOldIndex >= currentChats.length || parentFolder == null) return;

      final movedItem = currentChats[dataOldIndex];
      movedItem.parentFolderId = parentFolder.parentFolderId;
      movedItem.orderIndex = null; // 重置顺序
      movedItem.updatedAt = DateTime.now();
      
      try {
        await repo.saveChat(movedItem);
        if (mounted) {
          scaffoldMessenger.showSnackBar(SnackBar(
            content: Text("'${movedItem.title}' 已移至上一级"),
            backgroundColor: Colors.green,
          ));
        }
      } catch (e) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(SnackBar(content: Text('移动失败: $e'), backgroundColor: Colors.red));
        }
      }
      return;
    }

    // --- Case 2 & 3: 拖入文件夹或普通排序 ---
    final dataOldIndex = inFolder ? oldIndex - 1 : oldIndex;
    
    // 列表视图和网格视图的目标索引计算方式不同
    final dataTargetIndex = _isGridView
      ? (inFolder ? newIndex - 1 : newIndex)
      : (inFolder ? ((newIndex > oldIndex) ? newIndex - 2 : newIndex - 1) : ((newIndex > oldIndex) ? newIndex - 1 : newIndex));

    // --- Case 2: 拖入文件夹 ---
    if (dataTargetIndex >= 0 && dataTargetIndex < currentChats.length &&
        currentChats[dataTargetIndex].isFolder && !currentChats[dataOldIndex].isFolder) {
      
      final movedItem = currentChats[dataOldIndex];
      final targetFolder = currentChats[dataTargetIndex];
      movedItem.parentFolderId = targetFolder.id;
      movedItem.orderIndex = null; // 重置顺序
      movedItem.updatedAt = DateTime.now();

      try {
        await repo.saveChat(movedItem);
        if (mounted) {
          scaffoldMessenger.showSnackBar(SnackBar(
            content: Text("'${movedItem.title}' 已移至 '${targetFolder.title}'"),
            backgroundColor: Colors.green,
          ));
        }
      } catch (e) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(SnackBar(content: Text('移动失败: $e'), backgroundColor: Colors.red));
        }
      }
    } else {
      // --- Case 3: 普通排序 ---
      List<Chat> reorderedList = List.from(currentChats);
      final itemToMove = reorderedList.removeAt(dataOldIndex);
      // 插入位置的计算也需要考虑视图类型
      final dataInsertIndex = _isGridView
        ? (inFolder ? ((newIndex > oldIndex ? newIndex - 1 : newIndex) - 1) : (newIndex > oldIndex ? newIndex - 1 : newIndex))
        : (inFolder ? ((newIndex > oldIndex ? newIndex - 1 : newIndex) - 1) : (newIndex > oldIndex ? newIndex - 1 : newIndex));
        
      reorderedList.insert(dataInsertIndex.clamp(0, reorderedList.length), itemToMove);
      
      List<Chat> chatsToUpdate = [];
      for (int i = 0; i < reorderedList.length; i++) {
        if (reorderedList[i].orderIndex != i) {
          reorderedList[i].orderIndex = i;
          reorderedList[i].updatedAt = DateTime.now();
          chatsToUpdate.add(reorderedList[i]);
        }
      }

      if (chatsToUpdate.isNotEmpty) {
        try {
          await repo.updateChatOrder(chatsToUpdate);
        } catch (e) {
          if (mounted) {
            scaffoldMessenger.showSnackBar(SnackBar(content: Text('更新顺序失败: $e'), backgroundColor: Colors.red));
          }
        }
      }
    }
  }


  // --- 构建列表视图 ---
  Widget _buildListView(List<Chat> chats, WidgetRef ref) {
    final inFolder = ref.watch(currentFolderIdProvider) != null;
    final itemCount = inFolder ? chats.length + 1 : chats.length;

    return ReorderableListView.builder(
      itemExtent: 76.0,
      padding: const EdgeInsets.only(top: 8),
      itemCount: itemCount,
      buildDefaultDragHandles: false,
      itemBuilder: (context, index) {
        if (inFolder && index == 0) {
          return const _MoveUpTarget(key: ValueKey('move-up-target-list'), isListView: true);
        }
        final chatIndex = inFolder ? index - 1 : index;
        final chat = chats[chatIndex];
        
        return ReorderableDelayedDragStartListener(
          key: ValueKey(chat.id),
          index: index,
          enabled: !_isMultiSelectMode,
          child: _ChatListItem(
            chat: chat,
            isSelected: _selectedItemIds.contains(chat.id),
            isMultiSelectMode: _isMultiSelectMode,
            onTap: () async {
              if (_isMultiSelectMode) {
                _toggleItemSelection(chat.id);
              } else {
                if (chat.isFolder) {
                  ref.read(currentFolderIdProvider.notifier).state = chat.id;
                } else {
                  // 保存最后打开的聊天ID
                  final prefs = await ref.read(sharedPreferencesProvider.future);
                  await prefs.setInt('last_open_chat_id', chat.id);
                  ref.read(activeChatIdProvider.notifier).state = chat.id;
                  if (!context.mounted) return;
                  context.go('/chat');
                }
              }
            },
          ),
        );
      },
      onReorder: _handleReorder,
    );
  }


  // --- 构建网格视图 ---
  Widget _buildGridView(List<Chat> chats, WidgetRef ref) {
    final inFolder = ref.watch(currentFolderIdProvider) != null;
    final itemCount = inFolder ? chats.length + 1 : chats.length;

    return ReorderableGridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
        childAspectRatio: 1 / 1.5,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (inFolder && index == 0) {
          return const _MoveUpTarget(key: ValueKey('move-up-target-grid'), isListView: false);
        }
        final chatIndex = inFolder ? index - 1 : index;
        final chat = chats[chatIndex];
        
        return ReorderableDragStartListener(
          key: ValueKey(chat.id),
          index: index,
          enabled: !_isMultiSelectMode,
          child: _ChatGridItem(
            chat: chat,
            isSelected: _selectedItemIds.contains(chat.id),
            onTap: () async {
              if (_isMultiSelectMode) {
                _toggleItemSelection(chat.id);
              } else {
                if (chat.isFolder) {
                  ref.read(currentFolderIdProvider.notifier).state = chat.id;
                } else {
                  // 保存最后打开的聊天ID
                  final prefs = await ref.read(sharedPreferencesProvider.future);
                  await prefs.setInt('last_open_chat_id', chat.id);
                  ref.read(activeChatIdProvider.notifier).state = chat.id;
                  if (!context.mounted) return;
                  context.go('/chat');
                }
              }
            },
          ),
        );
      },
      onReorder: _handleReorder,
    );
  }


  @override
  Widget build(BuildContext context) {
    final currentFolderId = ref.watch(currentFolderIdProvider);
    final chatListAsync = ref.watch(chatListProvider(currentFolderId));
    final currentFolderAsync = ref.watch(currentChatProvider(currentFolderId ?? -1));

    return Scaffold(
      appBar: _buildAppBar(context, ref, currentFolderId, currentFolderAsync), // 使用单独的方法构建 AppBar
      body: chatListAsync.when(
                   data: (chats) {
                     if (chats.isEmpty && currentFolderId == null) { // 根目录为空
                       return const Center(child: Text('点击右下角 + 开始新聊天'));
                     } else if (chats.isEmpty && currentFolderId != null) { // 文件夹为空
                        return const Center(child: Text('此文件夹为空'));
                     }
                     // 根据 _isGridView 切换视图
                     return _isGridView
                         ? _buildGridView(chats, ref)
                         : _buildListView(chats, ref);
                   },
                   loading: () => const SizedBox.shrink(),
                   error: (error, stack) => Center(child: Text('无法加载列表: $error')),
                 ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateMenu(context, ref, currentFolderId), // 传递 currentFolderId
        tooltip: '新建',
        child: const Icon(Icons.add),
      ),
    );
  }

  // --- 构建 AppBar (根据模式切换) ---
  AppBar _buildAppBar(BuildContext context, WidgetRef ref, int? currentFolderId, AsyncValue<Chat?> currentFolderAsync) {
    if (_isMultiSelectMode) {
      // --- 多选模式 AppBar ---
      final allItems = ref.watch(chatListProvider(currentFolderId)).value ?? [];
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
              Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 1.0)
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
            // 仅在有选中项时启用
            onPressed: _selectedItemIds.isEmpty ? null : _showMultiDeleteConfirmationDialog,
          ),
        ],
      );
    } else {
      // --- 普通模式 AppBar ---
      return AppBar(
         leading: currentFolderId != null
             ? IconButton(
                 icon: const Icon(Icons.arrow_upward),
                 tooltip: '返回上一级',
                 onPressed: () {
                   // 读取当前文件夹信息以获取父 ID
                   final parentId = currentFolderAsync.whenData((folder) => folder?.parentFolderId).value;
                   ref.read(currentFolderIdProvider.notifier).state = parentId;
                   debugPrint("返回上一级，新的文件夹 ID: $parentId");
                 },
               )
             : null, // 根目录不显示返回按钮
         backgroundColor: Colors.transparent,
         elevation: 0,
         title: Text(
           currentFolderId != null
               ? (currentFolderAsync.whenData((folder) => folder?.title).value ?? '文件夹') // 显示文件夹标题
               : '', // 根目录标题
           style: TextStyle(
             shadows: <Shadow>[
               Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 1.0)
             ],
           ),
         ),
        actions: [
          // 进入多选模式按钮
          IconButton(
            icon: const Icon(Icons.select_all),
            tooltip: '选择项目',
            onPressed: () => _toggleMultiSelectMode(enable: true),
          ),
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view), // Icon can be const if not dynamic
            tooltip: _isGridView ? '切换到列表视图' : '切换到网格视图',
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
          ),
          // --- 新增：导入按钮 ---
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: '导入聊天',
            onPressed: () async {
              // 显示加载指示器
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('正在导入聊天...'), duration: Duration(seconds: 10)),
              );
              try {
                // 调用导入服务
                final count = await ref.read(chatExportImportServiceProvider).importChats();
                if (!context.mounted) return; // 检查 mounted
                ScaffoldMessenger.of(context).hideCurrentSnackBar(); // 隐藏加载指示器

                if (count > 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('成功导入 $count 个聊天！')),
                  );
                } else {
                  // 用户可能取消了文件选择
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('导入已取消或没有导入任何项目'), duration: Duration(seconds: 2)),
                  );
                }
              } catch (e) {
                // 导入失败
                if (!context.mounted) return; // 检查 mounted
                ScaffoldMessenger.of(context).hideCurrentSnackBar(); // 隐藏加载指示器
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('导入失败: $e'), backgroundColor: Colors.red),
                );
              }
            },
          ),
          // --- 结束新增 ---
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '全局设置',
            onPressed: () => context.push('/settings'),
          ),
        ],
      );
    }
  }


  // --- 显示创建菜单 (根据是否在文件夹内调整) ---
  void _showCreateMenu(BuildContext context, WidgetRef ref, int? currentFolderId) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('新建聊天'),
              onTap: () async {
                Navigator.pop(ctx);
                // 创建时设置 parentFolderId
                final newChat = Chat.create(
                    title: '新聊天 ${DateFormat.Hm().format(DateTime.now())}',
                    parentFolderId: currentFolderId // 设置父文件夹 ID
                );
                try {
                  final repo = ref.read(chatRepositoryProvider);
                  final chatId = await repo.saveChat(newChat);
                  if (context.mounted) {
                      ref.read(activeChatIdProvider.notifier).state = chatId;
                      context.go('/chat');
                  }
                } catch (e) {
                  if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('创建聊天失败: $e'), backgroundColor: Colors.red));
                  }
                }
              },
            ),
            // 始终显示创建文件夹选项
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('新建文件夹'),
              onTap: () async {
                Navigator.pop(ctx);
                // 调用时传递 currentFolderId
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
      final newFolder = Chat.create(
        title: folderName,
        isFolder: true,
        parentFolderId: parentFolderId, // 使用传入的 parentFolderId
      );
      try {
        final repo = ref.read(chatRepositoryProvider);
        await repo.saveChat(newFolder);
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
class _ChatListItem extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      color: isSelected ? Theme.of(context).highlightColor : null,
      child: InkWell(
        onTap: onTap,
        child: chat.isFolder
            ? ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(chat.title ?? '未命名文件夹'),
                subtitle: Text('文件夹 - ${DateFormat.yMd().add_Hm().format(chat.updatedAt)}'),
                trailing: isMultiSelectMode ? Icon(isSelected ? Icons.check_box : Icons.check_box_outline_blank) : null,
              )
            : ListTile(
                leading: _buildLeading(context, chat),
                title: Text(chat.title ?? '无标题聊天', maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '更新于: ${DateFormat.yMd().add_jm().format(chat.updatedAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
class _ChatGridItem extends StatelessWidget {
  final Chat chat;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChatGridItem({
    required this.chat,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
          cacheWidth: 240,
          cacheHeight: 360,
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
          title: Text(
            chat.title ?? (chat.isFolder ? '未命名文件夹' : '无标题'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

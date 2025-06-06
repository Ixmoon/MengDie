import 'dart:convert'; // 用于 base64Decode
import 'dart:typed_data'; // 用于 Uint8List
import 'dart:io'; // 仍然可能用于其他文件操作，或者可以根据实际情况移除
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // 用于导航
import 'package:intl/intl.dart'; // 用于日期格式化
import 'package:reorderable_grid_view/reorderable_grid_view.dart'; // 导入拖放网格视图包

// 导入模型、Provider 和 Widget
import '../models/models.dart';
import '../providers/api_key_provider.dart';
import '../providers/chat_state_providers.dart';
import '../repositories/chat_repository.dart'; // 需要 chatRepositoryProvider
import '../services/chat_export_import_service.dart'; // 导入导出/导入服务
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

  // --- 构建列表视图 (支持拖放排序和多选) ---
  Widget _buildListView(List<Chat> chats, WidgetRef ref) {
    // 使用 ReorderableListView.builder
    return ReorderableListView.builder(
      padding: const EdgeInsets.only(top: 8), // const
      itemCount: chats.length,
      // 禁用默认的长按拖动手柄，我们将使用 ReorderableDelayedDragStartListener
      buildDefaultDragHandles: false, // 总是禁用默认手柄
      itemBuilder: (context, index) {
        final chat = chats[index];
        final isSelected = _selectedItemIds.contains(chat.id);

        // 使用 ReorderableDelayedDragStartListener 包裹整个可点击区域
        // key 需要放在 Listener 上，或者其直接子 Widget 上，这里放在 Listener 上
        return ReorderableDelayedDragStartListener(
          key: ValueKey(chat.id), // key 必须在这里供 ReorderableListView 使用
          index: index,
          // 仅在非多选模式下启用拖动
          enabled: !_isMultiSelectMode,
          child: Container(
            // key: ValueKey(chat.id), // key 移到 Listener 上
            color: isSelected ? Theme.of(context).highlightColor : null,
            child: InkWell( // 使用 InkWell 响应点击
              // 长按现在由 ReorderableDelayedDragStartListener 处理
              onTap: () {
                if (_isMultiSelectMode) {
                  _toggleItemSelection(chat.id); // 多选模式下切换选中
                } else {
                  // 普通模式下导航
                  if (chat.isFolder) {
                    ref.read(currentFolderIdProvider.notifier).state = chat.id;
                    debugPrint("进入文件夹: ${chat.title} (ID: ${chat.id})");
                  } else {
                    context.push('/chat/${chat.id}');
                  }
                }
              },
              // 长按进入多选模式（如果需要的话，可以添加 onLongPress）
              // onLongPress: () {
              //   if (!_isMultiSelectMode) {
              //     _toggleMultiSelectMode(enable: true, initialSelectionId: chat.id);
              //   }
              // },
              child: chat.isFolder
                  ? ListTile(
                      leading: const Icon(Icons.folder_outlined), // const
                      title: Text(chat.title ?? '未命名文件夹'),
                      subtitle: Text('文件夹 - ${DateFormat.yMd().add_Hm().format(chat.updatedAt)}'),
                      // 多选模式下显示复选框
                      trailing: _isMultiSelectMode ? Icon(isSelected ? Icons.check_box : Icons.check_box_outline_blank) : null, // Icon can be const if not dynamic
                    )
                  // 为聊天项构建 ListTile，并添加 Checkbox
                  : ListTile(
                      leading: _buildLeading(context, chat), // 使用辅助方法构建 leading
                      title: Text(chat.title ?? '无标题聊天', maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '更新于: ${DateFormat.yMd().add_jm().format(chat.updatedAt)}',
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // 在多选模式下显示 Checkbox
                      trailing: _isMultiSelectMode ? Icon(isSelected ? Icons.check_box : Icons.check_box_outline_blank) : null,
                    ),
            ),
          ),
        );
      },
      // 添加 onReorder 回调 (与 _buildGridView 逻辑一致, 确保从最新的 Provider 读取数据)
      onReorder: (oldIndex, newIndex) async {
         // 拖放排序逻辑
         debugPrint("ListView Reorder: $oldIndex -> $newIndex");
         final repo = ref.read(chatRepositoryProvider);
         // 从 Provider 获取最新的列表状态，以防万一
         final chatListAsync = ref.read(chatListProvider(ref.read(currentFolderIdProvider)));
         final currentChats = chatListAsync.value ?? []; // 使用当前加载的数据
         if (currentChats.isEmpty || oldIndex < 0 || oldIndex >= currentChats.length) {
            debugPrint("ListView Reorder 错误: 列表为空或 oldIndex $oldIndex 超出范围");
            return;
         }
         final Chat movedItem = currentChats[oldIndex];

         // 拖入文件夹逻辑
         int targetIndex = newIndex;
         if (newIndex > oldIndex) {
             targetIndex = newIndex - 1; // 向下拖动时，目标是新位置的前一个
         }
         // 检查目标索引是否有效且是文件夹
         if (targetIndex >= 0 && targetIndex < currentChats.length && currentChats[targetIndex].isFolder && !movedItem.isFolder) {
             final targetFolder = currentChats[targetIndex];
             debugPrint("ListView: 移动 '${movedItem.title}' 到文件夹 '${targetFolder.title}' (ID: ${targetFolder.id})");
             movedItem.parentFolderId = targetFolder.id;
             movedItem.orderIndex = null; // 进入文件夹后由数据库排序
             movedItem.updatedAt = DateTime.now();
             try {
                 await repo.saveChat(movedItem);
                 debugPrint("ListView: 成功将项目移动到文件夹。");
                 // StreamProvider 会自动刷新列表
                 // 添加成功提示
                 if (mounted) {
                     final scaffoldMessenger = ScaffoldMessenger.of(context);
                     scaffoldMessenger.showSnackBar(
                         SnackBar(
                             content: Text("'${movedItem.title}' 已移动到文件夹 '${targetFolder.title}'"),
                             backgroundColor: Colors.green, // 绿色表示成功
                             duration: const Duration(seconds: 2),
                         ),
                     );
                 }
              } catch (e) {
                   debugPrint("ListView: 移动项目到文件夹时出错: $e");
                   // 异步操作后检查 State 是否挂载
                   if (mounted) { // 使用 State 的 mounted 属性
                       final scaffoldMessenger = ScaffoldMessenger.of(context); // 移到 mounted 检查内部
                       scaffoldMessenger.showSnackBar( // 使用捕获的 scaffoldMessenger
                           SnackBar(content: Text('移动到文件夹失败: $e'), backgroundColor: Colors.red),
                      );
                  }
              }
         } else {
             // 普通排序逻辑
             debugPrint("ListView: 执行普通排序操作...");
             List<Chat> reorderedList = List.from(currentChats);
             final Chat itemToMove = reorderedList.removeAt(oldIndex);
             // 确保插入索引有效
             final insertIndex = (newIndex > oldIndex ? newIndex - 1 : newIndex).clamp(0, reorderedList.length);
             reorderedList.insert(insertIndex, itemToMove);

             // 更新 orderIndex
             List<Chat> chatsToUpdate = [];
             for (int i = 0; i < reorderedList.length; i++) {
               if (reorderedList[i].orderIndex != i) {
                 reorderedList[i].orderIndex = i;
                 reorderedList[i].updatedAt = DateTime.now(); // 更新时间戳
                 chatsToUpdate.add(reorderedList[i]);
               }
             }
             if (chatsToUpdate.isNotEmpty) {
               try {
                 await repo.updateChatOrder(chatsToUpdate);
                 debugPrint("ListView: 成功更新了 ${chatsToUpdate.length} 个项目的顺序。");
                 } catch (e) {
                   debugPrint("ListView: 更新聊天顺序时出错: $e");
                   // 异步操作后检查 State 是否挂载
                   if (mounted) { // 使用 State 的 mounted 属性
                     final scaffoldMessenger = ScaffoldMessenger.of(context); // 移到 mounted 检查内部
                     scaffoldMessenger.showSnackBar( // 使用捕获的 scaffoldMessenger
                       SnackBar(content: Text('更新顺序失败: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
             } else {
                debugPrint("ListView: 顺序未改变，无需更新。");
             }
           }
      },
    );
  }

  // --- 辅助方法：构建 ListTile 的 leading (从 ChatListItem 提取) ---
  Widget _buildLeading(BuildContext context, Chat chat) {
    Widget leadingWidget;
    if (chat.coverImageBase64 != null && chat.coverImageBase64!.isNotEmpty) {
      try {
        final Uint8List imageBytes = base64Decode(chat.coverImageBase64!);
        leadingWidget = Image.memory(
          imageBytes,
          width: 50,
          height: 50,
          cacheWidth: 100,
          cacheHeight: 100,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.broken_image, size: 50, color: Colors.grey);
          },
        );
      } catch (e) {
        leadingWidget = const Icon(Icons.broken_image, size: 50, color: Colors.grey);
      }
    } else {
      leadingWidget = const Icon(Icons.chat_bubble_outline, size: 40, color: Colors.grey);
    }
    return CircleAvatar(
      radius: 25,
      backgroundColor: (chat.coverImageBase64 != null && chat.coverImageBase64!.isNotEmpty && !(leadingWidget is Icon && (leadingWidget as Icon).icon == Icons.broken_image))
          ? Colors.transparent
          : Theme.of(context).colorScheme.primaryContainer,
      child: leadingWidget,
    );
  }

  // --- 构建网格视图 (支持拖放排序和多选) ---
  Widget _buildGridView(List<Chat> chats, WidgetRef ref) {
    return ReorderableGridView.builder(
      padding: const EdgeInsets.all(8.0), // const
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount( // const
        crossAxisCount: 3,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
        childAspectRatio: 1 / 1.5, // 修改宽高比为 1:1.5 (竖直长方形)
      ),
      itemCount: chats.length,
      itemBuilder: (context, index) {
        final chat = chats[index];
        final isSelected = _selectedItemIds.contains(chat.id);
        Widget displayWidget;

        if (chat.isFolder) {
          displayWidget = Container(
            color: Colors.amber.shade100,
            child: Icon(Icons.folder_outlined, color: Colors.amber.shade800, size: 50),
          );
        } else {
          if (chat.coverImageBase64 != null && chat.coverImageBase64!.isNotEmpty) {
            try {
              final Uint8List imageBytes = base64Decode(chat.coverImageBase64!);
              displayWidget = Image.memory(
                imageBytes,
                fit: BoxFit.cover,
                cacheWidth: 240, 
                cacheHeight: 360,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.broken_image, color: Colors.grey, size: 40),
                ),
              );
            } catch (e) {
              displayWidget = Container(
                color: Colors.grey.shade300,
                child: const Icon(Icons.broken_image, color: Colors.grey, size: 40),
              );
            }
          } else {
            displayWidget = Container(
              color: Colors.grey.shade300,
              child: const Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 40),
            );
          }
        }

        return ReorderableDragStartListener(
          key: ValueKey(chat.id),
          index: index,
          // 禁用拖动当处于多选模式时
          enabled: !_isMultiSelectMode,
          // 移除 GestureDetector 的 onLongPress
          child: GestureDetector(
            onTap: () {
              if (_isMultiSelectMode) {
                _toggleItemSelection(chat.id); // 多选模式下切换选中
              } else {
                // 普通模式下导航
                if (chat.isFolder) {
                  ref.read(currentFolderIdProvider.notifier).state = chat.id;
                  debugPrint("进入文件夹: ${chat.title} (ID: ${chat.id})");
                } else {
                  context.push('/chat/${chat.id}');
                }
              }
            },
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
              child: Stack( // 使用 Stack 添加选中覆盖层
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: displayWidget,
                  ),
                  // 选中时的覆盖层
                   if (isSelected)
                     Container(
                       decoration: BoxDecoration(
                         color: Colors.black.withAlpha((255 * 0.3).round()), // 使用 withAlpha
                         borderRadius: BorderRadius.circular(8.0),
                         border: Border.all(color: Theme.of(context).primaryColor, width: 2), // 边框高亮
                       ),
                       child: Icon(Icons.check_circle, color: Colors.white.withAlpha((255 * 0.8).round()), size: 30), // 使用 withAlpha
                     ),
                 ],
              ),
            ),
          ),
        );
      },
      onReorder: (oldIndex, newIndex) async {
         // 拖放排序逻辑 (保持不变)
         debugPrint("GridView Reorder: $oldIndex -> $newIndex");
         // 从 Provider 获取最新的列表状态
         final chatListAsync = ref.read(chatListProvider(ref.read(currentFolderIdProvider)));
         final currentChats = chatListAsync.value ?? [];
         if (currentChats.isEmpty || oldIndex < 0 || oldIndex >= currentChats.length) {
            debugPrint("GridView Reorder 错误: 列表为空或 oldIndex $oldIndex 超出范围");
            return;
         }
         final repo = ref.read(chatRepositoryProvider);
         final Chat movedItem = currentChats[oldIndex];

         // 拖入文件夹逻辑
         // GridView 的 newIndex 直接对应目标项
         if (newIndex >= 0 && newIndex < currentChats.length && currentChats[newIndex].isFolder && !movedItem.isFolder) {
             final targetFolder = currentChats[newIndex];
             debugPrint("GridView: 移动 '${movedItem.title}' 到文件夹 '${targetFolder.title}' (ID: ${targetFolder.id})");
             movedItem.parentFolderId = targetFolder.id;
             movedItem.orderIndex = null;
             movedItem.updatedAt = DateTime.now();
             try {
                 await repo.saveChat(movedItem);
                 debugPrint("GridView: 成功将项目移动到文件夹。");
                 // 添加成功提示
                 if (mounted) {
                     final scaffoldMessenger = ScaffoldMessenger.of(context);
                     scaffoldMessenger.showSnackBar(
                         SnackBar(
                             content: Text("'${movedItem.title}' 已移动到文件夹 '${targetFolder.title}'"),
                             backgroundColor: Colors.green, // 绿色表示成功
                             duration: const Duration(seconds: 2),
                         ),
                     );
                 }
               } catch (e) {
                   debugPrint("GridView: 移动项目到文件夹时出错: $e");
                   // 异步操作后检查 State 是否挂载
                   if (mounted) { // 使用 State 的 mounted 属性
                       final scaffoldMessenger = ScaffoldMessenger.of(context); // 移到 mounted 检查内部
                       scaffoldMessenger.showSnackBar( // 使用捕获的 scaffoldMessenger
                           SnackBar(content: Text('移动到文件夹失败: $e'), backgroundColor: Colors.red),
                      );
                  }
              }
         } else {
             // 普通排序逻辑
             debugPrint("GridView: 执行普通排序操作...");
             List<Chat> reorderedList = List.from(currentChats);
             final Chat itemToMove = reorderedList.removeAt(oldIndex);
             // GridView 的 newIndex 可能需要调整
             final insertIndex = (newIndex > oldIndex ? newIndex - 1 : newIndex).clamp(0, reorderedList.length);
             reorderedList.insert(insertIndex, itemToMove);

             List<Chat> chatsToUpdate = [];
             for (int i = 0; i < reorderedList.length; i++) {
               if (reorderedList[i].orderIndex != i) {
                 reorderedList[i].orderIndex = i;
                 reorderedList[i].updatedAt = DateTime.now(); // 更新时间戳
                 chatsToUpdate.add(reorderedList[i]);
               }
             }
             if (chatsToUpdate.isNotEmpty) {
               try {
                 await repo.updateChatOrder(chatsToUpdate);
                 debugPrint("GridView: 成功更新了 ${chatsToUpdate.length} 个项目的顺序。");
                 } catch (e) {
                   debugPrint("GridView: 更新聊天顺序时出错: $e");
                   // 异步操作后检查 State 是否挂载
                   if (mounted) { // 使用 State 的 mounted 属性
                     final scaffoldMessenger = ScaffoldMessenger.of(context); // 移到 mounted 检查内部
                     scaffoldMessenger.showSnackBar( // 使用捕获的 scaffoldMessenger
                       SnackBar(content: Text('更新顺序失败: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
             } else {
                debugPrint("GridView: 顺序未改变，无需更新。");
             }
           }
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final currentFolderId = ref.watch(currentFolderIdProvider);
    final apiKeyState = ref.watch(apiKeyNotifierProvider);
    final chatListAsync = ref.watch(chatListProvider(currentFolderId));
    final currentFolderAsync = ref.watch(currentChatProvider(currentFolderId ?? -1));

    return Scaffold(
      appBar: _buildAppBar(context, ref, currentFolderId, currentFolderAsync), // 使用单独的方法构建 AppBar
      body: Column(
          children: [
              if (apiKeyState.error != null)
                 Padding(
                   padding: const EdgeInsets.fromLTRB(8, 8, 8, 0), // const
                   child: Card(
                     color: Colors.orange.shade100,
                     child: ListTile(
                       leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange), // const
                       title: Text("API Key 问题", style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold)),
                       subtitle: Text(apiKeyState.error!, style: TextStyle(color: Colors.orange.shade800)),
                       trailing: IconButton(
                         icon: const Icon(Icons.settings, color: Colors.orange), // const
                         tooltip: '前往设置',
                         onPressed: () => context.push('/settings'),
                       ),
                       dense: true,
                     ),
                   ),
                 ),
               Expanded(
                 child: chatListAsync.when(
                   data: (chats) {
                     if (chats.isEmpty && currentFolderId == null) { // 根目录为空
                       return const Center(child: Text('点击右下角 + 开始新聊天')); // const
                     } else if (chats.isEmpty && currentFolderId != null) { // 文件夹为空
                        return const Center(child: Text('此文件夹为空')); // const
                     }
                     // 根据 _isGridView 切换视图
                     return _isGridView
                         ? _buildGridView(chats, ref)
                         : _buildListView(chats, ref);
                   },
                   loading: () => const Center(child: CircularProgressIndicator()), // const
                   error: (error, stack) => Center(child: Text('无法加载列表: $error')),
                 ),
               ),
            ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateMenu(context, ref, currentFolderId), // 传递 currentFolderId
        tooltip: '新建',
        child: const Icon(Icons.add), // const
      ),
    );
  }

  // --- 构建 AppBar (根据模式切换) ---
  AppBar _buildAppBar(BuildContext context, WidgetRef ref, int? currentFolderId, AsyncValue<Chat?> currentFolderAsync) {
    if (_isMultiSelectMode) {
      // --- 多选模式 AppBar ---
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close), // const
          tooltip: '取消选择',
          onPressed: () => _toggleMultiSelectMode(enable: false),
        ),
        title: Text('已选择 ${_selectedItemIds.length} 项'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline), // const
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
                 icon: const Icon(Icons.arrow_upward), // const
                 tooltip: '返回上一级',
                 onPressed: () {
                   // 读取当前文件夹信息以获取父 ID
                   final parentId = currentFolderAsync.whenData((folder) => folder?.parentFolderId).value;
                   ref.read(currentFolderIdProvider.notifier).state = parentId;
                   debugPrint("返回上一级，新的文件夹 ID: $parentId");
                 },
               )
             : null, // 根目录不显示返回按钮
         title: Text(
             currentFolderId != null
                 ? (currentFolderAsync.whenData((folder) => folder?.title).value ?? '文件夹') // 显示文件夹标题
                 : '梦蝶' // 根目录标题
         ),
        actions: [
          // 进入多选模式按钮
          IconButton(
            icon: const Icon(Icons.select_all), // const
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
            icon: const Icon(Icons.file_download_outlined), // const: 使用下载/导入图标
            tooltip: '导入聊天',
            onPressed: () async {
              // 显示加载指示器
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('正在导入聊天...'), duration: Duration(seconds: 10)), // const SnackBar, const Text
              );
              try {
                // 调用导入服务
                final newChatId = await ref.read(chatExportImportServiceProvider).importChat();
                if (!context.mounted) return; // 检查 mounted
                ScaffoldMessenger.of(context).hideCurrentSnackBar(); // 隐藏加载指示器

                if (newChatId != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('聊天导入成功！')), // const SnackBar, const Text
                  );
                  // 可选：直接导航到新导入的聊天
                  // context.push('/chat/$newChatId');
                } else {
                  // 用户可能取消了文件选择
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('导入已取消'), duration: Duration(seconds: 2)), // const SnackBar, const Text
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
            icon: const Icon(Icons.settings), // const
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
              leading: const Icon(Icons.chat_bubble_outline), // const
              title: const Text('新建聊天'), // const
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
                      context.push('/chat/$chatId');
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
              leading: const Icon(Icons.create_new_folder_outlined), // const
              title: const Text('新建文件夹'), // const
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
        title: const Text('新建文件夹'), // const
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: folderNameController,
            autofocus: true,
            decoration: const InputDecoration(hintText: '输入文件夹名称'), // const
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '文件夹名称不能为空';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')), // const
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(folderNameController.text.trim());
              }
            },
            child: const Text('创建'), // const
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

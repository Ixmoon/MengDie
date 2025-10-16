import 'dart:convert';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers/chat_state_providers.dart';
import '../../app/services/prompt_service.dart';
import '../../domain/enums.dart';
import '../../domain/models/prompt_item.dart';

// Main Screen Widget
class PromptEditorScreen extends ConsumerStatefulWidget {
  const PromptEditorScreen({super.key});

  @override
  ConsumerState<PromptEditorScreen> createState() => _PromptEditorScreenState();
}

class _PromptEditorScreenState extends ConsumerState<PromptEditorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  final List<String?> _chatFolderPath = [null]; 
  final List<String?> _globalFolderPath = [null];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<String?> get _currentFolderPath =>
      _tabController.index == 0 ? _chatFolderPath : _globalFolderPath;

  String? get _currentParentId => _currentFolderPath.last;

  void _navigateToFolder(String folderId) {
    setState(() {
      _currentFolderPath.add(folderId);
    });
  }

  void _navigateBack() {
    if (_currentFolderPath.length > 1) {
      setState(() {
        _currentFolderPath.removeLast();
      });
    }
  }

  Future<void> _exportPrompts(BuildContext context, int chatId) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final promptService = ref.read(promptServiceProvider.notifier);
    final isGlobal = _tabController.index == 1;
    final parentId = _currentParentId;

    String jsonString;
    String fileName;
    String exportScope = 'all'; // 'all' or 'folder'

    // If inside a folder, ask the user what to export
    if (parentId != null) {
      final scope = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('选择导出范围'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('folder'),
              child: const Text('仅导出当前文件夹'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('all'),
              child: const Text('导出整个列表'),
            ),
          ],
        ),
      );
      if (scope == null) {
        scaffoldMessenger.showSnackBar(const SnackBar(content: Text('导出已取消')));
        return;
      }
      exportScope = scope;
    }

    if (isGlobal) {
      if (exportScope == 'all') {
        // Only show status option when exporting the whole global list
        final exportOption = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('选择导出选项'),
            content: const Text('您想如何导出全局提示词？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop('items_only'),
                child: const Text('仅导出条目'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop('with_statuses'),
                child: const Text('导出并包含所有开关状态'),
              ),
            ],
          ),
        );

        if (exportOption == null) {
          scaffoldMessenger.showSnackBar(const SnackBar(content: Text('导出已取消')));
          return;
        }

        if (exportOption == 'with_statuses') {
          jsonString = promptService.exportGlobalPromptsWithStatuses();
          fileName = 'mengdie_prompts_global_with_statuses.json';
        } else {
          jsonString = promptService.exportPrompts(isGlobal: true, chatId: chatId);
          fileName = 'mengdie_prompts_global.json';
        }
      } else {
        // Exporting a specific folder from global
        jsonString = promptService.exportPrompts(isGlobal: true, chatId: chatId, parentId: parentId);
        fileName = 'mengdie_prompts_global_folder.json';
      }
    } else {
      // Exporting from chat
      jsonString = promptService.exportPrompts(
          isGlobal: false,
          chatId: chatId,
          parentId: exportScope == 'folder' ? parentId : null);
      fileName = exportScope == 'folder'
          ? 'mengdie_prompts_chat_${chatId}_folder.json'
          : 'mengdie_prompts_chat_$chatId.json';
    }

    try {
      final String? path = await FilePicker.platform.saveFile(
        dialogTitle: '请选择保存位置',
        fileName: fileName,
        bytes: Uint8List.fromList(utf8.encode(jsonString)),
      );
      if (path != null) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('已成功导出到: $path')),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('导出已取消')),
        );
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('导出失败: $e')),
      );
    }
  }

  Future<void> _importPrompts(BuildContext context, int chatId) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final promptService = ref.read(promptServiceProvider.notifier);
    final isGlobal = _tabController.index == 1;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result == null || result.files.single.bytes == null) {
        scaffoldMessenger.showSnackBar(const SnackBar(content: Text('导入已取消')));
        return;
      }

      final String jsonString = utf8.decode(result.files.single.bytes!);
      bool success = false;
      final decodedJson = jsonDecode(jsonString);

      if (decodedJson is Map<String, dynamic> &&
          decodedJson.containsKey('prompts')) {
        if (!isGlobal) {
          final importPromptsOnly = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('导入全局提示词?'),
              content: const Text(
                  '这是一个全局提示词文件。您想只导入其中的提示词条目到当前聊天吗？\n(开关状态将被忽略)'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('取消')),
                TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('仅导入条目')),
              ],
            ),
          );
          if (importPromptsOnly == true) {
            final promptsJson = jsonEncode(decodedJson['prompts']);
            success = await promptService.importChatPrompts(promptsJson, chatId, parentId: _currentParentId);
          } else {
            scaffoldMessenger
                .showSnackBar(const SnackBar(content: Text('导入已取消')));
            return;
          }
        } else {
          if (decodedJson.containsKey('statuses')) {
            final importStatuses = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('检测到开关状态'),
                content: const Text(
                    '此文件包含全局开关状态，是否要一并导入？这可能会覆盖您当前的设置。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('仅导入条目'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('全部导入'),
                  ),
                ],
              ),
            );
            if (importStatuses == null) {
              scaffoldMessenger
                  .showSnackBar(const SnackBar(content: Text('导入已取消')));
              return;
            }
            success = await promptService.importGlobalPromptsWithStatuses(
                jsonString,
                importStatuses: importStatuses, parentId: _currentParentId);
          } else {
            final promptsJson = jsonEncode(decodedJson['prompts']);
            success = await promptService.importGlobalPrompts(promptsJson, parentId: _currentParentId);
          }
        }
      } else if (decodedJson is List) {
        if (isGlobal) {
          success = await promptService.importGlobalPrompts(jsonString, parentId: _currentParentId);
        } else {
          success = await promptService.importChatPrompts(jsonString, chatId, parentId: _currentParentId);
        }
      } else {
        success = false;
      }

      if (success) {
        scaffoldMessenger.showSnackBar(const SnackBar(content: Text('导入成功！')));
      } else {
        scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('导入失败，JSON格式可能不正确。')));
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('导入失败: $e')));
    }
  }

  void _showAddItemMenu(BuildContext context, int chatId) {
    final promptService = ref.read(promptServiceProvider.notifier);
    final isGlobal = _tabController.index == 1;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('新建条目'),
                onTap: () {
                  Navigator.pop(context);
                  if (isGlobal) {
                    promptService.addGlobalPromptItem(parentId: _currentParentId);
                  } else {
                    promptService.addChatPromptItem(chatId, parentId: _currentParentId);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder),
                title: const Text('新建文件夹'),
                onTap: () {
                  Navigator.pop(context);
                  if (isGlobal) {
                    promptService.addGlobalPromptFolder(parentId: _currentParentId);
                  } else {
                    promptService.addChatPromptFolder(chatId, parentId: _currentParentId);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeChatId = ref.watch(activeChatIdProvider);

    if (activeChatId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('提示词注入')),
        body: const Center(child: Text('没有活动的聊天。请先选择一个聊天。')),
      );
    }
    
    final promptState = ref.watch(promptServiceProvider);
    final allItems = _tabController.index == 0
        ? promptState.chatItems[activeChatId] ?? []
        : promptState.globalItems;

    final currentFolderName = (_currentParentId != null)
        ? allItems.firstWhereOrNull((i) => i.id == _currentParentId)?.keyword ?? '...'
        : '根目录';

    return Scaffold(
      appBar: AppBar(
        leading: (_currentFolderPath.length > 1)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _navigateBack,
              )
            : null,
        title: Text('提示词注入 - $currentFolderName'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddItemMenu(context, activeChatId),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'import') _importPrompts(context, activeChatId);
              if (value == 'export') _exportPrompts(context, activeChatId);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'import', child: Text('导入 (当前标签页)')),
              PopupMenuItem(value: 'export', child: Text('导出 (当前标签页)')),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kTextTabBarHeight),
          child: Stack(
            children: [
              TabBar(
                controller: _tabController,
                tabs: const [Tab(text: '聊天专属'), Tab(text: '全局')],
              ),
              Row(
                children: [
                  Expanded(
                    child: _buildTabDragTarget(
                      context: context,
                      isTargetGlobal: false, // This is the Chat tab
                      chatId: activeChatId,
                    ),
                  ),
                  Expanded(
                    child: _buildTabDragTarget(
                      context: context,
                      isTargetGlobal: true, // This is the Global tab
                      chatId: activeChatId,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PromptListView(
            key: ValueKey('chat_$_currentParentId'),
            chatId: activeChatId,
            isGlobalList: false,
            currentParentId: _chatFolderPath.last,
            onFolderTap: (folderId) => setState(() => _chatFolderPath.add(folderId)),
          ),
          _PromptListView(
            key: ValueKey('global_$_currentParentId'),
            chatId: activeChatId,
            isGlobalList: true,
            currentParentId: _globalFolderPath.last,
            onFolderTap: (folderId) => setState(() => _globalFolderPath.add(folderId)),
          ),
        ],
      ),
    );
  }

  Widget _buildTabDragTarget({
    required BuildContext context,
    required bool isTargetGlobal,
    required int chatId,
  }) {
    final promptService = ref.read(promptServiceProvider.notifier);
    return DragTarget<Map<String, dynamic>>(
      builder: (context, candidateData, rejectedData) {
        bool isDragOver = false;
        if (candidateData.isNotEmpty) {
          final bool? dragSourceIsGlobal =
              candidateData.first?['isGlobal'] as bool?;
          if (dragSourceIsGlobal != null) {
            isDragOver = dragSourceIsGlobal != isTargetGlobal;
          }
        }
        return GestureDetector(
          onTap: () {
            _tabController.index = isTargetGlobal ? 1 : 0;
          },
          child: Container(
            height: kTextTabBarHeight,
            color: isDragOver
                ? Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5)
                : Colors.transparent,
          ),
        );
      },
      onWillAccept: (data) {
        if (data == null) return false;
        final bool isDragSourceGlobal = data['isGlobal'] as bool;
        return isDragSourceGlobal != isTargetGlobal;
      },
      onAccept: (data) {
        final String itemId = data['id'] as String;
        final bool isSourceGlobal = data['isGlobal'] as bool;
        promptService.convertPromptType(
          chatId: chatId,
          itemId: itemId,
          isSourceGlobal: isSourceGlobal,
        );
      },
    );
  }
}

// ListView Widget
class _PromptListView extends ConsumerWidget {
  final int chatId;
  final bool isGlobalList;
  final String? currentParentId;
  final ValueChanged<String> onFolderTap;

  const _PromptListView({
    super.key,
    required this.chatId,
    required this.isGlobalList,
    required this.currentParentId,
    required this.onFolderTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promptService = ref.read(promptServiceProvider.notifier);
    final promptState = ref.watch(promptServiceProvider);

    final allItems = isGlobalList
        ? promptState.globalItems
        : promptState.chatItems[chatId] ?? [];
    final chatStatusMap = promptState.chatStatuses[chatId] ?? {};

    // Get the items for the current folder and apply chat-specific statuses if it's a global list.
    final itemsToShow = allItems
        .where((item) => item.parentId == currentParentId)
        .map((item) {
          if (isGlobalList && chatStatusMap.containsKey(item.id)) {
            // This global item has a specific status for this chat, so override it.
            return item.copyWith(status: chatStatusMap[item.id]);
          }
          return item;
        })
        .sortedBy<num>((item) => item.order)
        .toList();

    if (itemsToShow.isEmpty) {
      return DragTarget<Map<String, dynamic>>(
        builder: (context, candidateData, rejectedData) =>
            const Center(child: Text('此文件夹为空')),
        onAccept: (data) {
          final isGlobal = data['isGlobal'] as bool;
          if (isGlobal != isGlobalList) return; // Don't accept drops from other list type
          
          promptService.movePromptItem(
            chatId: chatId,
            isGlobal: isGlobalList,
            itemId: data['id'] as String,
            newParentId: currentParentId,
            newIndex: 0,
          );
        },
      );
    }
    
    return ListView.builder(
      itemCount: itemsToShow.length + 2,
      itemBuilder: (context, index) {
        // Top drop zone
        if (index == 0) {
          return DragTarget<Map<String, dynamic>>(
            builder: (context, candidateData, rejectedData) {
              final isForeign = candidateData.isNotEmpty && (candidateData.first?['isGlobal'] as bool? ?? isGlobalList) != isGlobalList;
              return Container(
                height: 40.0,
                width: double.infinity,
                alignment: Alignment.bottomCenter,
                child: candidateData.isNotEmpty && !isForeign
                    ? Container(
                        height: 2,
                        color: Theme.of(context).colorScheme.secondary,
                      )
                    : null,
              );
            },
            onWillAccept: (data) {
              if (data == null || (data['isGlobal'] as bool) != isGlobalList) return false;
              if (itemsToShow.isEmpty) return true;
              return itemsToShow.first.id != (data['id'] as String);
            },
            onAccept: (data) {
              promptService.movePromptItem(
                chatId: chatId,
                isGlobal: isGlobalList,
                itemId: data['id'] as String,
                newParentId: currentParentId,
                newIndex: 0,
              );
            },
          );
        }

        // Bottom drop zone
        if (index == itemsToShow.length + 1) {
          return DragTarget<Map<String, dynamic>>(
            builder: (context, candidateData, rejectedData) {
              final isForeign = candidateData.isNotEmpty && (candidateData.first?['isGlobal'] as bool? ?? isGlobalList) != isGlobalList;
              return Container(
                height: 60.0,
                width: double.infinity,
                decoration: candidateData.isNotEmpty && !isForeign
                    ? BoxDecoration(
                        border: Border(
                            top: BorderSide(
                                color: Theme.of(context).colorScheme.secondary,
                                width: 2)))
                    : null,
              );
            },
             onWillAccept: (data) => data != null && (data['isGlobal'] as bool) == isGlobalList,
            onAccept: (data) {
              promptService.movePromptItem(
                chatId: chatId,
                isGlobal: isGlobalList,
                itemId: data['id'] as String,
                newParentId: currentParentId,
                newIndex: itemsToShow.length,
              );
            },
          );
        }

        final item = itemsToShow[index - 1];

        final child = item.type == PromptItemType.folder
            ? _PromptFolderCard(
                item: item, chatId: chatId, onTap: () => onFolderTap(item.id))
            : _PromptItemCard(item: item, chatId: chatId);

        return LongPressDraggable<Map<String, dynamic>>(
          data: {'id': item.id, 'isGlobal': isGlobalList},
          feedback: Opacity(
            opacity: 0.7,
            child: Material(
              elevation: 4.0,
              child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width - 32),
                  child: child),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.4, child: child),
          onDragStarted: () => FocusScope.of(context).unfocus(),
          child: DragTarget<Map<String, dynamic>>(
            builder: (context, candidateData, rejectedData) {
              final isForeign = candidateData.isNotEmpty && (candidateData.first?['isGlobal'] as bool? ?? isGlobalList) != isGlobalList;
              return Container(
                decoration: candidateData.isNotEmpty && !isForeign
                    ? BoxDecoration(
                        border: Border(
                            top: BorderSide(
                                color: Theme.of(context).colorScheme.secondary,
                                width: 2)))
                    : null,
                child: child,
              );
            },
            onWillAccept: (data) {
              if (data == null) return false;
              final isGlobal = data['isGlobal'] as bool;
              final draggedId = data['id'] as String;
              return isGlobal == isGlobalList && draggedId != item.id;
            },
            onAccept: (data) {
              promptService.movePromptItem(
                chatId: chatId,
                isGlobal: isGlobalList,
                itemId: data['id'] as String,
                newParentId: currentParentId,
                newIndex: index - 1, // Adjusted index
              );
            },
          ),
        );
      },
    );
  }
}

// Folder Card Widget
class _PromptFolderCard extends ConsumerWidget {
  final PromptItem item;
  final int chatId;
  final VoidCallback onTap;

  const _PromptFolderCard({
    required this.item,
    required this.chatId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promptService = ref.read(promptServiceProvider.notifier);
    
    return DragTarget<Map<String, dynamic>>(
      builder: (context, candidateData, rejectedData) {
        final isForeign = candidateData.isNotEmpty && (candidateData.first?['isGlobal'] as bool? ?? item.isGlobal) != item.isGlobal;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: candidateData.isNotEmpty && !isForeign ? Theme.of(context).colorScheme.secondaryContainer : null,
          child: ListTile(
            leading: Icon(Icons.folder, color: Theme.of(context).colorScheme.secondary),
            title: Text(item.keyword, style: const TextStyle(fontWeight: FontWeight.bold)),
            onTap: onTap,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: item.status != PromptItemStatus.off,
                  onChanged: (value) {
                    promptService.updateStatusForChat(chatId, item.id, value ? PromptItemStatus.on : PromptItemStatus.off);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                     showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('确认删除'),
                        content: const Text('您确定要删除此文件夹及其所有内容吗？'),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
                          TextButton(
                            onPressed: () {
                              promptService.deletePromptItem(item.id, item.isGlobal, chatId);
                              Navigator.of(context).pop();
                            },
                            child: const Text('删除'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
      onWillAccept: (data) {
        if (data == null) return false;
        final isGlobal = data['isGlobal'] as bool;
        final draggedId = data['id'] as String;

        if (isGlobal != item.isGlobal) return false; // Must be from the same list type
        if (draggedId == item.id) return false;

        final allItems = item.isGlobal ? ref.read(promptServiceProvider).globalItems : (ref.read(promptServiceProvider).chatItems[chatId] ?? []);
        String? currentParentId = item.id;
        while(currentParentId != null) {
          if (currentParentId == draggedId) return false; // Prevent nesting folder in itself
          currentParentId = allItems.firstWhereOrNull((i) => i.id == currentParentId)?.parentId;
        }
        return true;
      },
      onAccept: (data) {
        promptService.movePromptItem(
          chatId: chatId,
          isGlobal: item.isGlobal,
          itemId: data['id'] as String,
          newParentId: item.id,
          newIndex: 9999,
        );
      },
    );
  }
}

// Item Card Widget (Simplified)
class _PromptItemCard extends ConsumerWidget {
  final PromptItem item;
  final int chatId;

  const _PromptItemCard({
    required this.item,
    required this.chatId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promptService = ref.read(promptServiceProvider.notifier);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: const Icon(Icons.description_outlined),
        title: Text(
          item.keyword.isNotEmpty ? item.keyword : '(无关键词)',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '状态: ${item.status.name} | ${item.text}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () {
          context.go(
            '/chat/prompt-editor/item/${item.id}?chatId=$chatId&isGlobal=${item.isGlobal}',
          );
        },
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('确认删除'),
                content: const Text('您确定要删除此提示词吗？'),
                actions: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
                  TextButton(
                    onPressed: () {
                      promptService.deletePromptItem(item.id, item.isGlobal, chatId);
                      Navigator.of(context).pop();
                    },
                    child: const Text('删除'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

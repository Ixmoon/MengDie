import 'dart:convert';
import 'dart:ui'; // For lerpDouble

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/chat_state_providers.dart';
import '../../app/services/prompt_service.dart';
import '../../domain/enums.dart';
import '../../domain/models/prompt_item.dart';
import '../widgets/widget_utils.dart';

class PromptEditorScreen extends ConsumerStatefulWidget {
  const PromptEditorScreen({super.key});

  @override
  ConsumerState<PromptEditorScreen> createState() => _PromptEditorScreenState();
}

class _PromptEditorScreenState extends ConsumerState<PromptEditorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _exportPrompts(BuildContext context, int chatId) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final promptService = ref.read(promptServiceProvider.notifier);
    final isGlobal = _tabController.index == 1;

    String jsonString;
    String fileName;

    if (isGlobal) {
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
        jsonString = promptService.exportGlobalPrompts();
        fileName = 'mengdie_prompts_global.json';
      }
    } else {
      jsonString = promptService.exportChatPrompts(chatId);
      fileName = 'mengdie_prompts_chat_$chatId.json';
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

      if (isGlobal) {
        final Map<String, dynamic> decodedJson = jsonDecode(jsonString);
        if (decodedJson.containsKey('prompts') &&
            decodedJson.containsKey('statuses')) {
          final importStatuses = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('检测到开关状态'),
              content: const Text('此文件包含全局开关状态，是否要一并导入？这可能会覆盖您当前的设置。'),
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
            scaffoldMessenger.showSnackBar(const SnackBar(content: Text('导入已取消')));
            return;
          }
          success = await promptService.importGlobalPromptsWithStatuses(jsonString,
              importStatuses: importStatuses);
        } else {
          // Old format or items_only format
          success = await promptService.importGlobalPrompts(jsonString);
        }
      } else {
        success = await promptService.importChatPrompts(jsonString, chatId);
      }

      if (success) {
        scaffoldMessenger.showSnackBar(const SnackBar(content: Text('导入成功！')));
      } else {
        scaffoldMessenger
            .showSnackBar(const SnackBar(content: Text('导入失败，JSON格式可能不正确。')));
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('导入失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final promptService = ref.read(promptServiceProvider.notifier);
    final activeChatId = ref.watch(activeChatIdProvider);

    if (activeChatId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Prompt Injection')),
        body: const Center(child: Text('没有活动的聊天。请先选择一个聊天。')),
      );
    }

    ref.watch(promptServiceProvider);
    final allPrompts = promptService.getItemsForChat(activeChatId);
    final chatPrompts = allPrompts.where((p) => !p.isGlobal).toList();
    final globalPrompts = allPrompts.where((p) => p.isGlobal).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prompt Injection'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              if (_tabController.index == 0) {
                promptService.addChatPromptItem(activeChatId);
              } else {
                promptService.addGlobalPromptItem();
              }
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'import') {
                _importPrompts(context, activeChatId);
              } else if (value == 'export') {
                _exportPrompts(context, activeChatId);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'import',
                child: Text('导入 (当前标签页)'),
              ),
              const PopupMenuItem<String>(
                value: 'export',
                child: Text('导出 (当前标签页)'),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '聊天专属'),
            Tab(text: '全局'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PromptListView(
            key: const ValueKey('chat_prompts'),
            items: chatPrompts,
            chatId: activeChatId,
            isGlobalList: false,
          ),
          _PromptListView(
            key: const ValueKey('global_prompts'),
            items: globalPrompts,
            chatId: activeChatId,
            isGlobalList: true,
          ),
        ],
      ),
    );
  }
}

class _PromptListView extends ConsumerWidget {
  final List<PromptItem> items;
  final int chatId;
  final bool isGlobalList;

  const _PromptListView({
    super.key,
    required this.items,
    required this.chatId,
    required this.isGlobalList,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promptService = ref.read(promptServiceProvider.notifier);

    if (items.isEmpty) {
      return Center(
        child: Text('没有${isGlobalList ? "全局" : "聊天专属"}条目.'),
      );
    }

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _PromptItemCard(
          key: ValueKey(items[index].id),
          item: items[index],
          chatId: chatId,
          index: index,
        );
      },
      onReorder: (oldIndex, newIndex) {
        if (isGlobalList) {
          promptService.reorderGlobalPromptItem(oldIndex, newIndex);
        } else {
          promptService.reorderChatPromptItem(chatId, oldIndex, newIndex);
        }
      },
      onReorderStart: (_) {
        FocusScope.of(context).unfocus();
      },
      proxyDecorator: (Widget child, int index, Animation<double> animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (BuildContext context, Widget? child) {
            final double animValue =
                Curves.easeInOut.transform(animation.value);
            const double elevation = 0;
            final double scale = lerpDouble(1, 1.02, animValue)!;
            return Transform.scale(
              scale: scale,
              child: Material(
                elevation: elevation,
                color: Colors.transparent,
                child: child,
              ),
            );
          },
          child: child,
        );
      },
    );
  }
}

class _PromptItemCard extends ConsumerStatefulWidget {
  final PromptItem item;
  final int chatId;
  final int index;

  const _PromptItemCard({
    super.key,
    required this.item,
    required this.chatId,
    required this.index,
  });

  @override
  ConsumerState<_PromptItemCard> createState() => _PromptItemCardState();
}

class _PromptItemCardState extends ConsumerState<_PromptItemCard> {
  late final TextEditingController _keywordController;
  late final TextEditingController _textController;
  late final TextEditingController _positionController;
  late final TextEditingController _matchCountController;
  late final TextEditingController _injectionTagController;

  @override
  void initState() {
    super.initState();
    _keywordController = TextEditingController(text: widget.item.keyword);
    _textController = TextEditingController(text: widget.item.text);
    _positionController = TextEditingController(
      text: widget.item.injectionPosition.toString(),
    );
    _matchCountController = TextEditingController(
      text: widget.item.matchMessageCount.toString(),
    );
    _injectionTagController =
        TextEditingController(text: widget.item.injectionTag);
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _textController.dispose();
    _positionController.dispose();
    _matchCountController.dispose();
    _injectionTagController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _PromptItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.keyword != oldWidget.item.keyword &&
        _keywordController.text != widget.item.keyword) {
      _keywordController.text = widget.item.keyword;
    }
    if (widget.item.text != oldWidget.item.text &&
        _textController.text != widget.item.text) {
      _textController.text = widget.item.text;
    }
    final newPosition = widget.item.injectionPosition.toString();
    if (widget.item.injectionPosition != oldWidget.item.injectionPosition &&
        _positionController.text != newPosition) {
      _positionController.text = newPosition;
    }
    final newMatchCount = widget.item.matchMessageCount.toString();
    if (widget.item.matchMessageCount != oldWidget.item.matchMessageCount &&
        _matchCountController.text != newMatchCount) {
      _matchCountController.text = newMatchCount;
    }
    if (widget.item.injectionTag != oldWidget.item.injectionTag &&
        _injectionTagController.text != widget.item.injectionTag) {
      _injectionTagController.text = widget.item.injectionTag;
    }
  }

  @override
  Widget build(BuildContext context) {
    final promptService = ref.read(promptServiceProvider.notifier);
    final item = widget.item;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IntrinsicWidth(
                      child: DropdownButtonFormField<PromptItemStatus>(
                        value: item.status,
                        decoration: const InputDecoration(
                          labelText: '状态',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        icon: const SizedBox.shrink(),
                        onChanged: (PromptItemStatus? newValue) {
                          if (newValue != null) {
                            promptService.updateStatusForChat(
                              widget.chatId,
                              item.id,
                              newValue,
                            );
                          }
                        },
                        items: PromptItemStatus.values
                            .map((value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value.toString().split('.').last),
                                ))
                            .toList(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _positionController,
                        decoration: const InputDecoration(
                          labelText: '注入位置',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        onChanged: (value) {
                          final newPosition = int.tryParse(value) ?? 2;
                          promptService.updatePromptItem(
                            item.copyWith(injectionPosition: newPosition),
                            widget.chatId,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _matchCountController,
                        decoration: const InputDecoration(
                          labelText: '匹配数',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        onChanged: (value) {
                          final newCount = int.tryParse(value) ?? 6;
                          promptService.updatePromptItem(
                            item.copyWith(matchMessageCount: newCount),
                            widget.chatId,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('确认删除'),
                              content: const Text('您确定要删除此提示词吗？'),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('取消'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    promptService.deletePromptItem(
                                        item.id, item.isGlobal, widget.chatId);
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('删除'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IntrinsicWidth(
                      child: DropdownButtonFormField<MessageRole>(
                        value: item.injectionRole,
                        decoration: const InputDecoration(
                          labelText: '注入角色',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        icon: const SizedBox.shrink(),
                        items: MessageRole.values
                            .map((role) => DropdownMenuItem(
                                  value: role,
                                  child: Text(role.toString().split('.').last),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            promptService.updatePromptItem(
                              item.copyWith(injectionRole: value),
                              widget.chatId,
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _injectionTagController,
                        decoration: const InputDecoration(
                          labelText: 'XML标签',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        onChanged: (value) {
                          promptService.updatePromptItem(
                            item.copyWith(injectionTag: value),
                            widget.chatId,
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                    controller: _keywordController,
                    decoration: InputDecoration(
                      labelText: '关键词',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.fullscreen),
                        tooltip: '全屏编辑',
                        onPressed: () async {
                          final newText = await showFullScreenTextEditor(
                            context,
                            initialText: item.keyword,
                            chatId: widget.chatId,
                            title: '编辑关键词',
                            initialLanguage: 'text',
                          );
                          if (newText != null && newText != item.keyword) {
                            promptService.updatePromptItem(
                              item.copyWith(keyword: newText),
                              widget.chatId,
                            );
                          }
                        },
                      ),
                    ),
                    onChanged: (value) {
                      promptService.updatePromptItem(
                        item.copyWith(keyword: value),
                        widget.chatId,
                      );
                    }),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _textController,
                  decoration: InputDecoration(
                    labelText: '注入文本',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.fullscreen),
                      tooltip: '全屏编辑',
                      onPressed: () async {
                        final newText = await showFullScreenTextEditor(
                          context,
                          initialText: item.text,
                          chatId: widget.chatId,
                          title: '编辑注入文本',
                          initialLanguage: 'markdown',
                        );
                        if (newText != null && newText != item.text) {
                          promptService.updatePromptItem(
                            item.copyWith(text: newText),
                            widget.chatId,
                          );
                        }
                      },
                    ),
                  ),
                  onChanged: (value) {
                    promptService.updatePromptItem(
                        item.copyWith(text: value), widget.chatId);
                  },
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: ReorderableDragStartListener(
              index: widget.index,
              child: ClipPath(
                clipper: TriangleClipper(),
                child: Material(
                  color: Theme.of(context)
                      .colorScheme
                      .primary, // 使用主题主色作为拖动手柄颜色
                  child: InkWell(
                    onTap: () {}, // Required for InkWell
                    child: const SizedBox(
                      width: 24, // 调整大小以适应三角形
                      height: 24,
                      child: Center(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

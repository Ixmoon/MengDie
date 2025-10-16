import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/services/prompt_service.dart';
import '../../domain/enums.dart';
import '../../domain/models/prompt_item.dart';
import '../widgets/widget_utils.dart';

class PromptItemEditorScreen extends ConsumerStatefulWidget {
  final String itemId;
  final int chatId;
  final bool isGlobal;

  const PromptItemEditorScreen({
    super.key,
    required this.itemId,
    required this.chatId,
    required this.isGlobal,
  });

  @override
  ConsumerState<PromptItemEditorScreen> createState() =>
      _PromptItemEditorScreenState();
}

class _PromptItemEditorScreenState
    extends ConsumerState<PromptItemEditorScreen> {
  late final TextEditingController _keywordController;
  late final TextEditingController _textController;
  late final TextEditingController _positionController;
  late final TextEditingController _matchCountController;
  late final TextEditingController _injectionTagController;

  @override
  void initState() {
    super.initState();
    final item = _getPromptItem();
    _keywordController = TextEditingController(text: item?.keyword ?? '');
    _textController = TextEditingController(text: item?.text ?? '');
    _positionController =
        TextEditingController(text: item?.injectionPosition.toString() ?? '2');
    _matchCountController =
        TextEditingController(text: item?.matchMessageCount.toString() ?? '6');
    _injectionTagController =
        TextEditingController(text: item?.injectionTag ?? '');
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
  
  PromptItem? _getPromptItem() {
    final promptState = ref.read(promptServiceProvider);
    final allItems = widget.isGlobal
        ? promptState.globalItems
        : promptState.chatItems[widget.chatId] ?? [];
    return allItems.firstWhereOrNull((i) => i.id == widget.itemId);
  }

  void _updateControllers(PromptItem item) {
    if (_keywordController.text != item.keyword) {
      _keywordController.text = item.keyword;
    }
    if (_textController.text != item.text) {
      _textController.text = item.text;
    }
    if (_positionController.text != item.injectionPosition.toString()) {
      _positionController.text = item.injectionPosition.toString();
    }
    if (_matchCountController.text != item.matchMessageCount.toString()) {
      _matchCountController.text = item.matchMessageCount.toString();
    }
    if (_injectionTagController.text != item.injectionTag) {
      _injectionTagController.text = item.injectionTag;
    }
  }

  @override
  Widget build(BuildContext context) {
    final promptService = ref.read(promptServiceProvider.notifier);
    final item = ref.watch(promptServiceProvider.select((state) {
      final allItems = widget.isGlobal
          ? state.globalItems
          : state.chatItems[widget.chatId] ?? [];
      return allItems.firstWhereOrNull((i) => i.id == widget.itemId);
    }));

    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('编辑条目')),
        body: const Center(child: Text('条目未找到或已被删除。')),
      );
    }
    
    // Update controllers if the item from provider has changed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateControllers(item);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑条目'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Row 1: Status, Position, Match Count
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<PromptItemStatus>(
                  value: item.status,
                  decoration: const InputDecoration(
                    labelText: '状态',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (newValue) {
                    if (newValue != null) {
                      promptService.updateStatusForChat(
                          widget.chatId, item.id, newValue);
                    }
                  },
                  items: PromptItemStatus.values
                      .map((v) => DropdownMenuItem(value: v, child: Text(v.name)))
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
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) {
                    final newPosition = int.tryParse(value) ?? 2;
                    promptService.updatePromptItem(
                        item.copyWith(injectionPosition: newPosition),
                        widget.chatId);
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
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) {
                    final newCount = int.tryParse(value) ?? 6;
                    promptService.updatePromptItem(
                        item.copyWith(matchMessageCount: newCount),
                        widget.chatId);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Row 2: Role, Tag
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<MessageRole>(
                  value: item.injectionRole,
                  decoration: const InputDecoration(
                    labelText: '注入角色',
                    border: OutlineInputBorder(),
                  ),
                  items: MessageRole.values
                      .map((r) => DropdownMenuItem(value: r, child: Text(r.name)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      promptService.updatePromptItem(
                          item.copyWith(injectionRole: value), widget.chatId);
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
                  ),
                  onChanged: (value) {
                    promptService.updatePromptItem(
                        item.copyWith(injectionTag: value), widget.chatId);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Row 3: Critical Match & Keyword
          TextFormField(
            controller: _keywordController,
            decoration: InputDecoration(
              labelText: '关键词',
              border: const OutlineInputBorder(),
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
                        item.copyWith(keyword: newText), widget.chatId);
                  }
                },
              ),
            ),
            onChanged: (value) {
              promptService.updatePromptItem(
                  item.copyWith(keyword: value), widget.chatId);
            },
          ),
          if (item.status == PromptItemStatus.match) ...[
            const SizedBox(height: 8),
            CheckboxListTile(
              title: const Text('全部匹配'),
              subtitle: const Text('“关键词”中所有由逗号分隔的词都必须出现才会触发注入。'),
              value: item.critical,
              onChanged: (newValue) {
                if (newValue != null) {
                  promptService.updatePromptItem(
                      item.copyWith(critical: newValue), widget.chatId);
                }
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
          const SizedBox(height: 16),
          // Row 4: Injection Text
          TextFormField(
            controller: _textController,
            decoration: InputDecoration(
              labelText: '注入文本',
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
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
                        item.copyWith(text: newText), widget.chatId);
                  }
                },
              ),
            ),
            onChanged: (value) {
              promptService.updatePromptItem(
                  item.copyWith(text: value), widget.chatId);
            },
            maxLines: 8,
          ),
        ],
      ),
    );
  }
}
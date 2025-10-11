import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/chat_state_providers.dart';
import '../../app/services/prompt_service.dart';
import '../../domain/enums.dart';
import '../../domain/models/prompt_item.dart';
import '../widgets/widget_utils.dart';

class PromptEditorScreen extends ConsumerWidget {
  const PromptEditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promptService = ref.read(promptServiceProvider.notifier);
    final activeChatId = ref.watch(activeChatIdProvider);

    if (activeChatId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Prompt Injection')),
        body: const Center(child: Text('没有活动的聊天。请先选择一个聊天。')),
      );
    }

    // Watch the provider to trigger rebuilds when items are added/deleted
    ref.watch(promptServiceProvider);
    final promptsForChat = promptService.getItemsForChat(activeChatId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prompt Injection'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: promptService.addPromptItem,
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: promptsForChat.length,
        itemBuilder: (context, index) {
          final item = promptsForChat[index];
          // Use a stateful widget for each item to manage controllers and focus
          return _PromptItemCard(
            key: ValueKey(item.id),
            item: item,
            chatId: activeChatId,
          );
        },
      ),
    );
  }
}

class _PromptItemCard extends ConsumerStatefulWidget {
  final PromptItem item;
  final int chatId;

  const _PromptItemCard({super.key, required this.item, required this.chatId});

  @override
  ConsumerState<_PromptItemCard> createState() => _PromptItemCardState();
}

class _PromptItemCardState extends ConsumerState<_PromptItemCard> {
  late final TextEditingController _keywordController;
  late final TextEditingController _textController;
  late final TextEditingController _positionController;
  late final TextEditingController _matchCountController;

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
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _textController.dispose();
    _positionController.dispose();
    _matchCountController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _PromptItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync controller text if the underlying model changes from the provider,
    // but only if the text is actually different, to avoid disrupting user input.
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
  }

  @override
  Widget build(BuildContext context) {
    final promptService = ref.read(promptServiceProvider.notifier);
    final item = widget.item;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Dropdown
                DropdownButton<PromptItemStatus>(
                  value: item.status,
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
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.toString().split('.').last),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(width: 8),
                // Role Dropdown
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<MessageRole>(
                    value: item.injectionRole,
                    decoration: const InputDecoration(
                      labelText: '注入角色',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: MessageRole.values
                        .map(
                          (role) => DropdownMenuItem(
                            value: role,
                            child: Text(role.toString().split('.').last),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        promptService.updatePromptItem(
                          item.copyWith(injectionRole: value),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Position Input
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _positionController,
                    decoration: const InputDecoration(
                      labelText: '位置',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) {
                      final newPosition = int.tryParse(value) ?? 2;
                      promptService.updatePromptItem(
                        item.copyWith(injectionPosition: newPosition),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Match Count Input
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _matchCountController,
                    decoration: const InputDecoration(
                      labelText: '匹配数',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) {
                      final newCount = int.tryParse(value) ?? 6;
                      promptService.updatePromptItem(
                        item.copyWith(matchMessageCount: newCount),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _keywordController,
                    decoration: InputDecoration(
                      labelText: '关键词 (逗号隔开)',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                    onChanged: (value) {
                      promptService.updatePromptItem(
                        item.copyWith(keyword: value),
                      );
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => promptService.deletePromptItem(item.id),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _textController,
              decoration: InputDecoration(
                labelText: '注入的文本',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.fullscreen),
                  tooltip: '全屏编辑',
                  onPressed: () async {
                    final newText = await showFullScreenTextEditor(
                      context,
                      initialText: item.text,
                      title: '编辑注入文本',
                      initialLanguage: 'markdown',
                    );
                    if (newText != null && newText != item.text) {
                      promptService.updatePromptItem(
                        item.copyWith(text: newText),
                      );
                    }
                  },
                ),
              ),
              onChanged: (value) {
                promptService.updatePromptItem(item.copyWith(text: value));
              },
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }
}

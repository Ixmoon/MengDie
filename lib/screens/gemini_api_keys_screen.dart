import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/api_key_provider.dart';

class GeminiApiKeysScreen extends ConsumerWidget {
  const GeminiApiKeysScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiKeyState = ref.watch(apiKeyNotifierProvider);
    final apiKeyNotifier = ref.read(apiKeyNotifierProvider.notifier);
    final keys = apiKeyState.geminiApiKeys;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
          shadows: <Shadow>[
            Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 1.0)
          ],
        ),
        title: Text(
          'Gemini API Keys',
          style: TextStyle(
            shadows: <Shadow>[
              Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 1.0)
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: '清空所有密钥',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('确认清空'),
                  content: const Text('确定要删除所有 Gemini API Keys 吗？此操作不可撤销。'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
                    TextButton(
                      onPressed: () {
                        ref.read(apiKeyNotifierProvider.notifier).clearAllGeminiKeys();
                        Navigator.pop(context);
                      },
                      child: const Text('清空', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: keys.isEmpty
                ? const Center(child: Text('没有找到 Gemini API Keys。'))
                : ListView.builder(
                    itemCount: keys.length,
                    itemBuilder: (context, index) {
                      final key = keys[index];
                      return ListTile(
                        title: Text('****${key.substring(key.length - 4)}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () => apiKeyNotifier.deleteGeminiKey(key),
                        ),
                      );
                    },
                  ),
          ),
          _AddKeySection(),
        ],
      ),
    );
  }
}

class _AddKeySection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AddKeySection> createState() => _AddKeySectionState();
}

class _AddKeySectionState extends ConsumerState<_AddKeySection> {
  final _controller = TextEditingController();

  void _addKey() {
    final key = _controller.text.trim();
    if (key.isNotEmpty) {
      ref.read(apiKeyNotifierProvider.notifier).addGeminiKey(key);
      _controller.clear();
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: '添加新的 Gemini API Key',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _addKey(),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addKey,
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
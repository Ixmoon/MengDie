import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/api_key_provider.dart'; // 导入 API Key Provider

// 新的 Gemini API Keys 管理屏幕

class GeminiApiKeysScreen extends ConsumerWidget {
  const GeminiApiKeysScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiKeyState = ref.watch(apiKeyNotifierProvider);
    final apiKeyNotifier = ref.read(apiKeyNotifierProvider.notifier);
    final apiKeyController = TextEditingController();

    // 在 Widget build 方法结束后释放 Controller
    // WidgetsBinding.instance.addPostFrameCallback((_) => apiKeyController.dispose()); // 示例, StatefulWidget 中更常见

    return Scaffold(
      appBar: AppBar(title: const Text('Gemini API Keys')), // const
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Padding(
          padding: const EdgeInsets.all(16.0), // const
          child: ListView(
            children: [
              Text('管理您的 Google AI API 密钥', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 15), // const
              TextField(
                controller: apiKeyController,
                decoration: InputDecoration(
                  labelText: '添加新的 API Key',
                  hintText: '粘贴您的 Gemini API Key (可用逗号分隔多个)',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add_circle_outline), // const
                    tooltip: '添加 Key',
                    onPressed: () {
                      apiKeyNotifier.addKeys(apiKeyController.text);
                      apiKeyController.clear();
                      FocusScope.of(context).unfocus();
                    },
                  ),
                  border: const OutlineInputBorder(), // const
                ),
                obscureText: true,
                onSubmitted: (value) {
                  apiKeyNotifier.addKeys(value);
                  apiKeyController.clear();
                  FocusScope.of(context).unfocus();
                },
              ),
              const SizedBox(height: 10), // const
              if (apiKeyState.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 5.0, bottom: 10.0), // const
                  child: Text("提示: ${apiKeyState.error}", style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              const SizedBox(height: 20), // const
              Text('已保存的 Keys (${apiKeyState.keys.length}):', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 5), // const
              if (apiKeyState.keys.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0), // const
                  child: Text('尚未添加任何 Gemini API Key。', style: Theme.of(context).textTheme.bodySmall),
                ),
              if (apiKeyState.keys.isNotEmpty)
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(), // const
                  itemCount: apiKeyState.keys.length,
                  itemBuilder: (context, index) {
                    final key = apiKeyState.keys[index];
                    final displayKey = key.length > 8 ? '${key.substring(0, 4)}...${key.substring(key.length - 4)}' : '...';
                    return ListTile(
                      leading: const Icon(Icons.vpn_key_outlined, size: 18), // const
                      title: Text(displayKey, style: const TextStyle(fontFamily: 'monospace')), // const
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20), // const
                        tooltip: '移除 Key',
                        onPressed: () => apiKeyNotifier.removeKey(key),
                      ),
                      dense: true,
                    );
                  },
                ),
              const Divider(height: 30), // const
              // “一键清空”按钮
              if (apiKeyState.keys.isNotEmpty) // 仅当有 Key 时显示清空按钮
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0), // const
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delete_sweep_outlined), // const
                    label: const Text('清空所有 Gemini API Keys'), // const
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('确认清空'), // const
                          content: const Text('您确定要删除所有已保存的 Gemini API Keys 吗？此操作无法撤销。'), // const
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(dialogContext).pop(false),
                              child: const Text('取消'), // const
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(dialogContext).pop(true),
                              child: Text('全部清空', style: TextStyle(color: Theme.of(context).colorScheme.error)), // TextStyle can be const if color is const
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await apiKeyNotifier.clearAllKeys();
                        // 可以在这里添加一个提示，例如 SnackBar
                        if (context.mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('所有 Gemini API Keys 已清空'), backgroundColor: Colors.green),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.errorContainer,
                      foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart'; // For generating unique IDs

// import '../models/embedded_models.dart'; // OpenAIAPIConfig - Replaced
import '../data/database/drift/models/drift_openai_api_config.dart'; // Import DriftOpenAIAPIConfig
import '../providers/api_key_provider.dart'; // ApiKeyNotifier

// 本文件包含管理 OpenAI API 配置的屏幕界面。

class OpenAIAPIConfigsScreen extends ConsumerWidget {
  const OpenAIAPIConfigsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiKeyState = ref.watch(apiKeyNotifierProvider);
    final openAIConfigs = apiKeyState.openAIConfigs;
    // final apiKeyNotifier = ref.read(apiKeyNotifierProvider.notifier); // Kept for actions

    return Scaffold(
      appBar: AppBar(
        title: const Text('OpenAI API 配置'), // const
      ),
      body: Column(
        children: [
          if (apiKeyState.error != null && apiKeyState.error!.contains("OpenAI"))
            Padding(
              padding: const EdgeInsets.all(8.0), // const
              child: Text(
                apiKeyState.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: openAIConfigs.isEmpty
                ? const Center(child: Text('未添加任何 OpenAI API 配置。')) // const
                : ListView.builder(
                    itemCount: openAIConfigs.length,
                    itemBuilder: (context, index) {
                      final config = openAIConfigs[index];
                      return ListTile(
                        leading: const Icon(Icons.settings_ethernet_rounded), // const
                        title: Text(config.name),
                        subtitle: Text(
                            'URL: ${config.baseUrl}\nModel: ${config.modelName}\nID: ${config.id?.substring(0, 8) ?? "N/A"}...'),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined), // const
                              tooltip: '编辑配置',
                              onPressed: () {
                                _showEditOpenAIConfigDialog(context, ref, existingConfig: config);
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error), // Icon can be const if color is const
                              tooltip: '删除配置',
                              onPressed: () => _confirmDeleteConfig(context, ref, config),
                            ),
                          ],
                        ),
                        onTap: () {
                           _showEditOpenAIConfigDialog(context, ref, existingConfig: config);
                        }
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded), // const
        label: const Text('添加配置'), // const
        onPressed: () {
          _showEditOpenAIConfigDialog(context, ref);
        },
      ),
    );
  }

  void _confirmDeleteConfig(BuildContext context, WidgetRef ref, DriftOpenAIAPIConfig config) { // Use DriftOpenAIAPIConfig
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('确认删除'), // const
          content: Text('您确定要删除配置 "${config.name}" 吗？此操作无法撤销。'),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'), // const
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('删除'), // const
              onPressed: () {
                ref.read(apiKeyNotifierProvider.notifier).deleteOpenAIConfig(config.id); // id is non-nullable in DriftOpenAIAPIConfig
                Navigator.of(dialogContext).pop();
                 // Show a snackbar or some feedback
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('配置 "${config.name}" 已删除。')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _showEditOpenAIConfigDialog(BuildContext context, WidgetRef ref, {DriftOpenAIAPIConfig? existingConfig}) { // Use DriftOpenAIAPIConfig
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: existingConfig?.name ?? '');
    final baseUrlController = TextEditingController(text: existingConfig?.baseUrl ?? 'https://api.openai.com/v1');
    final apiKeyController = TextEditingController(text: existingConfig?.apiKey ?? '');
    final modelNameController = TextEditingController(text: existingConfig?.modelName ?? 'gpt-3.5-turbo');
    
    final bool isEditing = existingConfig != null;
    final String dialogTitle = isEditing ? '编辑 OpenAI 配置' : '添加 OpenAI 配置';
    final String saveButtonText = isEditing ? '保存更改' : '添加配置';

    showDialog(
      context: context,
      barrierDismissible: false, // User must tap button!
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(dialogTitle),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: '配置名称*', hintText: '例如：我的本地大模型'), // const
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '配置名称不能为空。';
                        // Removed extraneous German text: Einen validen Namen eingeben.
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10), // const
                  TextFormField(
                    controller: baseUrlController,
                    decoration: const InputDecoration(labelText: 'Base URL*', hintText: '例如：https://api.your-llm.com/v1'), // const
                     validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Base URL 不能为空。';
                      }
                      // Corrected null check for Uri.tryParse(...).isAbsolute
                      if (!(Uri.tryParse(value.trim())?.isAbsolute ?? false)) {
                        return '请输入有效的 URL。';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10), // const
                  TextFormField(
                    controller: apiKeyController,
                    decoration: const InputDecoration(labelText: 'API Key*', hintText: '您的 API 密钥'), // const
                    obscureText: true,
                     validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'API Key 不能为空。';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10), // const
                  TextFormField(
                    controller: modelNameController,
                    decoration: const InputDecoration(labelText: '模型名称*', hintText: '例如：gpt-4, llama-7b-chat'), // const
                     validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '模型名称不能为空。';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'), // const
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: Text(saveButtonText), // Text can be const if text is const
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  // Use the constructor to create the config object
                  final config = DriftOpenAIAPIConfig( // Use DriftOpenAIAPIConfig
                    id: existingConfig?.id ?? const Uuid().v4(), // Drift model handles ID generation if not provided
                    name: nameController.text.trim(),
                    baseUrl: baseUrlController.text.trim(),
                    apiKey: apiKeyController.text.trim(), 
                    modelName: modelNameController.text.trim(),
                  );
                  
                  if (isEditing) {
                    ref.read(apiKeyNotifierProvider.notifier).updateOpenAIConfig(config);
                  } else {
                    ref.read(apiKeyNotifierProvider.notifier).addOpenAIConfig(config);
                  }
                  Navigator.of(dialogContext).pop();
                   ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('配置 "${config.name}" 已${isEditing ? "更新" : "添加"}。')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}

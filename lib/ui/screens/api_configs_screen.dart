import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/api_config.dart';
import '../../domain/enums.dart';
import '../../app/providers/api_key_provider.dart';
import '../../app/providers/openai_models_provider.dart';

class ApiConfigsScreen extends ConsumerWidget {
  const ApiConfigsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiKeyState = ref.watch(apiKeyNotifierProvider);
    final apiConfigs = apiKeyState.apiConfigs;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
          shadows: <Shadow>[
            Shadow(color: Colors.black.withAlpha((255 * 0.5).round()), blurRadius: 1.0)
          ],
        ),
        title: Text(
          'API 配置管理',
          style: TextStyle(
            shadows: <Shadow>[
              Shadow(color: Colors.black.withAlpha((255 * 0.5).round()), blurRadius: 1.0)
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '添加配置',
            onPressed: () => _showApiConfigDialog(context, ref),
          ),
        ],
      ),
      body: apiConfigs.isEmpty
          ? const Center(child: Text('没有找到 API 配置。\n点击右上角的 + 号添加一个。'))
          : ListView.builder(
              itemCount: apiConfigs.length,
              itemBuilder: (context, index) {
                final config = apiConfigs[index];
                return ListTile(
                  title: Text(config.name),
                  subtitle: Text('${config.apiType.name} - ${config.model}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        tooltip: '编辑',
                        onPressed: () => _showApiConfigDialog(context, ref, existingConfig: config),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        tooltip: '删除',
                        onPressed: () => _confirmDelete(context, ref, config),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, ApiConfig config) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除配置 "${config.name}" 吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () {
              ref.read(apiKeyNotifierProvider.notifier).deleteConfig(config.id);
              Navigator.pop(context);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showApiConfigDialog(BuildContext context, WidgetRef ref, {ApiConfig? existingConfig}) {
    final isNew = existingConfig == null;
    final nameController = TextEditingController(text: existingConfig?.name ?? '');
    final modelController = TextEditingController(text: existingConfig?.model ?? '');
    final apiKeyController = TextEditingController(text: existingConfig?.apiKey ?? '');
    final baseUrlController = TextEditingController(text: existingConfig?.baseUrl ?? '');
    final maxTokensController = TextEditingController(text: existingConfig?.maxOutputTokens?.toString() ?? '');
    final stopSequencesController = TextEditingController(text: existingConfig?.stopSequences?.join(', ') ?? '');
    final thinkingBudgetController = TextEditingController(text: existingConfig?.thinkingBudget?.toString() ?? '');
    final toolConfigController = TextEditingController(text: existingConfig?.toolConfig ?? '');
    final toolChoiceController = TextEditingController(text: existingConfig?.toolChoice ?? '');
    
    var selectedApiType = existingConfig?.apiType ?? LlmType.gemini;
    var useCustomTemperature = existingConfig?.useCustomTemperature ?? false;
    var temperature = existingConfig?.temperature ?? 1.0;
    var useCustomTopP = existingConfig?.useCustomTopP ?? false;
    var topP = existingConfig?.topP ?? 0.95;
    var useCustomTopK = existingConfig?.useCustomTopK ?? false;
    var topK = existingConfig?.topK?.toDouble() ?? 40.0;
    var enableReasoningEffort = existingConfig?.enableReasoningEffort ?? false;
    var reasoningEffort = existingConfig?.reasoningEffort ?? OpenAIReasoningEffort.auto;
    var useDefaultSafetySettings = existingConfig?.useDefaultSafetySettings ?? true;

    // Reset the state of the models provider when opening the dialog to ensure data isolation.
    Future.microtask(() => ref.read(openAIModelsProvider.notifier).resetState());

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isNew ? '添加新配置' : '编辑配置'),
              content: SingleChildScrollView(
                child: Form(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('基本设置', style: TextStyle(fontWeight: FontWeight.bold)),
                      const Divider(),
                      TextFormField(controller: nameController, decoration: const InputDecoration(labelText: '配置名称')),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<LlmType>(
                        value: selectedApiType,
                        items: LlmType.values.map((type) => DropdownMenuItem(value: type, child: Text(type.name))).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => selectedApiType = value);
                          }
                        },
                        decoration: const InputDecoration(labelText: 'API 类型'),
                      ),
                      const SizedBox(height: 16),
                      if (selectedApiType == LlmType.openai) ...[
                        Consumer(
                          builder: (context, ref, child) {
                            final modelsState = ref.watch(openAIModelsProvider);
                            final models = modelsState.models.asData?.value ?? [];

                            return TextFormField(
                              controller: modelController,
                              decoration: InputDecoration(
                                labelText: '模型名称',
                                suffixIcon: models.isEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.refresh),
                                        tooltip: '获取模型列表',
                                        onPressed: () {
                                          final baseUrl = baseUrlController.text;
                                          final apiKey = apiKeyController.text;
                                          if (baseUrl.isNotEmpty && apiKey.isNotEmpty) {
                                            ref.read(openAIModelsProvider.notifier).fetchModels(ApiConfig(id: '-1', name: 'temp', apiType: LlmType.openai, model: '', baseUrl: baseUrl, apiKey: apiKey, createdAt: DateTime.now(), updatedAt: DateTime.now()));
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('请输入 Base URL 和 API Key 以获取模型列表')),
                                            );
                                          }
                                        },
                                      )
                                    : PopupMenuButton<String>(
                                        icon: const Icon(Icons.arrow_drop_down),
                                        tooltip: '选择模型',
                                        onSelected: (String value) {
                                          setDialogState(() {
                                            modelController.text = value;
                                          });
                                        },
                                        itemBuilder: (BuildContext context) {
                                          // The list from the provider should not contain nulls.
                                          return models.map((model) {
                                            return PopupMenuItem<String>(
                                              value: model.id,
                                              child: Text(model.id),
                                            );
                                          }).toList();
                                        },
                                      ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                      ] else ...[
                        TextFormField(controller: modelController, decoration: const InputDecoration(labelText: '模型名称')),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(controller: baseUrlController, decoration: const InputDecoration(labelText: '自定义 URL (可选)', hintText: '将覆盖默认 API 地址')),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: apiKeyController,
                        decoration: InputDecoration(
                          labelText: selectedApiType == LlmType.openai ? 'API Key (必填)' : '专用 API Key (可选)',
                          hintText: selectedApiType == LlmType.gemini ? '留空则使用全局密钥池' : '',
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 24),
                      const Text('高级生成设置', style: TextStyle(fontWeight: FontWeight.bold)),
                      const Divider(),
                      if (selectedApiType == LlmType.gemini) ...[
                        TextFormField(
                          controller: thinkingBudgetController,
                          decoration: const InputDecoration(labelText: '思考预算 (可选)', hintText: '例如: 10000 或 -1'),
                          keyboardType: const TextInputType.numberWithOptions(signed: true),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (selectedApiType == LlmType.openai) ...[
                        SwitchListTile(
                          title: const Text('启用推理强度'),
                          subtitle: Text(enableReasoningEffort ? '已启用' : '已关闭'),
                          value: enableReasoningEffort,
                          onChanged: (val) => setDialogState(() => enableReasoningEffort = val),
                        ),
                        if (enableReasoningEffort)
                          DropdownButtonFormField<OpenAIReasoningEffort>(
                            value: reasoningEffort,
                            items: OpenAIReasoningEffort.values.map((level) {
                              return DropdownMenuItem(
                                value: level,
                                child: Text(level.name),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() => reasoningEffort = value);
                              }
                            },
                            decoration: const InputDecoration(labelText: '推理强度 (Reasoning Effort)'),
                          ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: maxTokensController,
                        decoration: const InputDecoration(labelText: '最大输出 Tokens (可选)'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: stopSequencesController,
                        decoration: const InputDecoration(labelText: '停止序列 (可选)', hintText: '用逗号分隔'),
                      ),
                      if (selectedApiType == LlmType.openai) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: toolChoiceController,
                          decoration: const InputDecoration(labelText: 'Tool Choice (可选)', hintText: 'auto, none, or JSON'),
                        ),
                      ],
                      if (selectedApiType == LlmType.gemini) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: toolConfigController,
                          decoration: const InputDecoration(labelText: 'Tool Config (可选)', hintText: 'JSON string'),
                           maxLines: null, // Allow multiple lines
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text('使用默认安全设置'),
                          subtitle: Text(useDefaultSafetySettings ? '开启 (全部设为 OFF)' : '关闭 (不发送)'),
                          value: useDefaultSafetySettings,
                          onChanged: (val) => setDialogState(() => useDefaultSafetySettings = val),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('自定义 Temperature'),
                        subtitle: Text(useCustomTemperature ? temperature.toStringAsFixed(2) : 'API 默认'),
                        value: useCustomTemperature,
                        onChanged: (val) => setDialogState(() => useCustomTemperature = val),
                      ),
                      Slider(
                        value: temperature,
                        min: 0.0,
                        max: 2.0,
                        divisions: 40,
                        label: temperature.toStringAsFixed(2),
                        onChanged: useCustomTemperature ? (val) => setDialogState(() => temperature = val) : null,
                      ),
                      SwitchListTile(
                        title: const Text('自定义 Top P'),
                        subtitle: Text(useCustomTopP ? topP.toStringAsFixed(2) : 'API 默认'),
                        value: useCustomTopP,
                        onChanged: (val) => setDialogState(() => useCustomTopP = val),
                      ),
                      Slider(
                        value: topP,
                        min: 0.0,
                        max: 1.0,
                        divisions: 100,
                        label: topP.toStringAsFixed(2),
                        onChanged: useCustomTopP ? (val) => setDialogState(() => topP = val) : null,
                      ),
                      SwitchListTile(
                        title: const Text('自定义 Top K'),
                        subtitle: Text(useCustomTopK ? topK.round().toString() : 'API 默认'),
                        value: useCustomTopK,
                        onChanged: (val) => setDialogState(() => useCustomTopK = val),
                      ),
                      Slider(
                        value: topK,
                        min: 1.0,
                        max: 100.0,
                        divisions: 99,
                        label: topK.round().toString(),
                        onChanged: useCustomTopK ? (val) => setDialogState(() => topK = val) : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
                if (!isNew)
                  TextButton(
                    onPressed: () {
                      final allConfigs = ref.read(apiKeyNotifierProvider).apiConfigs;
                      final currentName = nameController.text.isNotEmpty ? nameController.text : modelController.text;

                      if (currentName.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('配置名称和模型名称不能都为空')),
                        );
                        return;
                      }

                      String newName = currentName;
                      if (currentName == existingConfig.name) {
                        newName = '$currentName (副本)';
                      }

                      if (allConfigs.any((c) => c.name == newName)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('配置名称 "$newName" 已存在')),
                        );
                        return;
                      }

                      // Validation for OpenAI API Key
                      if (selectedApiType == LlmType.openai && apiKeyController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('OpenAI 配置需要填写 API Key')),
                        );
                        return;
                      }

                      ref.read(apiKeyNotifierProvider.notifier).saveConfig(
                        id: null, // Force creation of a new config
                        name: newName,
                        apiType: selectedApiType,
                        model: modelController.text,
                        apiKey: apiKeyController.text.isNotEmpty ? apiKeyController.text : null,
                        baseUrl: (selectedApiType == LlmType.openai || selectedApiType == LlmType.gemini) && baseUrlController.text.isNotEmpty ? baseUrlController.text : null,
                        useCustomTemperature: useCustomTemperature,
                        temperature: useCustomTemperature ? temperature : null,
                        useCustomTopP: useCustomTopP,
                        topP: useCustomTopP ? topP : null,
                        useCustomTopK: useCustomTopK,
                        topK: useCustomTopK ? topK.round() : null,
                        maxOutputTokens: int.tryParse(maxTokensController.text),
                        stopSequences: stopSequencesController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
                        enableReasoningEffort: enableReasoningEffort,
                        reasoningEffort: enableReasoningEffort ? reasoningEffort : OpenAIReasoningEffort.auto,
                        thinkingBudget: int.tryParse(thinkingBudgetController.text),
                        toolConfig: toolConfigController.text.isNotEmpty ? toolConfigController.text : null,
                        toolChoice: toolChoiceController.text.isNotEmpty ? toolChoiceController.text : null,
                        useDefaultSafetySettings: useDefaultSafetySettings,
                      );
                      Navigator.pop(context);
                    },
                    child: const Text('另存为'),
                  ),
                TextButton(
                  onPressed: () {
                    final allConfigs = ref.read(apiKeyNotifierProvider).apiConfigs;
                    final configName = nameController.text.isNotEmpty ? nameController.text : modelController.text;

                    if (configName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('配置名称和模型名称不能都为空')),
                      );
                      return;
                    }

                    if (allConfigs.any((c) => c.name == configName && c.id != existingConfig?.id)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('配置名称 "$configName" 已存在')),
                      );
                      return;
                    }

                    // Validation for OpenAI API Key
                    if (selectedApiType == LlmType.openai && apiKeyController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('OpenAI 配置需要填写 API Key')),
                      );
                      return;
                    }

                    ref.read(apiKeyNotifierProvider.notifier).saveConfig(
                      id: existingConfig?.id,
                      name: configName,
                      apiType: selectedApiType,
                      model: modelController.text,
                      apiKey: apiKeyController.text.isNotEmpty ? apiKeyController.text : null,
                      baseUrl: (selectedApiType == LlmType.openai || selectedApiType == LlmType.gemini) && baseUrlController.text.isNotEmpty ? baseUrlController.text : null,
                      useCustomTemperature: useCustomTemperature,
                      temperature: useCustomTemperature ? temperature : null,
                      useCustomTopP: useCustomTopP,
                      topP: useCustomTopP ? topP : null,
                      useCustomTopK: useCustomTopK,
                      topK: useCustomTopK ? topK.round() : null,
                      maxOutputTokens: int.tryParse(maxTokensController.text),
                      stopSequences: stopSequencesController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
                      enableReasoningEffort: enableReasoningEffort,
                      reasoningEffort: enableReasoningEffort ? reasoningEffort : OpenAIReasoningEffort.auto,
                      thinkingBudget: int.tryParse(thinkingBudgetController.text),
                      toolConfig: toolConfigController.text.isNotEmpty ? toolConfigController.text : null,
                      toolChoice: toolChoiceController.text.isNotEmpty ? toolChoiceController.text : null,
                      useDefaultSafetySettings: useDefaultSafetySettings,
                    );
                    Navigator.pop(context);
                 },
                  child: Text(isNew ? '添加' : '保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
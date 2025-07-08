import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;

// 导入模型、Provider 和仓库
import '../models/models.dart';
import '../data/database/drift/models/drift_xml_rule.dart';
import '../data/database/drift/models/drift_openai_api_config.dart';
import '../data/database/drift/common_enums.dart' as drift_enums;
import '../providers/api_key_provider.dart';
import '../providers/chat_settings_provider.dart';

// 本文件包含用于配置单个聊天会话设置的屏幕界面。

// 使用 ConsumerStatefulWidget 来处理本地 UI 状态（如 _showAdvancedSettings）
class ChatSettingsScreen extends ConsumerStatefulWidget {
  final int chatId;
  const ChatSettingsScreen({super.key, required this.chatId});

  @override
  ConsumerState<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends ConsumerState<ChatSettingsScreen> {
  // 本地 UI 状态，与业务逻辑无关
  bool _showAdvancedSettings = false;

  // --- 显示添加/编辑 XML 规则的对话框 ---
  void _showXmlRuleDialog(BuildContext context, {DriftXmlRule? existingRule, int? ruleIndex}) {
    final notifier = ref.read(chatSettingsProvider(widget.chatId).notifier);
    final tagNameController = TextEditingController(text: existingRule?.tagName ?? '');
    drift_enums.XmlAction selectedAction = existingRule?.action ?? drift_enums.XmlAction.ignore;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existingRule == null ? '添加 XML 规则' : '编辑 XML 规则'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: tagNameController,
                    decoration: const InputDecoration(
                      labelText: 'XML 标签名称',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<drift_enums.XmlAction>(
                    value: selectedAction,
                    decoration: const InputDecoration(
                      labelText: '处理动作',
                      border: OutlineInputBorder(),
                    ),
                    items: drift_enums.XmlAction.values.map((action) {
                      return DropdownMenuItem(
                        value: action,
                        child: Text(action.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          selectedAction = value;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
                TextButton(
                  onPressed: () {
                    final tagName = tagNameController.text.trim();
                    if (tagName.isNotEmpty) {
                      final newRule = DriftXmlRule(tagName: tagName, action: selectedAction);
                      notifier.updateSettings((chat) {
                        final rules = List<DriftXmlRule>.from(chat.xmlRules);
                        if (ruleIndex != null) {
                          rules[ruleIndex] = newRule;
                        } else {
                          if (!rules.any((r) => r.tagName?.toLowerCase() == tagName.toLowerCase())) {
                            rules.add(newRule);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('该标签名称的规则已存在'), backgroundColor: Colors.orange));
                            return chat; // No change
                          }
                        }
                        return chat.copyWith(xmlRules: rules);
                      });
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('标签名称不能为空'), backgroundColor: Colors.red));
                    }
                  },
                  child: Text(existingRule == null ? '添加' : '保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsState = ref.watch(chatSettingsProvider(widget.chatId));
    final notifier = ref.read(chatSettingsProvider(widget.chatId).notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(_showAdvancedSettings ? '高级模型设置' : '聊天设置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: '保存设置',
            onPressed: () async {
              try {
                await notifier.saveSettings();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('设置已保存')));
                  Navigator.pop(context);
                }
              } catch (e) {
                 if (context.mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red));
                 }
              }
            },
          ),
          TextButton.icon(
            icon: Icon(_showAdvancedSettings ? Icons.settings_outlined : Icons.tune_outlined),
            label: Text(_showAdvancedSettings ? '基本设置' : '高级选项'),
            onPressed: () => setState(() => _showAdvancedSettings = !_showAdvancedSettings),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).appBarTheme.foregroundColor ?? Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ],
      ),
      body: settingsState.initialChat.when(
        data: (_) {
          final chat = settingsState.chatForDisplay;
          if (chat == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Form(
              child: _showAdvancedSettings
                  ? _buildAdvancedSettingsForm(context, ref, chat)
                  : _buildMainSettingsForm(context, ref, chat),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('无法加载聊天设置: $err')),
      ),
    );
  }

  Widget _buildMainSettingsForm(BuildContext context, WidgetRef ref, Chat chat) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _BasicInfoSettings(chatId: widget.chatId),
        const Divider(height: 30),
        _ApiProviderSettings(chatId: widget.chatId),
        const Divider(height: 30),
        _ContextManagementSettings(chatId: widget.chatId),
        const Divider(height: 30),
        _XmlRulesSettings(
          chatId: widget.chatId,
          onShowXmlRuleDialog: (rule, index) => _showXmlRuleDialog(context, existingRule: rule, ruleIndex: index),
        ),
        const Divider(height: 30),
        _AutomationSettings(chatId: widget.chatId),
      ],
    );
  }

  Widget _buildAdvancedSettingsForm(BuildContext context, WidgetRef ref, Chat chat) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _ModelParametersSettings(chatId: widget.chatId),
      ],
    );
  }
}

// --- 封装的私有小部件 ---

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleLarge);
  }
}

class _BasicInfoSettings extends ConsumerWidget {
  final int chatId;
  const _BasicInfoSettings({required this.chatId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatSettingsProvider(chatId).select((s) => s.chatForDisplay!));
    final notifier = ref.read(chatSettingsProvider(chatId).notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('基本信息'),
        const SizedBox(height: 15),
        TextFormField(
          key: ValueKey('title_${chat.id}'),
          initialValue: chat.title,
          decoration: const InputDecoration(labelText: '聊天标题', border: OutlineInputBorder()),
          onChanged: (value) => notifier.updateSettings((c) => c.copyWith(title: value)),
        ),
        const SizedBox(height: 15),
        TextFormField(
          key: ValueKey('systemPrompt_${chat.id}'),
          initialValue: chat.systemPrompt,
          decoration: const InputDecoration(labelText: '系统提示词', hintText: '定义 AI 的角色或行为...', border: OutlineInputBorder()),
          maxLines: 4,
          minLines: 2,
          onChanged: (value) => notifier.updateSettings((c) => c.copyWith(systemPrompt: value)),
        ),
      ],
    );
  }
}

class _ApiProviderSettings extends ConsumerWidget {
  final int chatId;
  const _ApiProviderSettings({required this.chatId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatSettingsProvider(chatId).select((s) => s.chatForDisplay!));
    final notifier = ref.read(chatSettingsProvider(chatId).notifier);
    final openAIConfigs = ref.watch(apiKeyNotifierProvider.select((s) => s.openAIConfigs));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('API 提供者'),
        const SizedBox(height: 15),
        DropdownButtonFormField<drift_enums.LlmType>(
          value: chat.apiType,
          decoration: const InputDecoration(labelText: '选择 API 类型', border: OutlineInputBorder()),
          items: drift_enums.LlmType.values.map((type) => DropdownMenuItem(
            value: type,
            child: Text(type == drift_enums.LlmType.gemini ? 'Google Gemini' : 'OpenAI 兼容 API'),
          )).toList(),
          onChanged: (value) {
            if (value != null) {
              notifier.updateSettings((c) {
                String? newConfigId = c.selectedOpenAIConfigId;
                if (value == drift_enums.LlmType.openai) {
                   final currentIdIsValid = newConfigId != null && openAIConfigs.any((conf) => conf.id == newConfigId);
                   if (!currentIdIsValid) {
                     newConfigId = openAIConfigs.isNotEmpty ? openAIConfigs.first.id : null;
                   }
                } else {
                  newConfigId = null;
                }
                return c.copyWith(apiType: value, selectedOpenAIConfigId: Value(newConfigId));
              });
            }
          },
        ),
        const SizedBox(height: 15),
        if (chat.apiType == drift_enums.LlmType.openai)
          if (openAIConfigs.isEmpty)
            const Text('没有可用的 OpenAI 配置。请先在全局设置中添加。', style: TextStyle(color: Colors.orange))
          else
            DropdownButtonFormField<String>(
              value: openAIConfigs.any((c) => c.id == chat.selectedOpenAIConfigId) ? chat.selectedOpenAIConfigId : null,
              decoration: const InputDecoration(labelText: '选择 OpenAI 配置', border: OutlineInputBorder()),
              items: openAIConfigs.map((config) => DropdownMenuItem(
                value: config.id,
                child: Text(config.name),
              )).toList(),
              onChanged: (value) => notifier.updateSettings((c) => c.copyWith(selectedOpenAIConfigId: Value(value))),
              validator: (value) => (value == null) ? '请选择一个 OpenAI 配置。' : null,
            ),
      ],
    );
  }
}

class _ContextManagementSettings extends ConsumerWidget {
  final int chatId;
  const _ContextManagementSettings({required this.chatId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatSettingsProvider(chatId).select((s) => s.chatForDisplay!));
    final notifier = ref.read(chatSettingsProvider(chatId).notifier);
    final contextConfig = chat.contextConfig;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('上下文管理'),
        const SizedBox(height: 15),
        DropdownButtonFormField<drift_enums.ContextManagementMode>(
          value: contextConfig.mode,
          decoration: const InputDecoration(labelText: '上下文模式', border: OutlineInputBorder()),
          items: drift_enums.ContextManagementMode.values.map((mode) => DropdownMenuItem(
            value: mode,
            child: Text(mode == drift_enums.ContextManagementMode.turns ? '按轮数' : '按 Tokens (实验性)'),
          )).toList(),
          onChanged: (value) {
            if (value != null) {
              notifier.updateSettings((c) => c.copyWith(contextConfig: contextConfig.copyWith(mode: value)));
            }
          },
        ),
        const SizedBox(height: 15),
        if (contextConfig.mode == drift_enums.ContextManagementMode.turns)
          TextFormField(
            key: ValueKey('maxTurns_${chat.id}'),
            initialValue: contextConfig.maxTurns.toString(),
            decoration: const InputDecoration(labelText: '最大对话轮数', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
            onChanged: (value) => notifier.updateSettings((c) => c.copyWith(contextConfig: contextConfig.copyWith(maxTurns: int.tryParse(value) ?? 10))),
          ),
        if (contextConfig.mode == drift_enums.ContextManagementMode.tokens)
          TextFormField(
            key: ValueKey('maxTokens_${chat.id}'),
            initialValue: contextConfig.maxContextTokens?.toString() ?? '',
            decoration: const InputDecoration(labelText: '最大 Tokens (可选)', hintText: '留空则不限制', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
            onChanged: (value) => notifier.updateSettings((c) => c.copyWith(contextConfig: contextConfig.copyWith(maxContextTokens: int.tryParse(value)))),
          ),
      ],
    );
  }
}

class _XmlRulesSettings extends ConsumerWidget {
  final int chatId;
  final Function(DriftXmlRule?, int?) onShowXmlRuleDialog;

  const _XmlRulesSettings({required this.chatId, required this.onShowXmlRuleDialog});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatSettingsProvider(chatId).select((s) => s.chatForDisplay!));
    final notifier = ref.read(chatSettingsProvider(chatId).notifier);
    final xmlRules = chat.xmlRules;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SectionTitle('XML 处理规则 (${xmlRules.length})'),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: '添加规则',
              onPressed: () => onShowXmlRuleDialog(null, null),
            )
          ],
        ),
        const SizedBox(height: 5),
        if (xmlRules.isEmpty)
          const Text('未定义任何 XML 规则。', style: TextStyle(color: Colors.grey))
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: xmlRules.length,
            itemBuilder: (context, index) {
              final rule = xmlRules[index];
              return ListTile(
                title: Text('<${rule.tagName ?? "无效规则"}>'),
                subtitle: Text('动作: ${rule.action.name}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      tooltip: '编辑规则',
                      onPressed: () => onShowXmlRuleDialog(rule, index),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                      tooltip: '删除规则',
                      onPressed: () {
                        notifier.updateSettings((c) {
                          final rules = List<DriftXmlRule>.from(c.xmlRules)..removeAt(index);
                          return c.copyWith(xmlRules: rules);
                        });
                      },
                    ),
                  ],
                ),
                dense: true,
              );
            },
          ),
      ],
    );
  }
}

class _AutomationSettings extends ConsumerWidget {
  final int chatId;
  const _AutomationSettings({required this.chatId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatSettingsProvider(chatId).select((s) => s.chatForDisplay!));
    final notifier = ref.read(chatSettingsProvider(chatId).notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('自动化处理'),
        const SizedBox(height: 10),
        SwitchListTile(
          title: const Text('启用上下文总结 (前处理)'),
          subtitle: const Text('在回复后，对被遗忘的旧消息进行总结'),
          value: chat.enablePreprocessing,
          onChanged: (value) => notifier.updateSettings((c) => c.copyWith(enablePreprocessing: value)),
        ),
        if (chat.enablePreprocessing)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 16.0, right: 16.0, bottom: 16.0),
            child: TextFormField(
              key: ValueKey('preprocessingPrompt_${chat.id}'),
              initialValue: chat.preprocessingPrompt,
              decoration: const InputDecoration(labelText: '前处理提示词', hintText: '例如：请总结以下对话...', border: OutlineInputBorder()),
              maxLines: 3,
              minLines: 1,
              onChanged: (value) => notifier.updateSettings((c) => c.copyWith(preprocessingPrompt: Value(value))),
            ),
          ),
        SwitchListTile(
          title: const Text('启用回复增强 (后处理)'),
          subtitle: const Text('在回复后，使用特定提示词强化XML输出'),
          value: chat.enablePostprocessing,
          onChanged: (value) => notifier.updateSettings((c) => c.copyWith(enablePostprocessing: value)),
        ),
        if (chat.enablePostprocessing)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 16.0, right: 16.0, bottom: 16.0),
            child: TextFormField(
              key: ValueKey('postprocessingPrompt_${chat.id}'),
              initialValue: chat.postprocessingPrompt,
              decoration: const InputDecoration(labelText: '后处理提示词', hintText: '例如：请根据对话历史，生成tool_code标签...', border: OutlineInputBorder()),
              maxLines: 3,
              minLines: 1,
              onChanged: (value) => notifier.updateSettings((c) => c.copyWith(postprocessingPrompt: Value(value))),
            ),
          ),
      ],
    );
  }
}

class _ModelParametersSettings extends ConsumerWidget {
  final int chatId;
  const _ModelParametersSettings({required this.chatId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatSettingsProvider(chatId).select((s) => s.chatForDisplay!));
    final notifier = ref.read(chatSettingsProvider(chatId).notifier);
    final genConfig = chat.generationConfig;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('模型与生成设置'),
        const SizedBox(height: 15),
        if (chat.apiType == drift_enums.LlmType.gemini) ...[
          TextFormField(
            key: ValueKey('modelName_${chat.id}'),
            initialValue: genConfig.modelName,
            decoration: const InputDecoration(labelText: 'Gemini 模型名称', hintText: '例如: gemini-1.5-pro-latest', border: OutlineInputBorder()),
            onChanged: (value) => notifier.updateSettings((c) => c.copyWith(generationConfig: genConfig.copyWith(modelName: value))),
          ),
          const SizedBox(height: 15),
        ] else if (chat.apiType == drift_enums.LlmType.openai) ...[
          Consumer(builder: (context, ref, child) {
            final openAIConfigs = ref.watch(apiKeyNotifierProvider.select((s) => s.openAIConfigs));
            final selectedConfig = openAIConfigs.firstWhere(
                (c) => c.id == chat.selectedOpenAIConfigId,
                orElse: () => DriftOpenAIAPIConfig(id: '', name: '未找到配置', model: 'N/A', baseUrl: ''),
            );
            return ListTile(
              title: const Text('OpenAI 模型名称'),
              subtitle: Text(selectedConfig.model.isNotEmpty ? selectedConfig.model : '(来自所选配置)'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            );
          }),
          const SizedBox(height: 15),
        ],
        TextFormField(
          key: ValueKey('maxOutputTokens_${chat.id}'),
          initialValue: genConfig.maxOutputTokens?.toString() ?? '',
          decoration: const InputDecoration(labelText: '最大输出 Tokens (可选)', border: OutlineInputBorder()),
          keyboardType: TextInputType.number,
          onChanged: (value) => notifier.updateSettings((c) => c.copyWith(generationConfig: genConfig.copyWith(maxOutputTokens: int.tryParse(value)))),
        ),
        const SizedBox(height: 15),
        TextFormField(
          key: ValueKey('stopSequences_${chat.id}'),
          initialValue: genConfig.stopSequences?.join(', ') ?? '',
          decoration: const InputDecoration(labelText: '停止序列 (可选)', hintText: '用逗号分隔, 例如: END,STOP', border: OutlineInputBorder()),
          maxLines: 2,
          minLines: 1,
          onChanged: (value) {
            final sequences = value.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
            notifier.updateSettings((c) => c.copyWith(generationConfig: genConfig.copyWith(stopSequences: sequences)));
          },
        ),
        const Divider(height: 20),
        SwitchListTile(
          title: const Text('自定义 Temperature'),
          subtitle: Text(genConfig.useCustomTemperature ? (genConfig.temperature?.toStringAsFixed(1) ?? '1.0') : 'API 默认'),
          value: genConfig.useCustomTemperature,
          onChanged: (bool value) => notifier.updateSettings((c) => c.copyWith(generationConfig: genConfig.copyWith(useCustomTemperature: value, temperature: value ? (c.generationConfig.temperature ?? 1.0) : null))),
        ),
        Slider(
           value: genConfig.temperature ?? 1.0,
           min: 0.0, max: 2.0, divisions: 40,
           label: (genConfig.temperature ?? 1.0).toStringAsFixed(1),
           onChanged: genConfig.useCustomTemperature ? (val) => notifier.updateSettings((c) => c.copyWith(generationConfig: genConfig.copyWith(temperature: val))) : null,
        ),
        const SizedBox(height: 10),
        SwitchListTile(
          title: const Text('自定义 Top P'),
          subtitle: Text(genConfig.useCustomTopP ? (genConfig.topP?.toStringAsFixed(2) ?? '0.95') : 'API 默认'),
          value: genConfig.useCustomTopP,
          onChanged: (bool value) => notifier.updateSettings((c) => c.copyWith(generationConfig: genConfig.copyWith(useCustomTopP: value, topP: value ? (c.generationConfig.topP ?? 0.95) : null))),
        ),
        Slider(
            value: genConfig.topP ?? 0.95,
            min: 0.0, max: 1.0, divisions: 100,
            label: (genConfig.topP ?? 0.95).toStringAsFixed(2),
            onChanged: genConfig.useCustomTopP ? (val) => notifier.updateSettings((c) => c.copyWith(generationConfig: genConfig.copyWith(topP: val))) : null,
        ),
        const SizedBox(height: 10),
        SwitchListTile(
          title: const Text('自定义 Top K'),
          subtitle: Text(genConfig.useCustomTopK ? (genConfig.topK?.round().toString() ?? '40') : 'API 默认'),
          value: genConfig.useCustomTopK,
          onChanged: (bool value) => notifier.updateSettings((c) => c.copyWith(generationConfig: genConfig.copyWith(useCustomTopK: value, topK: value ? (c.generationConfig.topK ?? 40) : null))),
        ),
        Slider(
          value: genConfig.topK?.toDouble() ?? 40.0,
          min: 1.0, max: 100.0, divisions: 99,
          label: (genConfig.topK?.round() ?? 40).toString(),
          onChanged: genConfig.useCustomTopK ? (val) => notifier.updateSettings((c) => c.copyWith(generationConfig: genConfig.copyWith(topK: val.round()))) : null,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;

// 导入模型、Provider 和仓库
import '../../models/models.dart';
import '../../data/models/drift_xml_rule.dart';
import '../../data/common_enums.dart' as drift_enums;
import '../../providers/api_key_provider.dart';
import '../../providers/chat_settings_provider.dart';
import '../../providers/chat_state_providers.dart';
import '../widgets/fullscreen_text_editor.dart'; // 导入全屏文本编辑器

// --- 默认提示词常量 ---
const String defaultContinuePrompt = '请根据你上一次的回复继续补充或续写。';
const String defaultPreprocessingPrompt = '根据对话以及之前的总结（如果有）进行详细的总结概括，尤其要分析并保留关键的信息，进行有条理的归纳。';
const String defaultSecondaryXmlPrompt = '使用<Summary><summary id=“”></summary></Summary>对最新一轮对话进行总结，已有内容无需重复总结，如果新的内容较少，直接回复<Summary>略</Summary>即可。';


// 本文件包含用于配置单个聊天会话设置的屏幕界面。

class ChatSettingsScreen extends ConsumerStatefulWidget {
  const ChatSettingsScreen({super.key});

  @override
  ConsumerState<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends ConsumerState<ChatSettingsScreen> {
  // --- 显示添加/编辑 XML 规则的对话框 ---
  void _showXmlRuleDialog(BuildContext context, {DriftXmlRule? existingRule, int? ruleIndex}) {
    final chatId = ref.read(activeChatIdProvider);
    if (chatId == null) return;
    final notifier = ref.read(chatSettingsProvider(chatId).notifier);
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
    final chatId = ref.watch(activeChatIdProvider);
    if (chatId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('聊天设置')),
        body: const Center(child: Text('没有活动的聊天。')),
      );
    }
    final settingsState = ref.watch(chatSettingsProvider(chatId));
    final notifier = ref.read(chatSettingsProvider(chatId).notifier);

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
          '聊天设置',
          style: TextStyle(
            shadows: <Shadow>[
              Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 1.0)
            ],
          ),
        ),
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
        ],
      ),
      body: settingsState.initialChat.when(
        data: (_) {
          final chat = settingsState.chatForDisplay;
          if (chat == null) {
            return const SizedBox.shrink();
          }
          return GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Form(
              child: _buildMainSettingsForm(context, ref, chat, chatId),
            ),
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (err, stack) => Center(child: Text('无法加载聊天设置: $err')),
      ),
    );
  }

  Widget _buildMainSettingsForm(BuildContext context, WidgetRef ref, Chat chat, int chatId) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _BasicInfoSettings(chatId: chatId),
        const Divider(height: 30),
        _ApiProviderSettings(chatId: chatId),
        const Divider(height: 30),
        _ContextManagementSettings(chatId: chatId),
        const Divider(height: 30),
        _XmlRulesSettings(
          chatId: chatId,
          onShowXmlRuleDialog: (rule, index) => _showXmlRuleDialog(context, existingRule: rule, ruleIndex: index),
        ),
        const Divider(height: 30),
        _AutomationSettings(chatId: chatId),
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
          key: ValueKey('systemPrompt_${chat.id}_${chat.systemPrompt}'),
          initialValue: chat.systemPrompt,
          decoration: InputDecoration(
            labelText: '系统提示词',
            hintText: '定义 AI 的角色或行为...',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.fullscreen),
              tooltip: '全屏编辑',
              onPressed: () async {
                final newText = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (context) => FullScreenTextEditorScreen(
                      initialText: chat.systemPrompt ?? '',
                      title: '编辑系统提示词',
                      // 注意：系统提示词没有全局默认值，因此不提供 defaultValue
                    ),
                  ),
                );
                if (newText != null) {
                  notifier.updateSettings((c) => c.copyWith(systemPrompt: newText));
                }
              },
            ),
          ),
          maxLines: 4,
          minLines: 2,
          onChanged: (value) => notifier.updateSettings((c) => c.copyWith(systemPrompt: value)),
        ),
        const SizedBox(height: 15),
        TextFormField(
          key: ValueKey('continuePrompt_${chat.id}_${chat.continuePrompt}'),
          initialValue: chat.continuePrompt,
          decoration: InputDecoration(
            labelText: '续写提示词 (可选)',
            hintText: '为空时，续写功能将使用系统提示词',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.fullscreen),
              tooltip: '全屏编辑',
              onPressed: () async {
                final newText = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (context) => FullScreenTextEditorScreen(
                      initialText: chat.continuePrompt ?? defaultContinuePrompt,
                      title: '编辑续写提示词',
                      defaultValue: defaultContinuePrompt,
                    ),
                  ),
                );
                if (newText != null) {
                  notifier.updateSettings((c) => c.copyWith(continuePrompt: Value(newText)));
                }
              },
            ),
          ),
          maxLines: 4,
          minLines: 2,
          onChanged: (value) => notifier.updateSettings((c) => c.copyWith(continuePrompt: Value(value.isEmpty ? null : value))),
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
    final apiConfigs = ref.watch(apiKeyNotifierProvider.select((s) => s.apiConfigs));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('API 提供者'),
        const SizedBox(height: 15),
        if (apiConfigs.isEmpty)
          const Text('没有可用的 API 配置。请先在全局设置中添加。', style: TextStyle(color: Colors.orange))
        else
          DropdownButtonFormField<String>(
            value: apiConfigs.any((c) => c.id == chat.apiConfigId) ? chat.apiConfigId : null,
            decoration: const InputDecoration(labelText: '选择 API 配置', border: OutlineInputBorder()),
            items: apiConfigs.map((config) => DropdownMenuItem(
              value: config.id,
              child: Text(config.name),
            )).toList(),
            onChanged: (value) {
              notifier.updateSettings((c) => c.copyWith(apiConfigId: Value(value)));
            },
            validator: (value) => (value == null) ? '请选择一个 API 配置。' : null,
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
    final apiConfigs = ref.watch(apiKeyNotifierProvider.select((s) => s.apiConfigs));

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
              key: ValueKey('preprocessingPrompt_${chat.id}_${chat.preprocessingPrompt}'),
              initialValue: chat.preprocessingPrompt ?? defaultPreprocessingPrompt,
              decoration: InputDecoration(
                labelText: '前处理提示词',
                hintText: '例如：请总结以下对话...',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.fullscreen),
                  tooltip: '全屏编辑',
                  onPressed: () async {
                    final newText = await Navigator.of(context).push<String>(
                      MaterialPageRoute(
                        builder: (context) => FullScreenTextEditorScreen(
                          initialText: chat.preprocessingPrompt ?? defaultPreprocessingPrompt,
                          title: '编辑前处理提示词',
                          defaultValue: defaultPreprocessingPrompt,
                        ),
                      ),
                    );
                    if (newText != null) {
                      notifier.updateSettings((c) => c.copyWith(preprocessingPrompt: Value(newText)));
                    }
                  },
                ),
              ),
              maxLines: 3,
              minLines: 1,
              onChanged: (value) => notifier.updateSettings((c) => c.copyWith(preprocessingPrompt: Value(value.isEmpty ? null : value))),
            ),
          ),
       if (chat.enablePreprocessing)
         Padding(
           padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
           child: DropdownButtonFormField<String>(
             value: apiConfigs.any((c) => c.id == chat.preprocessingApiConfigId) ? chat.preprocessingApiConfigId : null,
             decoration: const InputDecoration(labelText: '用于总结的 API 配置', border: OutlineInputBorder()),
             items: apiConfigs.map((config) => DropdownMenuItem(value: config.id, child: Text(config.name))).toList(),
             onChanged: (value) => notifier.updateSettings((c) => c.copyWith(preprocessingApiConfigId: Value(value))),
             validator: (value) => (value == null) ? '请选择一个 API 配置。' : null,
           ),
         ),
        SwitchListTile(
          title: const Text('启用附加XML生成'),
          subtitle: const Text('在回复后，使用附加提示词生成额外XML内容'),
          value: chat.enableSecondaryXml,
          onChanged: (value) => notifier.updateSettings((c) => c.copyWith(enableSecondaryXml: value)),
        ),
        if (chat.enableSecondaryXml)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 16.0, right: 16.0, bottom: 8.0),
            child: TextFormField(
              key: ValueKey('secondaryXmlPrompt_${chat.id}_${chat.secondaryXmlPrompt}'),
              initialValue: chat.secondaryXmlPrompt ?? defaultSecondaryXmlPrompt,
              decoration: InputDecoration(
                labelText: '附加XML提示词',
                hintText: '例如：请根据对话历史，生成tool_code标签...',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.fullscreen),
                  tooltip: '全屏编辑',
                  onPressed: () async {
                    final newText = await Navigator.of(context).push<String>(
                      MaterialPageRoute(
                        builder: (context) => FullScreenTextEditorScreen(
                          initialText: chat.secondaryXmlPrompt ?? defaultSecondaryXmlPrompt,
                          title: '编辑附加XML提示词',
                          defaultValue: defaultSecondaryXmlPrompt,
                        ),
                      ),
                    );
                    if (newText != null) {
                      notifier.updateSettings((c) => c.copyWith(secondaryXmlPrompt: Value(newText)));
                    }
                  },
                ),
              ),
              maxLines: 3,
              minLines: 1,
              onChanged: (value) => notifier.updateSettings((c) => c.copyWith(secondaryXmlPrompt: Value(value.isEmpty ? null : value))),
            ),
          ),
       if (chat.enableSecondaryXml)
         Padding(
           padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
           child: DropdownButtonFormField<String>(
             value: apiConfigs.any((c) => c.id == chat.secondaryXmlApiConfigId) ? chat.secondaryXmlApiConfigId : null,
             decoration: const InputDecoration(labelText: '用于附加XML的 API 配置', border: OutlineInputBorder()),
             items: apiConfigs.map((config) => DropdownMenuItem(value: config.id, child: Text(config.name))).toList(),
             onChanged: (value) => notifier.updateSettings((c) => c.copyWith(secondaryXmlApiConfigId: Value(value))),
             validator: (value) => (value == null) ? '请选择一个 API 配置。' : null,
           ),
         ),
      ],
    );
  }
}

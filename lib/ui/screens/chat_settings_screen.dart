import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 导入模型、Provider 和仓库
import '../../data/models/models.dart';
import '../providers/api_key_provider.dart';
import '../providers/chat_settings_provider.dart';
import '../providers/chat_state_providers.dart';
import '../widgets/fullscreen_text_editor.dart'; // 导入全屏文本编辑器
import '../providers/chat_state/chat_data_providers.dart';

// --- 默认提示词常量 ---
const String defaultContinuePrompt = '请根据你上一次的回复继续补充或续写。';
const String defaultPreprocessingPrompt = '根据对话以及之前的总结（如果有）进行详细的总结概括，尤其要分析并保留关键的信息，进行有条理的归纳。';
const String defaultSecondaryXmlPrompt = '使用<Summary><summary id=“”></summary></Summary>对最新一轮对话进行总结，已有内容无需重复总结，如果新的内容较少，直接回复<Summary>略</Summary>即可。';
const String defaultHelpMeReplyPrompt = '假如你是我，请根据以上对话，为我设想三个不同的回复，并使用序号1. 2. 3.分别标注。（不要包含任何其他非序号的回复内容。）';


// 本文件包含用于配置单个聊天会话设置的屏幕界面。

// --- 辅助方法：根据优先级解析有效的 API 配置 ---
ApiConfig? _getEffectiveApiConfig(WidgetRef ref, Chat chat, {String? specificConfigId}) {
 final allConfigs = ref.read(apiKeyNotifierProvider).apiConfigs;
 if (allConfigs.isEmpty) return null;

 final defaultConfig = allConfigs.first;

 // 检查 specificConfigId 是否有效
 if (specificConfigId != null) {
   final foundConfig = allConfigs.firstWhere((c) => c.id == specificConfigId, orElse: () => defaultConfig);
   return foundConfig;
 }
 
 // 检查聊天的主要 apiConfigId 是否有效
 if (chat.apiConfigId != null) {
   final foundConfig = allConfigs.firstWhere((c) => c.id == chat.apiConfigId, orElse: () => defaultConfig);
   return foundConfig;
 }
 
 // 如果都无效，则回退到列表的第一个
 return defaultConfig;
}

class ChatSettingsScreen extends ConsumerStatefulWidget {
  const ChatSettingsScreen({super.key});

  @override
  ConsumerState<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends ConsumerState<ChatSettingsScreen> {
  // --- 显示添加/编辑 XML 规则的对话框 ---
   void _showXmlRuleDialog(BuildContext context, {XmlRule? existingRule, int? ruleIndex}) {
     final chatId = ref.read(activeChatIdProvider);
     if (chatId == null) return;
    final notifier = ref.read(chatSettingsProvider(chatId).notifier);
    final tagNameController = TextEditingController(text: existingRule?.tagName ?? '');
    var selectedAction = existingRule?.action ?? XmlAction.ignore;

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
                  DropdownButtonFormField<XmlAction>(
                    value: selectedAction,
                    decoration: const InputDecoration(
                      labelText: '处理动作',
                      border: OutlineInputBorder(),
                    ),
                    items: XmlAction.values.map((action) {
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
                      final newRule = XmlRule(tagName: tagName, action: selectedAction);
                      notifier.updateSettings((chat) {
                        final rules = List<XmlRule>.from(chat.xmlRules);
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

    return PopScope(
      canPop: false, // 禁止默认的返回行为，由 onPopInvoked 控制
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return; // 如果已经 pop，则不执行任何操作

        // 在异步操作前捕获 context 相关的对象
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        final navigator = Navigator.of(context);

        try {
          await notifier.saveSettings();
        } catch (e) {
          // 在后台静默处理错误，或者使用日志库记录
          debugPrint('自动保存聊天设置失败: $e');
          // 可选：显示一个错误提示
          if (scaffoldMessenger.mounted) {
            scaffoldMessenger.showSnackBar(
              SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red),
            );
          }
        } finally {
          // 无论成功或失败，最后都返回上一页
          if (navigator.mounted) {
            navigator.pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
          shadows: <Shadow>[
            Shadow(color: Colors.black.withAlpha((255 * 0.5).round()), blurRadius: 1.0)
          ],
        ),
        title: Text(
          '聊天设置',
          style: TextStyle(
            shadows: <Shadow>[
              Shadow(color: Colors.black.withAlpha((255 * 0.5).round()), blurRadius: 1.0)
            ],
          ),
        ),
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
        const Divider(height: 30),
        _HelpMeReplySettings(chatId: chatId),
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

class _BasicInfoSettings extends ConsumerStatefulWidget {
  final int chatId;
  const _BasicInfoSettings({required this.chatId});

  @override
  ConsumerState<_BasicInfoSettings> createState() => _BasicInfoSettingsState();
}

class _BasicInfoSettingsState extends ConsumerState<_BasicInfoSettings> {
  late final TextEditingController _titleController;
  late final TextEditingController _systemPromptController;
  late final TextEditingController _continuePromptController;

  @override
  void initState() {
    super.initState();
    final chat = ref.read(chatSettingsProvider(widget.chatId)).chatForDisplay!;
    _titleController = TextEditingController(text: chat.title ?? '');
    _systemPromptController = TextEditingController(text: chat.systemPrompt ?? '');
    _continuePromptController = TextEditingController(text: chat.continuePrompt ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _systemPromptController.dispose();
    _continuePromptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(chatSettingsProvider(widget.chatId).notifier);

    // 监听来自 Provider 的外部变化（例如从全屏编辑器返回）
    // 并更新 controller 的文本，同时避免不必要的重建
    // NOTE: This was causing a bug where the last character could not be deleted.
    // The logic to update from full screen is handled directly in the `onPressed` callback.
    // The controller is the source of truth for user input.
    ref.watch(chatSettingsProvider(widget.chatId).select((s) => s.chatForDisplay!));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('基本信息'),
        const SizedBox(height: 15),
        TextFormField(
          controller: _titleController,
          decoration: const InputDecoration(labelText: '聊天标题', border: OutlineInputBorder()),
          onChanged: (value) {
            notifier.updateSettings((c) => c.copyWith(
              title: value.isEmpty ? null : value
            ));
          },
        ),
        const SizedBox(height: 15),
        TextFormField(
          controller: _systemPromptController,
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
                      initialText: _systemPromptController.text,
                      title: '编辑系统提示词',
                    ),
                  ),
                );
                if (newText != null) {
                  // 直接更新 controller 和 provider 状态
                  _systemPromptController.text = newText;
                  notifier.updateSettings((c) => c.copyWith(
                    systemPrompt: newText.isEmpty ? null : newText
                  ));
                }
              },
            ),
          ),
          maxLines: 4,
          minLines: 2,
          onChanged: (value) {
            notifier.updateSettings((c) => c.copyWith(
              systemPrompt: value.isEmpty ? null : value
            ));
          },
        ),
        const SizedBox(height: 15),
        TextFormField(
          controller: _continuePromptController,
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
                      initialText: _continuePromptController.text,
                      title: '编辑续写提示词',
                      defaultValue: defaultContinuePrompt,
                    ),
                  ),
                );
                if (newText != null) {
                  _continuePromptController.text = newText;
                  notifier.updateSettings((c) => c.copyWith(
                    continuePrompt: newText.isEmpty ? null : newText
                  ));
                }
              },
            ),
          ),
          maxLines: 4,
          minLines: 2,
          onChanged: (value) {
            notifier.updateSettings((c) => c.copyWith(
              continuePrompt: value.isEmpty ? null : value
            ));
          },
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

    // 修复：确保提供给 Dropdown 的项目列表中的值是唯一的，并且当前值有效。
    // 1. 通过 ID 去重，防止因重复 ID 导致断言失败。
    final uniqueApiConfigs = Map.fromEntries(apiConfigs.map((c) => MapEntry(c.id, c))).values.toList();
    // 2. 创建一个有效的 ID 集合，用于快速查找。
    final validConfigIds = uniqueApiConfigs.map((c) => c.id).toSet();
    // 3. 检查当前聊天的 apiConfigId 是否在有效列表中，如果不是，则设为 null 以避免崩溃。
    final safeApiConfigId = validConfigIds.contains(chat.apiConfigId) ? chat.apiConfigId : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('API 提供者'),
        const SizedBox(height: 15),
        if (uniqueApiConfigs.isEmpty)
          const Text('没有可用的 API 配置。请先在全局设置中添加。', style: TextStyle(color: Colors.orange))
        else
          DropdownButtonFormField<String?>(
            value: safeApiConfigId,
            decoration: InputDecoration(
              labelText: '聊天 API 配置',
              border: const OutlineInputBorder(),
              hintText: '默认: ${uniqueApiConfigs.first.name}',
            ),
            // 使用去重后的列表构建项目
            items: uniqueApiConfigs.map((config) => DropdownMenuItem(
              value: config.id,
              child: Text(config.name),
            )).toList(),
            onChanged: (value) {
              notifier.updateSettings((c) => c.copyWith(apiConfigId: value));
            },
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
        DropdownButtonFormField<ContextManagementMode>(
          value: contextConfig.mode,
          decoration: const InputDecoration(labelText: '上下文模式', border: OutlineInputBorder()),
          items: ContextManagementMode.values.map((mode) => DropdownMenuItem(
            value: mode,
            child: Text(mode == ContextManagementMode.turns ? '按轮数' : '按 Tokens (实验性)'),
          )).toList(),
          onChanged: (value) {
            if (value != null) {
              notifier.updateSettings((c) => c.copyWith(contextConfig: contextConfig.copyWith(mode: value)));
            }
          },
        ),
        const SizedBox(height: 15),
        if (contextConfig.mode == ContextManagementMode.turns)
          TextFormField(
            key: ValueKey('maxTurns_${chat.id}'),
            initialValue: contextConfig.maxTurns.toString(),
            decoration: const InputDecoration(labelText: '最大对话轮数', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
            onChanged: (value) => notifier.updateSettings((c) => c.copyWith(contextConfig: contextConfig.copyWith(maxTurns: int.tryParse(value) ?? 10))),
          ),
        if (contextConfig.mode == ContextManagementMode.tokens)
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
  final Function(XmlRule?, int?) onShowXmlRuleDialog;

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
                          final rules = List<XmlRule>.from(c.xmlRules)..removeAt(index);
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

class _AutomationSettings extends ConsumerStatefulWidget {
  final int chatId;
  const _AutomationSettings({required this.chatId});

  @override
  ConsumerState<_AutomationSettings> createState() => _AutomationSettingsState();
}

class _AutomationSettingsState extends ConsumerState<_AutomationSettings> {
  late final TextEditingController _preprocessingPromptController;
  late final TextEditingController _secondaryXmlPromptController;

  @override
  void initState() {
    super.initState();
    final chat = ref.read(chatSettingsProvider(widget.chatId)).chatForDisplay!;
    _preprocessingPromptController = TextEditingController(text: chat.preprocessingPrompt ?? '');
    _secondaryXmlPromptController = TextEditingController(text: chat.secondaryXmlPrompt ?? '');
  }

  @override
  void dispose() {
    _preprocessingPromptController.dispose();
    _secondaryXmlPromptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatSettingsProvider(widget.chatId).select((s) => s.chatForDisplay!));
    final notifier = ref.read(chatSettingsProvider(widget.chatId).notifier);
    final apiConfigs = ref.watch(apiKeyNotifierProvider.select((s) => s.apiConfigs));

    // 修复：确保下拉菜单数据源的健壮性
    final uniqueApiConfigs = Map.fromEntries(apiConfigs.map((c) => MapEntry(c.id, c))).values.toList();
    final validConfigIds = uniqueApiConfigs.map((c) => c.id).toSet();
 
    // The controller is the source of truth during user input.
    // The previous ref.listen was causing a bug where the last character could not be deleted.

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
              controller: _preprocessingPromptController,
              decoration: InputDecoration(
                labelText: '前处理提示词',
                hintText: defaultPreprocessingPrompt,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.fullscreen),
                  tooltip: '全屏编辑',
                  onPressed: () async {
                    final newText = await Navigator.of(context).push<String>(
                      MaterialPageRoute(
                        builder: (context) => FullScreenTextEditorScreen(
                          initialText: _preprocessingPromptController.text,
                          title: '编辑前处理提示词',
                          defaultValue: defaultPreprocessingPrompt,
                        ),
                      ),
                    );
                    if (newText != null) {
                      _preprocessingPromptController.text = newText;
                      notifier.updateSettings((c) => c.copyWith(
                        preprocessingPrompt: newText.isEmpty ? null : newText
                      ));
                    }
                  },
                ),
              ),
              maxLines: 3,
              minLines: 1,
              onChanged: (value) {
                notifier.updateSettings((c) => c.copyWith(
                  preprocessingPrompt: value.isEmpty ? null : value
                ));
              },
            ),
          ),
       if (chat.enablePreprocessing)
         Padding(
           padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: DropdownButtonFormField<String?>(
              value: validConfigIds.contains(chat.preprocessingApiConfigId) ? chat.preprocessingApiConfigId : null,
              decoration: InputDecoration(
                labelText: '用于总结的 API 配置',
                border: const OutlineInputBorder(),
                hintText: '默认: ${ _getEffectiveApiConfig(ref, chat, specificConfigId: chat.preprocessingApiConfigId)?.name ?? 'N/A'}'
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('使用聊天默认配置', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                ),
                ...uniqueApiConfigs.map((config) => DropdownMenuItem(
                  value: config.id,
                  child: Text(config.name),
                )),
              ],
              onChanged: (value) => notifier.updateSettings((c) => c.copyWith(preprocessingApiConfigId: value)),
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
              controller: _secondaryXmlPromptController,
              decoration: InputDecoration(
                labelText: '附加XML提示词',
                hintText: defaultSecondaryXmlPrompt,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.fullscreen),
                  tooltip: '全屏编辑',
                  onPressed: () async {
                    final newText = await Navigator.of(context).push<String>(
                      MaterialPageRoute(
                        builder: (context) => FullScreenTextEditorScreen(
                          initialText: _secondaryXmlPromptController.text,
                          title: '编辑附加XML提示词',
                          defaultValue: defaultSecondaryXmlPrompt,
                        ),
                      ),
                    );
                    if (newText != null) {
                      _secondaryXmlPromptController.text = newText;
                      notifier.updateSettings((c) => c.copyWith(
                        secondaryXmlPrompt: newText.isEmpty ? null : newText
                      ));
                    }
                  },
                ),
              ),
              maxLines: 3,
              minLines: 1,
              onChanged: (value) {
                notifier.updateSettings((c) => c.copyWith(
                  secondaryXmlPrompt: value.isEmpty ? null : value
                ));
              },
            ),
          ),
       if (chat.enableSecondaryXml)
         Padding(
           padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: DropdownButtonFormField<String?>(
              value: validConfigIds.contains(chat.secondaryXmlApiConfigId) ? chat.secondaryXmlApiConfigId : null,
              decoration: InputDecoration(
                labelText: '用于附加XML的 API 配置',
                border: const OutlineInputBorder(),
                hintText: '默认: ${_getEffectiveApiConfig(ref, chat, specificConfigId: chat.secondaryXmlApiConfigId)?.name ?? 'N/A'}'
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('使用聊天默认配置', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                ),
                ...uniqueApiConfigs.map((config) => DropdownMenuItem(
                  value: config.id,
                  child: Text(config.name),
                )),
              ],
              onChanged: (value) => notifier.updateSettings((c) => c.copyWith(secondaryXmlApiConfigId: value)),
            ),
         ),
      ],
    );
  }
}

class _HelpMeReplySettings extends ConsumerStatefulWidget {
  final int chatId;
  const _HelpMeReplySettings({required this.chatId});

  @override
  ConsumerState<_HelpMeReplySettings> createState() => _HelpMeReplySettingsState();
}

class _HelpMeReplySettingsState extends ConsumerState<_HelpMeReplySettings> {
  late final TextEditingController _promptController;

  @override
  void initState() {
    super.initState();
    final chat = ref.read(chatSettingsProvider(widget.chatId)).chatForDisplay!;
    _promptController = TextEditingController(text: chat.helpMeReplyPrompt ?? '');
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatSettingsProvider(widget.chatId).select((s) => s.chatForDisplay!));
    final notifier = ref.read(chatSettingsProvider(widget.chatId).notifier);
    final apiConfigs = ref.watch(apiKeyNotifierProvider.select((s) => s.apiConfigs));

    // 修复：确保下拉菜单数据源的健壮性
    final uniqueApiConfigs = Map.fromEntries(apiConfigs.map((c) => MapEntry(c.id, c))).values.toList();
    final validConfigIds = uniqueApiConfigs.map((c) => c.id).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('帮我回复'),
        const SizedBox(height: 10),
        SwitchListTile(
          title: const Text('启用“帮我回复”'),
          subtitle: const Text('根据对话上下文，生成多个回复选项'),
          value: chat.enableHelpMeReply,
          onChanged: (value) => notifier.updateSettings((c) => c.copyWith(enableHelpMeReply: value)),
        ),
        if (chat.enableHelpMeReply)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _promptController,
                  decoration: InputDecoration(
                    labelText: '“帮我回复”提示词',
                    hintText: defaultHelpMeReplyPrompt,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.fullscreen),
                      tooltip: '全屏编辑',
                      onPressed: () async {
                        final newText = await Navigator.of(context).push<String>(
                          MaterialPageRoute(
                            builder: (context) => FullScreenTextEditorScreen(
                              initialText: _promptController.text,
                              title: '编辑“帮我回复”提示词',
                              defaultValue: defaultHelpMeReplyPrompt,
                            ),
                          ),
                        );
                        if (newText != null) {
                          _promptController.text = newText;
                          notifier.updateSettings((c) => c.copyWith(
                            helpMeReplyPrompt: newText.isEmpty ? null : newText,
                          ));
                        }
                      },
                    ),
                  ),
                  maxLines: 3,
                  minLines: 1,
                  onChanged: (value) {
                    notifier.updateSettings((c) => c.copyWith(
                      helpMeReplyPrompt: value.isEmpty ? null : value,
                    ));
                  },
                ),
                const SizedBox(height: 15),
                if (apiConfigs.isEmpty)
                  const Text('没有可用的 API 配置。请先在全局设置中添加。', style: TextStyle(color: Colors.orange))
                else
                  DropdownButtonFormField<String?>(
                    value: validConfigIds.contains(chat.helpMeReplyApiConfigId) ? chat.helpMeReplyApiConfigId : null,
                    decoration: InputDecoration(
                      labelText: '用于“帮我回复”的 API 配置',
                      border: const OutlineInputBorder(),
                      hintText: '默认: ${_getEffectiveApiConfig(ref, chat, specificConfigId: chat.helpMeReplyApiConfigId)?.name ?? 'N/A'}',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('使用聊天默认配置', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                      ),
                      ...uniqueApiConfigs.map((config) => DropdownMenuItem(
                        value: config.id,
                        child: Text(config.name),
                      )),
                    ],
                    onChanged: (value) => notifier.updateSettings((c) => c.copyWith(helpMeReplyApiConfigId: value)),
                  ),
                const SizedBox(height: 15),
                Text('触发模式', style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 8),
                SegmentedButton<HelpMeReplyTriggerMode>(
                  segments: const [
                    ButtonSegment<HelpMeReplyTriggerMode>(value: HelpMeReplyTriggerMode.manual, label: Text('手动'), icon: Icon(Icons.touch_app_rounded)),
                    ButtonSegment<HelpMeReplyTriggerMode>(value: HelpMeReplyTriggerMode.auto, label: Text('自动'), icon: Icon(Icons.play_arrow_rounded)),
                  ],
                  selected: {chat.helpMeReplyTriggerMode},
                  onSelectionChanged: (newSelection) {
                    notifier.updateSettings((c) => c.copyWith(helpMeReplyTriggerMode: newSelection.first));
                  },
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

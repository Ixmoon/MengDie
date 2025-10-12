import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 导入模型、Provider 和仓库
import '../../domain/models/models.dart';
import '../../app/providers/api_key_provider.dart';
import '../../app/providers/chat_settings_provider.dart';
import '../../app/providers/chat_state_providers.dart';
import '../widgets/widget_utils.dart'; // 导入新的公用函数
import '../../app/providers/chat_state/chat_data_providers.dart';

// --- 默认提示词常量 ---
const String defaultContinuePrompt = '''
<system_command>
用户没有发送任何消息，你需要继续回复并拼接到上一次的回复中，请根据你上一次的回复继续延申并与上一次回复衔接自然。
</system_command>
''';
const String defaultPreprocessingPrompt = '''
<system_command>
你现在进入回忆思考模式，需要为你与用户之间的持续互动创建一份精确且结构化的上下文总结。这份总结是保持对话连贯性、记忆关键信息和高效推进后续任务的核心。该总结不会给用户或任何人看到，仅作为你自身参考之用，所以一切请以服务你自己为主要目标。
核心指令：
首次创建：若这是第一次生成总结，请全面回顾迄今为止的所有互动内容。
迭代更新：若需更新已有总结，请将 [上一份总结] 与 [新的互动内容] 无缝地融合成一份全新的、统一的总结。在更新时，请务必整合并精炼信息，将已过时或重要性降低的旧内容适度简化，以防止总结无限膨胀，同时确保核心信息和长期目标得以保留。
补充: 请包含对话中的关键内容的直接引文，以便明确关键事实、决策点和任何明确的用户偏好避免产生歧义。
你的总结可以参考以下的示例（仅供学习参考，请根据对话任务类型和具体任务调整，切勿照搬）：

# 示例1:

**1. 宏观背景 (Overall Context):**
*   **互动历程回顾 (Interaction History):** 高度概括你与用户互动的起点、关键转折点和总体目标。这部分旨在让任何接手者能迅速理解“你与用户是如何走到这一步的”。
*   **当前焦点 (Immediate Focus):** 详细描述在请求总结前，你与用户正在进行的具体任务、讨论的话题或处理的情境。

**2. 核心原则与框架 (Core Principles & Framework):**
*   列出所有指导你与用户互动的基础规则、关键假设、使用的模型或共同遵守的规范。这可以是技术栈、设计哲学、故事的世界观设定，或是沟通中的情感边界。

**3. 关键实体与要素 (Key Entities & Elements):**
*   枚举并描述互动中所有重要的“名词”。根据情境，这可以是人物、代码模块、文件、物品、地点、概念或反复出现的情感。
    - **[实体/要素 1]:**
        - **定义/描述:** 它的本质、作用和核心属性。
        - **当前状态:** 它最近的变化、所处的位置或相关的情绪状态。
    - **[实体/要素 2]:**
        - [...]

**4. 已达成的进展与共识 (Progress & Resolutions):**
*   记录已经解决的问题、完成的任务、达成的协议、澄清的误解或确认的事实。这部分是衡量你与用户进展的里程碑。

**5. 待办事项与未来方向 (Pending Goals & Next Steps):**
*   清晰地列出所有悬而未决的任务、未解的疑问、长期的目标或计划进行的下一步行动。
*   为保证准确性，在描述下一步计划时，可直接引用你与用户最近互动中的关键指令或意图。
    - **[待办事项 1]:** [描述任务详情，以及你与用户计划如何着手。]
    - **[潜在方向 2]:** [描述一个未来的可能性或需要进一步探索的领域。]

# 示例2:

**故事背景 (Story Context):** 用于无缝衔接故事的宏观与微观背景。
  1.  **故事主线回顾 (Main Plot Recap):** 高度概括故事的开端、发展和主要转折点，让读者能快速理解整个故事的脉络。
  2.  **当前情节焦点 (Current Plot Focus):** 详细描述总结前正在发生的事情。聚焦于最近的角色互动、所处的场景、面临的直接挑战或目标。

**核心设定与要素 (Core Settings & Elements):** 列出故事世界观、关键规则（如魔法体系、科技水平）、特殊物品、重要概念或反复出现的主题，这些是理解故事行为逻辑的基础。

**关键角色与地点 (Key Characters & Locations):** 枚举故事中的核心参与者和重要场景。
  - **[角色名1]:**
    - **简介:** 总结其核心动机、性格特点、关键能力以及与其他角色的关系。
    - **状态更新:** 记录其最近的行动、状态变化（如受伤、获得新能力/信息）或心理活动。
  - **[角色名2]:**
    - [...]
  - **[地点名1]:**
    - **简介:** 描述其特点、在故事中的作用以及其独特的氛围或规则。
    - **近期事件:** 概述最近在此发生的关键事件。
  - [...]

**已解决的冲突与谜团 (Resolved Conflicts & Mysteries):** 记录已被角色解决的挑战、战胜的敌人、揭开的谜底或完成的重要任务。这有助于追踪故事的进展和角色的成长。

**悬而未决的线索与未来走向 (Pending Clues & Future Directions):** 概述所有未解的谜题、隐藏的伏笔、角色的长期目标以及潜在的冲突。这部分是推动故事继续发展的钩子。对于后续步骤，可以引用最近的对话或行动来明确即将展开的情节。
  - **[线索/任务1]:** [详细描述，以及角色们计划如何应对]
  - **[潜在冲突2]:** [详细描述，以及预示其可能爆发的迹象]
  - [...]

# 示例3:

1. 先前的对话：
  [详细描述]
2. 当前工作：
  [详细描述]
3. 关键技术概念：
  - [概念1]
  - [概念2]
  - [...]
4. 相关文件和代码：
  - [文件名1]
	- [关于此文件重要性的摘要]
	- [对此文件所做更改的摘要（如有）]
	- [重要代码片段]
  - [文件名2]
	- [重要代码片段]
  - [...]
5. 问题解决：
  [详细描述]
6. 待办任务和后续步骤：
  - [任务1详情及后续步骤]
  - [任务2详情及后续步骤]
  - [...]

输出要求：请仅输出这份结构化的总结，不要附加任何额外的开场白、评论或解释。
</system_command>
''';
const String defaultSecondaryXmlPrompt = '''
<system_command>
对最新一轮对话进行总结，已有内容无需重复总结。
<summary>
 <round id="X">
  <!-- 每轮对话的概括 -->
 </round>
 <message id="X">
  <!-- 重要信息/线索/设定 -->
 </message>
 <goals id="X">
  <status>
  待进行/进行中/已完成<!-- 目标状态 -->
  </status>
  <goal>
   <!-- 你需要达成的目标。 -->
  </goal>
 </goals>
 <problem>
  <!-- 此处用于自纠自省，分析此轮输出不足,在之后需要及时纠正。也可以在此处添加改进建议 -->
 </problem>
</summary>
请仅输出这份结构化的总结，无需任何额外的开场白或解释。
</system_command>
''';
const String defaultHelpMeReplyPrompt = '''
<system_command>
参考你与用户间的过往对话，仿造用户的风格（也可以给出比用户更高质量的回复），代替用户发言或者回复，为用户设想三个不同的回复，并使用序号1. 2. 3.分别标注，单个回复中不要有任何换行符号。
请仅输出这份结构化的选项，无需任何额外的开场白或解释。
</system_command>
''';

// 本文件包含用于配置单个聊天会话设置的屏幕界面。

// --- 辅助方法：根据优先级解析有效的 API 配置 ---
ApiConfig? _getEffectiveApiConfig(
  WidgetRef ref,
  Chat chat, {
  String? specificConfigId,
}) {
  final allConfigs = ref.read(apiKeyNotifierProvider).apiConfigs;
  if (allConfigs.isEmpty) return null;

  final defaultConfig = allConfigs.first;

  // 检查 specificConfigId 是否有效
  if (specificConfigId != null) {
    final foundConfig = allConfigs.firstWhere(
      (c) => c.id == specificConfigId,
      orElse: () => defaultConfig,
    );
    return foundConfig;
  }

  // 检查聊天的主要 apiConfigId 是否有效
  if (chat.apiConfigId != null) {
    final foundConfig = allConfigs.firstWhere(
      (c) => c.id == chat.apiConfigId,
      orElse: () => defaultConfig,
    );
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
  void _showXmlRuleDialog(
    BuildContext context, {
    XmlRule? existingRule,
    int? ruleIndex,
  }) {
    final chatId = ref.read(activeChatIdProvider);
    if (chatId == null) return;
    final notifier = ref.read(chatSettingsProvider(chatId).notifier);
    final tagNameController = TextEditingController(
      text: existingRule?.tagName ?? '',
    );
    var selectedAction = existingRule?.action ?? XmlAction.collapsible;
    var ignoreInContext = existingRule?.ignoreInContext ?? false;

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
                    initialValue: selectedAction,
                    decoration: const InputDecoration(
                      labelText: 'UI 行为',
                      border: OutlineInputBorder(),
                    ),
                    items: XmlAction.values.map((action) {
                      String description;
                      switch (action) {
                        case XmlAction.collapsible:
                          description = '折叠 (默认)';
                          break;
                        case XmlAction.content:
                          description = '直接显示内容';
                          break;
                        case XmlAction.save:
                          description = '保存状态';
                          break;
                        case XmlAction.update:
                          description = '更新状态';
                          break;
                      }
                      return DropdownMenuItem(
                        value: action,
                        child: Text(description),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          selectedAction = value;
                          // LOGIC: If action is save or update, it cannot be ignored in context.
                          if (selectedAction == XmlAction.save ||
                              selectedAction == XmlAction.update) {
                            ignoreInContext = false;
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    title: const Text('在上下文中忽略'),
                    subtitle: const Text('此标签不会被包含在发送给模型的历史记录中'),
                    value: ignoreInContext,
                    // LOGIC: Disable checkbox if action is save or update.
                    onChanged:
                        (selectedAction == XmlAction.save ||
                            selectedAction == XmlAction.update)
                        ? null
                        : (bool? value) {
                            setDialogState(() {
                              ignoreInContext = value ?? false;
                            });
                          },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () {
                    final tagName = tagNameController.text.trim();
                    if (tagName.isNotEmpty) {
                      // Final check to ensure logic consistency before saving
                      final bool finalIgnoreInContext =
                          (selectedAction == XmlAction.save ||
                              selectedAction == XmlAction.update)
                          ? false
                          : ignoreInContext;

                      final newRule = XmlRule(
                        tagName: tagName,
                        action: selectedAction,
                        ignoreInContext: finalIgnoreInContext,
                      );
                      notifier.updateSettings((chat) {
                        final rules = List<XmlRule>.from(chat.xmlRules);
                        if (ruleIndex != null) {
                          rules[ruleIndex] = newRule;
                        } else {
                          if (!rules.any(
                            (r) =>
                                r.tagName?.toLowerCase() ==
                                tagName.toLowerCase(),
                          )) {
                            rules.add(newRule);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('该标签名称的规则已存在'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return chat; // No change
                          }
                        }
                        return chat.copyWith(xmlRules: rules);
                      });
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('标签名称不能为空'),
                          backgroundColor: Colors.red,
                        ),
                      );
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
              Shadow(
                color: Colors.black.withAlpha((255 * 0.5).round()),
                blurRadius: 1.0,
              ),
            ],
          ),
          title: Text(
            '聊天设置',
            style: TextStyle(
              shadows: <Shadow>[
                Shadow(
                  color: Colors.black.withAlpha((255 * 0.5).round()),
                  blurRadius: 1.0,
                ),
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

  Widget _buildMainSettingsForm(
    BuildContext context,
    WidgetRef ref,
    Chat chat,
    int chatId,
  ) {
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
          onShowXmlRuleDialog: (rule, index) =>
              _showXmlRuleDialog(context, existingRule: rule, ruleIndex: index),
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
    _systemPromptController = TextEditingController(
      text: chat.systemPrompt ?? '',
    );
    _continuePromptController = TextEditingController(
      text: chat.continuePrompt ?? '',
    );
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
    ref.watch(
      chatSettingsProvider(widget.chatId).select((s) => s.chatForDisplay!),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('基本信息'),
        const SizedBox(height: 15),
        TextFormField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: '聊天标题',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            notifier.updateSettings(
              (c) => c.copyWith(title: value.isEmpty ? null : value),
            );
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
                final newText = await showFullScreenTextEditor(
                  context,
                  initialText: _systemPromptController.text,
                  title: '编辑系统提示词',
                );
                if (newText != null) {
                  _systemPromptController.text = newText;
                  notifier.updateSettings(
                    (c) => c.copyWith(
                      systemPrompt: newText.isEmpty ? null : newText,
                    ),
                  );
                }
              },
            ),
          ),
          maxLines: 4,
          minLines: 2,
          onChanged: (value) {
            notifier.updateSettings(
              (c) => c.copyWith(systemPrompt: value.isEmpty ? null : value),
            );
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
                final newText = await showFullScreenTextEditor(
                  context,
                  initialText: _continuePromptController.text,
                  title: '编辑续写提示词',
                  defaultValue: defaultContinuePrompt,
                );
                if (newText != null) {
                  _continuePromptController.text = newText;
                  notifier.updateSettings(
                    (c) => c.copyWith(
                      continuePrompt: newText.isEmpty ? null : newText,
                    ),
                  );
                }
              },
            ),
          ),
          maxLines: 4,
          minLines: 2,
          onChanged: (value) {
            notifier.updateSettings(
              (c) => c.copyWith(continuePrompt: value.isEmpty ? null : value),
            );
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
    final chat = ref.watch(
      chatSettingsProvider(chatId).select((s) => s.chatForDisplay!),
    );
    final notifier = ref.read(chatSettingsProvider(chatId).notifier);
    final apiConfigs = ref.watch(
      apiKeyNotifierProvider.select((s) => s.apiConfigs),
    );

    // 修复：确保提供给 Dropdown 的项目列表中的值是唯一的，并且当前值有效。
    // 1. 通过 ID 去重，防止因重复 ID 导致断言失败。
    final uniqueApiConfigs = Map.fromEntries(
      apiConfigs.map((c) => MapEntry(c.id, c)),
    ).values.toList();
    // 2. 创建一个有效的 ID 集合，用于快速查找。
    final validConfigIds = uniqueApiConfigs.map((c) => c.id).toSet();
    // 3. 检查当前聊天的 apiConfigId 是否在有效列表中，如果不是，则设为 null 以避免崩溃。
    final safeApiConfigId = validConfigIds.contains(chat.apiConfigId)
        ? chat.apiConfigId
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('API 提供者'),
        const SizedBox(height: 15),
        if (uniqueApiConfigs.isEmpty)
          const Text(
            '没有可用的 API 配置。请先在全局设置中添加。',
            style: TextStyle(color: Colors.orange),
          )
        else
          DropdownButtonFormField<String?>(
            initialValue: safeApiConfigId,
            decoration: InputDecoration(
              labelText: '聊天 API 配置',
              border: const OutlineInputBorder(),
              hintText: '默认: ${uniqueApiConfigs.first.name}',
            ),
            // 使用去重后的列表构建项目
            items: uniqueApiConfigs
                .map(
                  (config) => DropdownMenuItem(
                    value: config.id,
                    child: Text(config.name),
                  ),
                )
                .toList(),
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
    final chat = ref.watch(
      chatSettingsProvider(chatId).select((s) => s.chatForDisplay!),
    );
    final notifier = ref.read(chatSettingsProvider(chatId).notifier);
    final contextConfig = chat.contextConfig;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('上下文管理'),
        const SizedBox(height: 15),
        DropdownButtonFormField<ContextManagementMode>(
          initialValue: contextConfig.mode,
          decoration: const InputDecoration(
            labelText: '上下文模式',
            border: OutlineInputBorder(),
          ),
          items: ContextManagementMode.values
              .map(
                (mode) => DropdownMenuItem(
                  value: mode,
                  child: Text(
                    mode == ContextManagementMode.turns
                        ? '按轮数'
                        : '按 Tokens (实验性)',
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              notifier.updateSettings(
                (c) => c.copyWith(
                  contextConfig: contextConfig.copyWith(mode: value),
                ),
              );
            }
          },
        ),
        const SizedBox(height: 15),
        if (contextConfig.mode == ContextManagementMode.turns)
          TextFormField(
            key: ValueKey('maxTurns_${chat.id}'),
            initialValue: contextConfig.maxTurns.toString(),
            decoration: const InputDecoration(
              labelText: '最大对话轮数',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) => notifier.updateSettings(
              (c) => c.copyWith(
                contextConfig: contextConfig.copyWith(
                  maxTurns: int.tryParse(value) ?? 10,
                ),
              ),
            ),
          ),
        if (contextConfig.mode == ContextManagementMode.tokens)
          Column(
            children: [
              TextFormField(
                key: ValueKey('maxTokens_${chat.id}'),
                initialValue: contextConfig.maxContextTokens?.toString() ?? '',
                decoration: const InputDecoration(
                  labelText: '最大 Tokens (可选)',
                  hintText: '留空则不限制',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) => notifier.updateSettings(
                  (c) => c.copyWith(
                    contextConfig: contextConfig.copyWith(
                      maxContextTokens: int.tryParse(value),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              TextFormField(
                key: ValueKey('predictedTokens_${chat.id}'),
                initialValue:
                    contextConfig.predictedTurnTokens?.toString() ?? '2048',
                decoration: const InputDecoration(
                  labelText: '预测回合 Tokens',
                  hintText: '用于后台总结的预测值',
                  border: OutlineInputBorder(),
                  helperText: '后台任务会用此值预测未来消耗，以提前触发总结。',
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) => notifier.updateSettings(
                  (c) => c.copyWith(
                    contextConfig: contextConfig.copyWith(
                      predictedTurnTokens: int.tryParse(value) ?? 2048,
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _XmlRulesSettings extends ConsumerWidget {
  final int chatId;
  final Function(XmlRule?, int?) onShowXmlRuleDialog;

  const _XmlRulesSettings({
    required this.chatId,
    required this.onShowXmlRuleDialog,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(
      chatSettingsProvider(chatId).select((s) => s.chatForDisplay!),
    );
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
            ),
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
                subtitle: Text(
                  'UI: ${rule.action.name} / 上下文: ${rule.ignoreInContext ? "忽略" : "包含"}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      tooltip: '编辑规则',
                      onPressed: () => onShowXmlRuleDialog(rule, index),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: Colors.redAccent,
                      ),
                      tooltip: '删除规则',
                      onPressed: () {
                        notifier.updateSettings((c) {
                          final rules = List<XmlRule>.from(c.xmlRules)
                            ..removeAt(index);
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
  ConsumerState<_AutomationSettings> createState() =>
      _AutomationSettingsState();
}

class _AutomationSettingsState extends ConsumerState<_AutomationSettings> {
  late final TextEditingController _preprocessingPromptController;
  late final TextEditingController _secondaryXmlPromptController;

  @override
  void initState() {
    super.initState();
    final chat = ref.read(chatSettingsProvider(widget.chatId)).chatForDisplay!;
    _preprocessingPromptController = TextEditingController(
      text: chat.preprocessingPrompt ?? '',
    );
    _secondaryXmlPromptController = TextEditingController(
      text: chat.secondaryXmlPrompt ?? '',
    );
  }

  @override
  void dispose() {
    _preprocessingPromptController.dispose();
    _secondaryXmlPromptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(
      chatSettingsProvider(widget.chatId).select((s) => s.chatForDisplay!),
    );
    final notifier = ref.read(chatSettingsProvider(widget.chatId).notifier);
    final apiConfigs = ref.watch(
      apiKeyNotifierProvider.select((s) => s.apiConfigs),
    );

    // 修复：确保下拉菜单数据源的健壮性
    final uniqueApiConfigs = Map.fromEntries(
      apiConfigs.map((c) => MapEntry(c.id, c)),
    ).values.toList();
    final validConfigIds = uniqueApiConfigs.map((c) => c.id).toSet();

    // The controller is the source of truth during user input.
    // The previous ref.listen was causing a bug where the last character could not be deleted.

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('自动化处理'),
        const SizedBox(height: 10),
        SwitchListTile(
          title: const Text('启用上下文总结'),
          subtitle: const Text('在回复后，对被遗忘的旧消息进行总结'),
          value: chat.enablePreprocessing,
          onChanged: (value) => notifier.updateSettings(
            (c) => c.copyWith(enablePreprocessing: value),
          ),
        ),
        if (chat.enablePreprocessing)
          Padding(
            padding: const EdgeInsets.only(
              top: 8.0,
              left: 16.0,
              right: 16.0,
              bottom: 16.0,
            ),
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
                    final newText = await showFullScreenTextEditor(
                      context,
                      initialText: _preprocessingPromptController.text,
                      title: '编辑前处理提示词',
                      defaultValue: defaultPreprocessingPrompt,
                    );
                    if (newText != null) {
                      _preprocessingPromptController.text = newText;
                      notifier.updateSettings(
                        (c) => c.copyWith(
                          preprocessingPrompt: newText.isEmpty ? null : newText,
                        ),
                      );
                    }
                  },
                ),
              ),
              maxLines: 3,
              minLines: 1,
              onChanged: (value) {
                notifier.updateSettings(
                  (c) => c.copyWith(
                    preprocessingPrompt: value.isEmpty ? null : value,
                  ),
                );
              },
            ),
          ),
        if (chat.enablePreprocessing)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: DropdownButtonFormField<String?>(
              initialValue:
                  validConfigIds.contains(chat.preprocessingApiConfigId)
                  ? chat.preprocessingApiConfigId
                  : null,
              decoration: InputDecoration(
                labelText: '用于总结的 API 配置',
                border: const OutlineInputBorder(),
                hintText:
                    '默认: ${_getEffectiveApiConfig(ref, chat, specificConfigId: chat.preprocessingApiConfigId)?.name ?? 'N/A'}',
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    '使用聊天默认配置',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ),
                ...uniqueApiConfigs.map(
                  (config) => DropdownMenuItem(
                    value: config.id,
                    child: Text(config.name),
                  ),
                ),
              ],
              onChanged: (value) => notifier.updateSettings(
                (c) => c.copyWith(preprocessingApiConfigId: value),
              ),
            ),
          ),
        SwitchListTile(
          title: const Text('启用再生XML合并计算'),
          subtitle: const Text('开启后将合并计算再生XML。关闭后仅生成并存储，不参与计算。'),
          value: chat.enableSecondaryXml,
          onChanged: (chat.secondaryXmlPrompt?.isEmpty ?? true)
              ? null
              : (value) => notifier.updateSettings(
                    (c) => c.copyWith(enableSecondaryXml: value),
                  ),
        ),
        if (chat.enableSecondaryXml)
          Padding(
            padding: const EdgeInsets.only(
              top: 8.0,
              left: 16.0,
              right: 16.0,
              bottom: 8.0,
            ),
            child: TextFormField(
              controller: _secondaryXmlPromptController,
              decoration: InputDecoration(
                labelText: '再生XML提示词',
                hintText: defaultSecondaryXmlPrompt,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.fullscreen),
                  tooltip: '全屏编辑',
                  onPressed: () async {
                    final newText = await showFullScreenTextEditor(
                      context,
                      initialText: _secondaryXmlPromptController.text,
                      title: '编辑原生XML提示词',
                      defaultValue: defaultSecondaryXmlPrompt,
                    );
                    if (newText != null) {
                      _secondaryXmlPromptController.text = newText;
                      notifier.updateSettings(
                        (c) => c.copyWith(
                          secondaryXmlPrompt: newText.isEmpty ? null : newText,
                        ),
                      );
                    }
                  },
                ),
              ),
              maxLines: 3,
              minLines: 1,
              onChanged: (value) {
                notifier.updateSettings(
                  (c) => c.copyWith(
                    secondaryXmlPrompt: value.isEmpty ? null : value,
                  ),
                );
              },
            ),
          ),
        if (chat.enableSecondaryXml)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: DropdownButtonFormField<String?>(
              initialValue:
                  validConfigIds.contains(chat.secondaryXmlApiConfigId)
                  ? chat.secondaryXmlApiConfigId
                  : null,
              decoration: InputDecoration(
                labelText: '用于再生XML的 API 配置',
                border: const OutlineInputBorder(),
                hintText:
                    '默认: ${_getEffectiveApiConfig(ref, chat, specificConfigId: chat.secondaryXmlApiConfigId)?.name ?? 'N/A'}',
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    '使用聊天默认配置',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ),
                ...uniqueApiConfigs.map(
                  (config) => DropdownMenuItem(
                    value: config.id,
                    child: Text(config.name),
                  ),
                ),
              ],
              onChanged: (value) => notifier.updateSettings(
                (c) => c.copyWith(secondaryXmlApiConfigId: value),
              ),
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
  ConsumerState<_HelpMeReplySettings> createState() =>
      _HelpMeReplySettingsState();
}

class _HelpMeReplySettingsState extends ConsumerState<_HelpMeReplySettings> {
  late final TextEditingController _promptController;

  @override
  void initState() {
    super.initState();
    final chat = ref.read(chatSettingsProvider(widget.chatId)).chatForDisplay!;
    _promptController = TextEditingController(
      text: chat.helpMeReplyPrompt ?? '',
    );
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(
      chatSettingsProvider(widget.chatId).select((s) => s.chatForDisplay!),
    );
    final notifier = ref.read(chatSettingsProvider(widget.chatId).notifier);
    final apiConfigs = ref.watch(
      apiKeyNotifierProvider.select((s) => s.apiConfigs),
    );

    // 修复：确保下拉菜单数据源的健壮性
    final uniqueApiConfigs = Map.fromEntries(
      apiConfigs.map((c) => MapEntry(c.id, c)),
    ).values.toList();
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
          onChanged: (value) => notifier.updateSettings(
            (c) => c.copyWith(enableHelpMeReply: value),
          ),
        ),
        if (chat.enableHelpMeReply)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
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
                      tooltip: '全��编辑',
                      onPressed: () async {
                        final newText = await showFullScreenTextEditor(
                          context,
                          initialText: _promptController.text,
                          title: '编辑“帮我回复”提示词',
                          defaultValue: defaultHelpMeReplyPrompt,
                        );
                        if (newText != null) {
                          _promptController.text = newText;
                          notifier.updateSettings(
                            (c) => c.copyWith(
                              helpMeReplyPrompt: newText.isEmpty
                                  ? null
                                  : newText,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  maxLines: 3,
                  minLines: 1,
                  onChanged: (value) {
                    notifier.updateSettings(
                      (c) => c.copyWith(
                        helpMeReplyPrompt: value.isEmpty ? null : value,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 15),
                if (apiConfigs.isEmpty)
                  const Text(
                    '没有可用的 API 配置。请先在全局设置中添加。',
                    style: TextStyle(color: Colors.orange),
                  )
                else
                  DropdownButtonFormField<String?>(
                    initialValue:
                        validConfigIds.contains(chat.helpMeReplyApiConfigId)
                        ? chat.helpMeReplyApiConfigId
                        : null,
                    decoration: InputDecoration(
                      labelText: '用于“帮我回复”的 API 配置',
                      border: const OutlineInputBorder(),
                      hintText:
                          '默认: ${_getEffectiveApiConfig(ref, chat, specificConfigId: chat.helpMeReplyApiConfigId)?.name ?? 'N/A'}',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          '使用聊天默认配置',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      ...uniqueApiConfigs.map(
                        (config) => DropdownMenuItem(
                          value: config.id,
                          child: Text(config.name),
                        ),
                      ),
                    ],
                    onChanged: (value) => notifier.updateSettings(
                      (c) => c.copyWith(helpMeReplyApiConfigId: value),
                    ),
                  ),
                const SizedBox(height: 15),
                Text('触发模式', style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 8),
                SegmentedButton<HelpMeReplyTriggerMode>(
                  segments: const [
                    ButtonSegment<HelpMeReplyTriggerMode>(
                      value: HelpMeReplyTriggerMode.manual,
                      label: Text('手动'),
                      icon: Icon(Icons.touch_app_rounded),
                    ),
                    ButtonSegment<HelpMeReplyTriggerMode>(
                      value: HelpMeReplyTriggerMode.auto,
                      label: Text('自动'),
                      icon: Icon(Icons.play_arrow_rounded),
                    ),
                  ],
                  selected: {chat.helpMeReplyTriggerMode},
                  onSelectionChanged: (newSelection) {
                    notifier.updateSettings(
                      (c) => c.copyWith(
                        helpMeReplyTriggerMode: newSelection.first,
                      ),
                    );
                  },
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/settings_providers.dart';
import '../models/enums.dart';
import '../providers/api_key_provider.dart';
import '../data/database/drift/app_database.dart';
import '../widgets/fullscreen_text_editor.dart'; // 导入全屏文本编辑器
 
 
class GlobalSettingsScreen extends ConsumerWidget {
  const GlobalSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('全局设置')),
      body: GestureDetector(
         onTap: () => FocusScope.of(context).unfocus(),
         child: Padding(
           padding: const EdgeInsets.all(16.0),
           child: ListView(
             children: [
                Text('应用主题', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                Consumer(
                  builder: (context, ref, child) {
                    final currentThemeMode = ref.watch(themeModeProvider);
                    final themeModeNotifier = ref.read(themeModeProvider.notifier);

                    return DropdownButtonFormField<ThemeModeSetting>(
                      value: currentThemeMode,
                      decoration: const InputDecoration(
                        labelText: '选择主题模式',
                        border: OutlineInputBorder(),
                      ),
                      items: ThemeModeSetting.values.map((ThemeModeSetting mode) {
                        String modeText;
                        switch (mode) {
                          case ThemeModeSetting.system:
                            modeText = '跟随系统';
                            break;
                          case ThemeModeSetting.light:
                            modeText = '浅色模式';
                            break;
                          case ThemeModeSetting.dark:
                            modeText = '深色模式';
                            break;
                        }
                        return DropdownMenuItem<ThemeModeSetting>(
                          value: mode,
                          child: Text(modeText),
                        );
                      }).toList(),
                      onChanged: (ThemeModeSetting? newValue) {
                        if (newValue != null) {
                          themeModeNotifier.setThemeMode(newValue);
                        }
                      },
                    );
                  }
                ),
                const Divider(height: 30),

                Text('API 配置', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(Icons.key),
                  title: const Text('Gemini API Keys'),
                  subtitle: const Text('管理全局 Gemini API 密钥池'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () => context.push('/settings/gemini-api-keys'),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(Icons.settings_ethernet_rounded),
                  title: const Text('API 配置管理'),
                  subtitle: const Text('管理所有 API 配置 (Gemini, OpenAI 等)'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () {
                    context.push('/settings/api-configs');
                  },
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const Divider(height: 30),

               Text('自动化', style: Theme.of(context).textTheme.titleLarge),
               const SizedBox(height: 10),
               _buildFeatureSettings(
                 context: context,
                 ref: ref,
                 title: '自动生成聊天标题',
                 subtitle: '在首次回复后，自动为新聊天生成标题',
                 icon: Icons.title,
                 isEnabled: ref.watch(globalSettingsProvider.select((s) => s.enableAutoTitleGeneration)),
                 prompt: ref.watch(globalSettingsProvider.select((s) => s.titleGenerationPrompt)),
                 apiConfigId: ref.watch(globalSettingsProvider.select((s) => s.titleGenerationApiConfigId)),
                 onEnableChanged: (value) {
                   final notifier = ref.read(globalSettingsProvider.notifier);
                   notifier.updateSettings(ref.read(globalSettingsProvider).copyWith(enableAutoTitleGeneration: value));
                 },
                 onPromptChanged: (value) {
                   final notifier = ref.read(globalSettingsProvider.notifier);
                   notifier.updateSettings(ref.read(globalSettingsProvider).copyWith(titleGenerationPrompt: value));
                 },
                 onApiConfigChanged: (value) {
                   final notifier = ref.read(globalSettingsProvider.notifier);
                   notifier.updateSettings(ref.read(globalSettingsProvider).copyWith(titleGenerationApiConfigId: value, clearTitleGenerationApiConfigId: value == null));
                 },
               ),
               const Divider(height: 30),
                _buildFeatureSettings(
                  context: context,
                  ref: ref,
                  title: '中断恢复',
                  subtitle: '当模型消息中断时，提供恢复按钮',
                  icon: Icons.replay_circle_filled_rounded,
                  isEnabled: ref.watch(globalSettingsProvider.select((s) => s.enableResume)),
                  prompt: ref.watch(globalSettingsProvider.select((s) => s.resumePrompt)),
                  apiConfigId: ref.watch(globalSettingsProvider.select((s) => s.resumeApiConfigId)),
                  onEnableChanged: (value) {
                    final notifier = ref.read(globalSettingsProvider.notifier);
                    notifier.updateSettings(ref.read(globalSettingsProvider).copyWith(enableResume: value));
                  },
                  onPromptChanged: (value) {
                    final notifier = ref.read(globalSettingsProvider.notifier);
                    notifier.updateSettings(ref.read(globalSettingsProvider).copyWith(resumePrompt: value));
                  },
                  onApiConfigChanged: (value) {
                    final notifier = ref.read(globalSettingsProvider.notifier);
                    notifier.updateSettings(ref.read(globalSettingsProvider).copyWith(resumeApiConfigId: value, clearResumeApiConfigId: value == null));
                  },
                ),
               const Divider(height: 30),
                _buildFeatureSettings(
                  context: context,
                  ref: ref,
                  title: '帮我回复',
                  subtitle: '根据对话上下文，生成多个回复选项',
                  icon: Icons.quickreply_rounded,
                  isEnabled: ref.watch(globalSettingsProvider.select((s) => s.enableHelpMeReply)),
                  prompt: ref.watch(globalSettingsProvider.select((s) => s.helpMeReplyPrompt)),
                  apiConfigId: ref.watch(globalSettingsProvider.select((s) => s.helpMeReplyApiConfigId)),
                  onEnableChanged: (value) {
                    final notifier = ref.read(globalSettingsProvider.notifier);
                    notifier.updateSettings(ref.read(globalSettingsProvider).copyWith(enableHelpMeReply: value));
                  },
                  onPromptChanged: (value) {
                    final notifier = ref.read(globalSettingsProvider.notifier);
                    notifier.updateSettings(ref.read(globalSettingsProvider).copyWith(helpMeReplyPrompt: value));
                  },
                  onApiConfigChanged: (value) {
                    final notifier = ref.read(globalSettingsProvider.notifier);
                    notifier.updateSettings(ref.read(globalSettingsProvider).copyWith(helpMeReplyApiConfigId: value, clearHelpMeReplyApiConfigId: value == null));
                  },
                  additionalWidgets: [
                    const SizedBox(height: 15),
                    Text('触发模式', style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment<String>(value: 'manual', label: Text('手动'), icon: Icon(Icons.touch_app_rounded)),
                        ButtonSegment<String>(value: 'auto', label: Text('自动'), icon: Icon(Icons.play_arrow_rounded)),
                      ],
                      selected: {ref.watch(globalSettingsProvider.select((s) => s.helpMeReplyTriggerMode))},
                      onSelectionChanged: (newSelection) {
                        final notifier = ref.read(globalSettingsProvider.notifier);
                        notifier.updateSettings(ref.read(globalSettingsProvider).copyWith(helpMeReplyTriggerMode: newSelection.first));
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
             ],
           ),
         ),
       ),
    );
  }

 Widget _buildFeatureSettings({
  required BuildContext context,
  required WidgetRef ref,
  required String title,
  required String subtitle,
  required IconData icon,
  required bool isEnabled,
  required String prompt,
  required String? apiConfigId,
  required ValueChanged<bool> onEnableChanged,
  required ValueChanged<String> onPromptChanged,
  required ValueChanged<String?> onApiConfigChanged,
  List<Widget>? additionalWidgets,
}) {
   final apiConfigs = ref.watch(apiKeyNotifierProvider.select((s) => s.apiConfigs));

   return Column(
     crossAxisAlignment: CrossAxisAlignment.start,
     children: [
       SwitchListTile(
         title: Text(title),
         subtitle: Text(subtitle),
         value: isEnabled,
         onChanged: onEnableChanged,
         secondary: Icon(icon),
         contentPadding: EdgeInsets.zero,
       ),
       if (isEnabled) ...[
         const SizedBox(height: 15),
         TextFormField(
           initialValue: prompt,
           // Use a key to force rebuild when switching between features
           key: ValueKey('prompt_$title'),
           decoration: InputDecoration(
             labelText: '提示词',
             border: const OutlineInputBorder(),
             contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
             suffixIcon: IconButton(
               icon: const Icon(Icons.fullscreen),
               tooltip: '全屏编辑',
               onPressed: () async {
                 final newText = await Navigator.of(context).push<String>(
                   MaterialPageRoute(
                     builder: (context) => FullScreenTextEditorScreen(
                       initialText: prompt,
                       title: '编辑 $title 的提示词',
                     ),
                   ),
                 );
                 if (newText != null) {
                   onPromptChanged(newText);
                 }
               },
             ),
           ),
           maxLines: 3,
           minLines: 1,
           onChanged: onPromptChanged,
         ),
         const SizedBox(height: 15),
         if (apiConfigs.isEmpty)
           const Text('没有可用的 API 配置。请先在 API 配置管理中添加。', style: TextStyle(color: Colors.orange))
         else
           DropdownButtonFormField<String>(
             value: apiConfigs.any((c) => c.id == apiConfigId) ? apiConfigId : null,
             decoration: const InputDecoration(labelText: '使用的 API 配置', border: OutlineInputBorder()),
             items: [
               const DropdownMenuItem<String>(
                 value: null,
                 child: Text('使用聊天默认配置'),
               ),
               ...apiConfigs.map((ApiConfig config) {
                 return DropdownMenuItem<String>(
                   value: config.id,
                   child: Text(config.name),
                 );
               }),
             ],
             onChanged: onApiConfigChanged,
           ),
         if (additionalWidgets != null) ...additionalWidgets,
       ],
     ],
   );
 }
}

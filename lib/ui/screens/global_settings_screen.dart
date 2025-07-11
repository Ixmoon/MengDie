import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/settings_providers.dart';
import '../../data/models/api_config.dart';
import '../providers/api_key_provider.dart';
import '../widgets/fullscreen_text_editor.dart'; // 导入全屏文本编辑器
import '../../data/models/enums.dart';
 
 
class GlobalSettingsScreen extends ConsumerWidget {
  const GlobalSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          '全局设置',
          style: TextStyle(
            shadows: <Shadow>[
              Shadow(color: Colors.black.withAlpha((255 * 0.5).round()), blurRadius: 1.0)
            ],
          ),
        ),
      ),
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
               _FeatureSettingsWidget(
                 title: '自动生成聊天标题',
                 subtitle: '在首次回复后，自动为新聊天生成标题',
                 icon: Icons.title,
                 isEnabled: ref.watch(globalSettingsProvider.select((s) => s.enableAutoTitleGeneration)),
                 prompt: ref.watch(globalSettingsProvider.select((s) => s.titleGenerationPrompt)),
                 apiConfigId: ref.watch(globalSettingsProvider.select((s) => s.titleGenerationApiConfigId)),
                 onEnableChanged: (value) {
                   final notifier = ref.read(globalSettingsProvider.notifier);
                   notifier.updateSettings(ref.read(globalSettingsProvider).copyWith({'enableAutoTitleGeneration': value}));
                 },
                 onPromptChanged: (value) {
                   final notifier = ref.read(globalSettingsProvider.notifier);
                   notifier.updateSettings(ref.read(globalSettingsProvider).copyWith({
                     'titleGenerationPrompt': value,
                   }));
                 },
                 onApiConfigChanged: (value) {
                   final notifier = ref.read(globalSettingsProvider.notifier);
                   notifier.updateSettings(ref.read(globalSettingsProvider).copyWith({'titleGenerationApiConfigId': value}));
                 },
               ),
               const Divider(height: 30),
                _FeatureSettingsWidget(
                  title: '中断恢复',
                  subtitle: '当模型消息中断时，提供恢复按钮',
                  icon: Icons.replay_circle_filled_rounded,
                  isEnabled: ref.watch(globalSettingsProvider.select((s) => s.enableResume)),
                  prompt: ref.watch(globalSettingsProvider.select((s) => s.resumePrompt)),
                  apiConfigId: ref.watch(globalSettingsProvider.select((s) => s.resumeApiConfigId)),
                  onEnableChanged: (value) {
                    final notifier = ref.read(globalSettingsProvider.notifier);
                    notifier.updateSettings(ref.read(globalSettingsProvider).copyWith({'enableResume': value}));
                  },
                  onPromptChanged: (value) {
                    final notifier = ref.read(globalSettingsProvider.notifier);
                    notifier.updateSettings(ref.read(globalSettingsProvider).copyWith({
                      'resumePrompt': value,
                    }));
                  },
                  onApiConfigChanged: (value) {
                    final notifier = ref.read(globalSettingsProvider.notifier);
                    notifier.updateSettings(ref.read(globalSettingsProvider).copyWith({'resumeApiConfigId': value}));
                  },
                ),
                const Divider(height: 30),
                 _FeatureSettingsWidget(
                   title: '帮我回复',
                  subtitle: '根据对话上下文，生成多个回复选项',
                  icon: Icons.quickreply_rounded,
                  isEnabled: ref.watch(globalSettingsProvider.select((s) => s.enableHelpMeReply)),
                  prompt: ref.watch(globalSettingsProvider.select((s) => s.helpMeReplyPrompt)),
                  apiConfigId: ref.watch(globalSettingsProvider.select((s) => s.helpMeReplyApiConfigId)),
                  onEnableChanged: (value) {
                    final notifier = ref.read(globalSettingsProvider.notifier);
                    notifier.updateSettings(ref.read(globalSettingsProvider).copyWith({'enableHelpMeReply': value}));
                  },
                  onPromptChanged: (value) {
                    final notifier = ref.read(globalSettingsProvider.notifier);
                    notifier.updateSettings(ref.read(globalSettingsProvider).copyWith({
                      'helpMeReplyPrompt': value,
                    }));
                  },
                  onApiConfigChanged: (value) {
                    final notifier = ref.read(globalSettingsProvider.notifier);
                    notifier.updateSettings(ref.read(globalSettingsProvider).copyWith({'helpMeReplyApiConfigId': value}));
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
                        notifier.updateSettings(ref.read(globalSettingsProvider).copyWith({'helpMeReplyTriggerMode': newSelection.first}));
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
 }
 
 class _FeatureSettingsWidget extends ConsumerStatefulWidget {
   final String title;
   final String subtitle;
   final IconData icon;
   final bool isEnabled;
   final String prompt;
   final String? apiConfigId;
   final ValueChanged<bool> onEnableChanged;
   final ValueChanged<String> onPromptChanged;
   final ValueChanged<String?> onApiConfigChanged;
   final List<Widget>? additionalWidgets;
 
   const _FeatureSettingsWidget({
     required this.title,
     required this.subtitle,
     required this.icon,
     required this.isEnabled,
     required this.prompt,
     this.apiConfigId,
     required this.onEnableChanged,
     required this.onPromptChanged,
     required this.onApiConfigChanged,
     this.additionalWidgets,
   });
 
   @override
   ConsumerState<_FeatureSettingsWidget> createState() => __FeatureSettingsWidgetState();
 }
 
 class __FeatureSettingsWidgetState extends ConsumerState<_FeatureSettingsWidget> {
   late final TextEditingController _promptController;
 
   @override
   void initState() {
     super.initState();
     _promptController = TextEditingController(text: widget.prompt);
   }
 
   @override
   void didUpdateWidget(covariant _FeatureSettingsWidget oldWidget) {
     super.didUpdateWidget(oldWidget);
     // The logic for updating the controller's text has been removed from here
     // to prevent the "can't delete last character" bug.
     // The controller is the source of truth during user input. External updates
     // (e.g., from the full-screen editor) are handled directly in the `onPressed` callback.
   }
 
   @override
   void dispose() {
     _promptController.dispose();
     super.dispose();
   }
 
   String? _getDefaultPrompt() {
     switch (widget.title) {
       case '自动生成聊天标题':
         return defaultTitleGenerationPrompt;
       case '中断恢复':
         return defaultResumePrompt;
       case '帮我回复':
         return defaultHelpMeReplyPrompt;
       default:
         return null;
     }
   }
 
   @override
   Widget build(BuildContext context) {
     final apiConfigs = ref.watch(apiKeyNotifierProvider.select((s) => s.apiConfigs));
 
     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         SwitchListTile(
           title: Text(widget.title),
           subtitle: Text(widget.subtitle),
           value: widget.isEnabled,
           onChanged: widget.onEnableChanged,
           secondary: Icon(widget.icon),
           contentPadding: EdgeInsets.zero,
         ),
         if (widget.isEnabled) ...[
           const SizedBox(height: 15),
           TextFormField(
             controller: _promptController,
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
                         initialText: _promptController.text,
                         title: '编辑 ${widget.title} 的提示词',
                         defaultValue: _getDefaultPrompt(),
                       ),
                     ),
                   );
                   if (newText != null) {
                     _promptController.text = newText;
                     // The newText from editor can be an empty string.
                     // The logic to handle this (using clear... flags) is in the onPromptChanged callback.
                     widget.onPromptChanged(newText);
                   }
                 },
               ),
             ),
             maxLines: 3,
             minLines: 1,
             onChanged: widget.onPromptChanged,
           ),
           const SizedBox(height: 15),
           if (apiConfigs.isEmpty)
             const Text('没有可用的 API 配置。请先在 API 配置管理中添加。', style: TextStyle(color: Colors.orange))
           else
             DropdownButtonFormField<String>(
               value: apiConfigs.any((c) => c.id == widget.apiConfigId) ? widget.apiConfigId : null,
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
               onChanged: widget.onApiConfigChanged,
             ),
           if (widget.additionalWidgets != null) ...widget.additionalWidgets!,
         ],
       ],
     );
   }
 }

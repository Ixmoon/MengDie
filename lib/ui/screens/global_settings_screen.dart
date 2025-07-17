import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers/auth_providers.dart';
import '../../app/providers/settings_providers.dart';
import '../../domain/models/user.dart';
import '../../domain/models/api_config.dart';
import '../../app/providers/api_key_provider.dart';
import '../widgets/fullscreen_text_editor.dart'; // 导入全屏文本编辑器
import '../../domain/enums.dart';
import '../../core/app_constants.dart';
 
class GlobalSettingsScreen extends ConsumerStatefulWidget {
  const GlobalSettingsScreen({super.key});

  @override
  ConsumerState<GlobalSettingsScreen> createState() => _GlobalSettingsScreenState();
}

class _GlobalSettingsScreenState extends ConsumerState<GlobalSettingsScreen> {
  // 本地状态，用于缓存设置更改，避免频繁写入数据库
  late User _localSettings;
  late SyncSettings _localSyncSettings;
  bool _isDirty = false; // 标记设置是否已更改

  @override
  void initState() {
    super.initState();
    // 初始化本地状态
    _localSettings = ref.read(globalSettingsProvider);
    _localSyncSettings = ref.read(syncSettingsProvider);
  }

  @override
  void dispose() {
    // 页面销毁时，如果设置已更改，则保存
    _saveSettingsIfDirty();
    super.dispose();
  }

  // 保存已更改的设置
  void _saveSettingsIfDirty() {
    if (_isDirty) {
      final authState = ref.read(authProvider);
      // 只有当用户不是游客时才保存全局设置
      if (!authState.isGuestMode) {
        ref.read(globalSettingsActionsProvider).updateSettings(_localSettings);
      }
      // 同步设置总是保存，因为它不区分用户
      ref.read(syncSettingsProvider.notifier).updateSettings(_localSyncSettings);
      _isDirty = false; // 重置标记
    }
  }

  // 用于更新本地设置并标记为已更改
  void _updateLocalSettings(User newSettings) {
    setState(() {
      _localSettings = newSettings;
      _isDirty = true;
    });
  }

  void _updateLocalSyncSettings(SyncSettings newSyncSettings) {
    setState(() {
      _localSyncSettings = newSyncSettings;
      _isDirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 监听全局设置和同步设置的外部变化
    final globalSettings = ref.watch(globalSettingsProvider);
    final syncSettings = ref.watch(syncSettingsProvider);

    // 如果外部状态发生变化（例如，通过其他方式同步），则更新本地状态
    // 我们只在 _isDirty 为 false 时执行此操作，以避免覆盖用户的当前输入
    if (!_isDirty) {
      _localSettings = globalSettings;
      _localSyncSettings = syncSettings;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        _saveSettingsIfDirty();
        context.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              _saveSettingsIfDirty();
              context.pop();
            },
            style: ButtonStyle(
              iconColor: WidgetStateProperty.all(
                Theme.of(context).iconTheme.color?.withAlpha((255 * 0.7).round())
              ),
            ),
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

                Text('数据同步', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                _SyncSettingsWidget(
                  settings: _localSyncSettings,
                  onChanged: _updateLocalSyncSettings,
                ),
                const Divider(height: 30),

               Text('自动化', style: Theme.of(context).textTheme.titleLarge),
               const SizedBox(height: 10),
               _FeatureSettingsWidget(
                 title: '自动生成聊天标题',
                 subtitle: '在首次回复后，自动为新聊天生成标题',
                 icon: Icons.title,
                 isEnabled: _localSettings.enableAutoTitleGeneration,
                 prompt: _localSettings.titleGenerationPrompt,
                 apiConfigId: _localSettings.titleGenerationApiConfigId,
                 onEnableChanged: (value) {
                   _updateLocalSettings(_localSettings.copyWith(enableAutoTitleGeneration: value));
                 },
                 onPromptChanged: (value) {
                   _updateLocalSettings(_localSettings.copyWith(titleGenerationPrompt: value));
                 },
                 onApiConfigChanged: (value) {
                   _updateLocalSettings(_localSettings.copyWith(
                     titleGenerationApiConfigId: value,
                     clearTitleGenerationApiConfigId: value == null,
                   ));
                 },
               ),
               const Divider(height: 30),
                _FeatureSettingsWidget(
                 title: '中断恢复',
                 subtitle: '当模型消息中断时，提供恢复按钮',
                 icon: Icons.replay_circle_filled_rounded,
                 isEnabled: _localSettings.enableResume,
                 prompt: _localSettings.resumePrompt,
                 apiConfigId: _localSettings.resumeApiConfigId,
                 onEnableChanged: (value) {
                   _updateLocalSettings(_localSettings.copyWith(enableResume: value));
                 },
                 onPromptChanged: (value) {
                   _updateLocalSettings(_localSettings.copyWith(resumePrompt: value));
                 },
                 onApiConfigChanged: (value) {
                   _updateLocalSettings(_localSettings.copyWith(
                     resumeApiConfigId: value,
                     clearResumeApiConfigId: value == null,
                   ));
                 },
                ),
                const Divider(height: 30),
                Text('账户', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                Consumer(
                  builder: (context, ref, child) {
                    final authState = ref.watch(authProvider);
                    // 无论是注册用户还是游客，都需要一个登出/切换账户的选项。
                    // 唯一的区别是显示的文本。
                    final bool isGuest = authState.isGuestMode;

                    return ListTile(
                      leading: Icon(isGuest ? Icons.login : Icons.logout),
                      title: Text(isGuest ? '登录或注册' : '登出'),
                      subtitle: Text(isGuest ? '当前为游客模式' : '当前用户: ${authState.currentUser?.username ?? ""}'),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onTap: () {
                        // 对于游客和注册用户，操作是相同的：
                        // 1. 清除当前会话（无论是游客还是注册用户）。
                        // 2. 返回到登录页面。
                        ref.read(authProvider.notifier).logout();
                        context.go('/login');
                      },
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    );
                  },
                ),
               ],
             ),
           ),
         ),
      ),
    );
   }
}

class _SyncSettingsWidget extends ConsumerStatefulWidget {
  final SyncSettings settings;
  final ValueChanged<SyncSettings> onChanged;

  const _SyncSettingsWidget({
    required this.settings,
    required this.onChanged,
  });

  @override
  ConsumerState<_SyncSettingsWidget> createState() => _SyncSettingsWidgetState();
}

class _SyncSettingsWidgetState extends ConsumerState<_SyncSettingsWidget> {
  late final TextEditingController _connectionStringController;
  final FocusNode _connectionStringFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _connectionStringController = TextEditingController(text: widget.settings.connectionString);
    _connectionStringFocusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant _SyncSettingsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.settings.connectionString != _connectionStringController.text) {
      _connectionStringController.text = widget.settings.connectionString;
    }
  }

  @override
  void dispose() {
    _connectionStringController.dispose();
    _connectionStringFocusNode.removeListener(_onFocusChange);
    _connectionStringFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_connectionStringFocusNode.hasFocus) {
      widget.onChanged(
        widget.settings.copyWith(connectionString: _connectionStringController.text),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('启用远程同步'),
          subtitle: const Text('将数据同步到远程 PostgreSQL 数据库'),
          value: widget.settings.isEnabled,
          onChanged: (value) {
            widget.onChanged(
              widget.settings.copyWith(isEnabled: value),
            );
          },
          secondary: const Icon(Icons.sync),
        ),
        if (widget.settings.isEnabled) ...[
          const SizedBox(height: 15),
          TextFormField(
            controller: _connectionStringController,
            focusNode: _connectionStringFocusNode,
            decoration: const InputDecoration(
              labelText: '数据库连接字符串',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              // We only trigger the final update on focus change,
              // but we can still use onChanged for intermediate validation if needed.
            },
          ),
        ],
      ],
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
   });
 
   @override
   ConsumerState<_FeatureSettingsWidget> createState() => __FeatureSettingsWidgetState();
 }
 
 class __FeatureSettingsWidgetState extends ConsumerState<_FeatureSettingsWidget> {
   late final TextEditingController _promptController;
   final FocusNode _promptFocusNode = FocusNode();
 
   @override
   void initState() {
     super.initState();
     _promptController = TextEditingController(text: widget.prompt);
     _promptFocusNode.addListener(_onFocusChange);
   }
 
   @override
   void didUpdateWidget(covariant _FeatureSettingsWidget oldWidget) {
     super.didUpdateWidget(oldWidget);
     // 当外部传入的 prompt 发生变化，并且与当前输入框中的文本不一致时，更新输入框
     if (widget.prompt != oldWidget.prompt && widget.prompt != _promptController.text) {
       _promptController.text = widget.prompt;
     }
   }
 
   @override
   void dispose() {
     _promptController.dispose();
     _promptFocusNode.removeListener(_onFocusChange);
     _promptFocusNode.dispose();
     super.dispose();
   }

   void _onFocusChange() {
    // 当输入框失去焦点时，通过回调更新状态
    if (!_promptFocusNode.hasFocus) {
      widget.onPromptChanged(_promptController.text);
    }
  }
 
   String? _getDefaultPrompt() {
     switch (widget.title) {
       case '自动生成聊天标题':
         return defaultTitleGenerationPrompt;
       case '中断恢复':
         return defaultResumePrompt;
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
             focusNode: _promptFocusNode,
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
                     // 从全屏编辑器返回后，立即触发更新
                     widget.onPromptChanged(newText);
                   }
                 },
               ),
             ),
             maxLines: 3,
             minLines: 1,
             onChanged: (value) {
                // 用户输入时，我们不立即调用 onPromptChanged，
                // 最终的更新将在失去焦点时由 _onFocusChange 触发。
             },
           ),
           const SizedBox(height: 15),
           if (apiConfigs.isEmpty)
             const Text('没有可用的 API 配置。请先在 API 配置管理中添加。', style: TextStyle(color: Colors.orange))
           else
             DropdownButtonFormField<String?>(
               isExpanded: true, // 修复溢出
               value: widget.apiConfigId,
               decoration: InputDecoration(
                 labelText: '使用的 API 配置',
                 border: const OutlineInputBorder(),
                 hintText: '默认: ${apiConfigs.first.name}',
               ),
               items: [
                 const DropdownMenuItem<String?>(
                   value: null,
                   // 修复长文本溢出
                   child: Text('使用全局默认配置', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey), overflow: TextOverflow.ellipsis),
                 ),
                 ...apiConfigs.map((ApiConfig config) {
                   return DropdownMenuItem<String?>(
                     value: config.id,
                     // 修复长文本溢出
                     child: Text(config.name, overflow: TextOverflow.ellipsis),
                   );
                 }),
               ],
               onChanged: widget.onApiConfigChanged,
             ),
         ],
       ],
     );
   }
 }

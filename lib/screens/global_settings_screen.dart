import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // 导入 GoRouter 用于导航

// 导入 API Key Provider
// import '../providers/api_key_provider.dart'; // API Key 相关逻辑将移至新页面
// 导入主题相关的 Provider 和枚举
import '../providers/settings_providers.dart';
import '../models/enums.dart';

// 本文件包含全局设置屏幕的界面。

// --- 全局设置屏幕 ---
// 使用 ConsumerWidget，因为它不需要管理本地状态（除了 TextEditingController）。
class GlobalSettingsScreen extends ConsumerWidget {
  const GlobalSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // API Key相关的 State 和 Notifier 将在新的密钥管理页面中使用
    // final apiKeyState = ref.watch(apiKeyNotifierProvider);
    // final apiKeyNotifier = ref.read(apiKeyNotifierProvider.notifier);
    // final apiKeyController = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('全局设置')), // const
      // 使用 GestureDetector 允许点击背景时收起键盘
      body: GestureDetector(
         onTap: () => FocusScope.of(context).unfocus(),
         child: Padding(
           padding: const EdgeInsets.all(16.0), // const
           // 使用 ListView 方便未来扩展更多设置项
           child: ListView(
             children: [
                // --- 主题设置部分 (移到顶部) ---
                Text('应用主题', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10), // const
                Consumer( // 使用 Consumer 来监听 themeModeProvider
                  builder: (context, ref, child) {
                    final currentThemeMode = ref.watch(themeModeProvider);
                    final themeModeNotifier = ref.read(themeModeProvider.notifier);

                    return DropdownButtonFormField<ThemeModeSetting>(
                      value: currentThemeMode,
                      decoration: const InputDecoration( // const
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
                const Divider(height: 30), // const

                // --- API Key 管理部分 (修改为导航项) ---
                Text('API Keys', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10), // const
                ListTile(
                  leading: const Icon(Icons.vpn_key_outlined), // const
                  title: const Text('Gemini API Keys'), // const
                  subtitle: const Text('管理您的 Google AI API 密钥'), // const
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16), // const
                  onTap: () {
                    // 导航到新的 Gemini API Keys 管理页面
                    // 假设路由名称为 '/settings/gemini-api-keys'
                    context.push('/settings/gemini-api-keys');
                  },
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 10), // const: Add some space between the tiles
                ListTile(
                  leading: const Icon(Icons.settings_ethernet_rounded), // const: Use a different icon
                  title: const Text('OpenAI API Endpoints'), // const
                  subtitle: const Text('管理自定义 OpenAI 兼容端点'), // const
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16), // const
                  onTap: () {
                    // 导航到新的 OpenAI API 配置页面
                    // 假设路由名称为 '/settings/openai-api-configs'
                    context.push('/settings/openai-api-configs');
                  },
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const Divider(height: 30), // const


                // --- 未来其他全局设置的占位符 ---
                // Text('其他全局设置', style: Theme.of(context).textTheme.titleLarge),
                // 例如：OpenAI API Keys 等
             ],
           ),
         ),
       ),
    );
  }
}

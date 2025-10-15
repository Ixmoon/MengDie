import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers/auth_providers.dart';
import '../../app/providers/settings_providers.dart';
import '../../data/sync/sync_service.dart';

/// 登录屏幕
///
/// 提供用户登录、注册和进入游客模式的界面。
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  late final TextEditingController _connectionStringController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _connectionStringController = TextEditingController(
      text: ref.read(syncSettingsProvider).connectionString,
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _connectionStringController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await ref
            .read(authProvider.notifier)
            .login(_usernameController.text, _passwordController.text);
        // 登录成功后，在后台触发自动同步和用户设置拉取
        // We don't await these futures to avoid blocking the UI.
        SyncService.instance.syncWithRemote();

        if (mounted) context.go('/list');
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('登录失败: ${e.toString()}')));
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await ref
            .read(authProvider.notifier)
            .register(_usernameController.text, _passwordController.text);
        // 注册成功后，同样触发后台同步
        SyncService.instance.syncWithRemote();

        if (mounted) context.go('/list');
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('注册失败: ${e.toString()}')));
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _enterGuestMode() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).enterGuestMode();
      if (mounted) context.go('/list');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('登录')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: '用户名'),
                  validator: (value) => value!.isEmpty ? '请输入用户名' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: '密码'),
                  obscureText: true,
                  validator: (value) => value!.isEmpty ? '请输入密码' : null,
                ),
                const SizedBox(height: 16),
                _buildSyncSettings(),
                const SizedBox(height: 24),
                if (_isLoading)
                  const CircularProgressIndicator()
                else
                  Column(
                    children: [
                      ElevatedButton(
                        onPressed: _login,
                        child: const Text('登录'),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _register,
                        child: const Text('注册'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _enterGuestMode,
                        child: const Text('以游客身份继续'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSyncSettings() {
    final syncSettings = ref.watch(syncSettingsProvider);

    return ExpansionTile(
      title: const Text('同步设置'),
      subtitle: Text(syncSettings.isEnabled ? '已启用' : '已禁用'),
      children: [
        SwitchListTile(
          title: const Text('启用同步'),
          value: syncSettings.isEnabled,
          onChanged: (value) {
            ref.read(syncSettingsProvider.notifier).updateSettings(
                  syncSettings.copyWith(isEnabled: value),
                );
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: TextFormField(
            controller: _connectionStringController,
            decoration: const InputDecoration(
              labelText: '数据库连接字符串',
              hintText: 'postgresql://user:password@host:port/dbname',
            ),
            enabled: syncSettings.isEnabled,
            onChanged: (value) {
              // Debounced update to avoid excessive provider notifications
            },
            onEditingComplete: () {
              ref.read(syncSettingsProvider.notifier).updateSettings(
                    syncSettings.copyWith(connectionString: _connectionStringController.text),
                  );
            },
          ),
        ),
      ],
    );
  }
}

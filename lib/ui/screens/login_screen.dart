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
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await ref.read(authProvider.notifier).login(
              _usernameController.text,
              _passwordController.text,
            );
       // 登录成功后，在后台触发自动同步和用户设置拉取
       // We don't await these futures to avoid blocking the UI.
       SyncService.instance.syncWithRemote();

       if (mounted) context.go('/list');
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('登录失败: ${e.toString()}')),
          );
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
        await ref.read(authProvider.notifier).register(
              _usernameController.text,
              _passwordController.text,
            );
       // 注册成功后，同样触发后台同步
       SyncService.instance.syncWithRemote();
       
       if (mounted) context.go('/list');
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('注册失败: ${e.toString()}')),
          );
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

  Future<void> _syncUsers() async {
    // Read the current sync settings
    final syncSettings = ref.read(syncSettingsProvider);
    String connectionString = syncSettings.connectionString;

    // If the connection string is empty, prompt the user
    if (connectionString.isEmpty) {
      final newConnectionString = await _showConnectionStringDialog();
      if (newConnectionString == null || newConnectionString.isEmpty) {
        return; // User cancelled
      }
      connectionString = newConnectionString;
      // Update and persist the new settings
      ref.read(syncSettingsProvider.notifier).updateSettings(
        syncSettings.copyWith(connectionString: connectionString, isEnabled: true)
      );
      // Give a moment for the provider to update before sync service reads it
      await Future.delayed(const Duration(milliseconds: 50));
    }

    setState(() => _isLoading = true);
    try {
      await SyncService.instance.syncAllUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('用户数据同步完成')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('同步失败: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<String?> _showConnectionStringDialog() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('输入数据库连接字符串'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'postgresql://user:password@host:port/dbname',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(controller.text);
              },
              child: const Text('保存并同步'),
            ),
          ],
        );
      },
    );
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
                  validator: (value) =>
                      value!.isEmpty ? '请输入用户名' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: '密码'),
                  obscureText: true,
                  validator: (value) =>
                      value!.isEmpty ? '请输入密码' : null,
                ),
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
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        icon: const Icon(Icons.sync),
                        label: const Text('同步远程用户数据'),
                        onPressed: _syncUsers,
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.secondary,
                        ),
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
}
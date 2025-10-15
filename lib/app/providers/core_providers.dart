import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/database/app_database.dart'; // Import Drift database
import 'settings_providers.dart';

// 本文件包含应用核心服务的 Riverpod 提供者，例如数据库和本地存储。

// --- Drift AppDatabase Provider ---
// Provides the AppDatabase instance.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  // The AppDatabase constructor itself handles opening the connection.
  // If you need to manage its lifecycle more explicitly (e.g., closing),
  // you might use a different type of Provider or add disposal logic.
  return AppDatabase();
});

// --- SharedPreferences Provider ---
// 提供 SharedPreferences 实例的 FutureProvider。
// 这个 Provider 会异步初始化 SharedPreferences，无需在 main() 中手动处理。
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((
  ref,
) async {
  return await SharedPreferences.getInstance();
});

/// A provider that exposes a list of providers that need to be initialized asynchronously
/// when the application starts. This ensures that essential services are ready
/// before the UI is built.
final coreAsyncInitializersProvider = Provider<List<ProviderListenable>>((ref) {
  return [
    // Add any providers here that have an `init()` method or require async setup.
    // For StateNotifierProviders, you can usually just reference the notifier.
    themeModeProvider.notifier,
    syncSettingsProvider.notifier,
    summaryRatioProvider.notifier,
  ];
});

// --- 全局同步状态 Provider ---
// 这个 Provider 用于跟踪应用当前是否正在进行数据同步。
// true = 正在同步, false = 未在同步。
// 这可以用来防止在同步过程中执行某些数据清理或回退逻辑，避免数据不一致。
final isSyncingProvider = StateProvider<bool>((ref) => false);

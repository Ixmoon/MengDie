
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/database/app_database.dart'; // Import Drift database

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
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
	return await SharedPreferences.getInstance();
});


import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/database/drift/app_database.dart'; // Import Drift database

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
// 提供 SharedPreferences 实例的 Provider。
// 注意：这个 Provider 必须在 main() 函数中被 override，
// 因为 SharedPreferences 需要异步初始化。
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  // 如果在 main() 中没有被 override，则抛出未实现错误，提示开发者进行初始化。
  throw UnimplementedError('SharedPreferences 应该在 main() 中初始化并覆盖此 Provider');
});

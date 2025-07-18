import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/api_config_repository.dart';
import '../repositories/chat_repository.dart';
import '../repositories/user_repository.dart';
import 'core_providers.dart'; // For appDatabaseProvider

// Provider for ApiConfigRepository
final apiConfigRepositoryProvider = Provider<ApiConfigRepository>((ref) {
  // The repository depends on the ApiConfigDao.
  // The DAO is obtained from the AppDatabase instance.
  final database = ref.watch(appDatabaseProvider);
  return ApiConfigRepository(database.apiConfigDao);
});

// Provider for ChatRepository
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ChatRepository(ref, db, db.chatDao, db.userDao);
});

// Provider for UserRepository
final userRepositoryProvider = Provider<UserRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return UserRepository(ref, db.userDao);
});
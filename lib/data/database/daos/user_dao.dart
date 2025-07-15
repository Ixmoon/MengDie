import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/users.dart';

part 'user_dao.g.dart';

/// 用户数据访问对象 (DAO)
///
/// 提供与用户数据表 (Users) 交互的方法。
@DriftAccessor(tables: [Users])
class UserDao extends DatabaseAccessor<AppDatabase> with _$UserDaoMixin {
  UserDao(super.db);

  /// 根据用户名查找用户。
  ///
  /// [username] 要查找的用户名。
  /// 返回一个 [DriftUser] 对象，如果未找到则返回 null。
  Future<DriftUser?> getUserByUsername(String username) {
    return (select(users)..where((u) => u.username.equals(username))).getSingleOrNull();
  }

  /// 根据用户ID查找用户。
  ///
  /// [userId] 要查找的用户ID。
  /// 返回一个 [DriftUser] 对象，如果未找到则返回 null。
  Future<DriftUser?> getUserById(int userId) {
    return (select(users)..where((u) => u.id.equals(userId))).getSingleOrNull();
  }

  /// 保存一个新用户或更新一个现有用户。
  ///
  /// [user] 要保存或更新的用户对象。
  Future<void> saveUser(UsersCompanion user) {
    final companionWithTime = user.copyWith(updatedAt: Value(DateTime.now()));
    return into(users).insertOnConflictUpdate(companionWithTime);
  }
  /// 监听单个用户的变化。
  ///
  /// [userId] 要监听的用户的ID。
  /// 返回一个用户数据流。
  Stream<DriftUser?> watchUser(int userId) {
    return (select(users)..where((u) => u.id.equals(userId))).watchSingleOrNull();
  }
}
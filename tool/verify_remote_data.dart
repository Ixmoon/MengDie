import 'package:postgres/postgres.dart' as pg;

// 该脚本用于连接到远程 PostgreSQL 数据库，并获取所有表中的数据以供检查。
// 它会打印每个表中的记录数和详细内容。
Future<void> main() async {
  final connectionString =
      'postgresql://neondb_owner:npg_JNQZ0m8SazcH@ep-late-poetry-a16kyduc-pooler.ap-southeast-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require';

  pg.Connection? connection;
  try {
    print('正在连接到远程数据库...');
    final uri = Uri.parse(connectionString);
    connection = await pg.Connection.open(
      pg.Endpoint(
        host: uri.host,
        port: uri.port == 0 ? 5432 : uri.port,
        database: uri.pathSegments.first,
        username: uri.userInfo.split(':')[0],
        password: uri.userInfo.contains(':') ? uri.userInfo.split(':').last : null,
      ),
      settings: pg.ConnectionSettings(
        sslMode: pg.SslMode.require,
      ),
    );
    print('数据库连接成功！\n');

    final tables = ['users', 'api_configs', 'chats', 'messages'];

    for (final table in tables) {
      print('--- 开始查询表: $table ---');
      try {
        // Add a unique comment to each query to prevent prepared statement caching issues.
        final results = await connection.execute('SELECT * FROM $table -- $table');
        if (results.isEmpty) {
          print('表中没有数据。');
        } else {
          print('找到 ${results.length} 条记录:');
          for (final row in results) {
            print('  - ${row.toColumnMap()}');
          }
        }
      } catch (e) {
        print('查询表 $table 时发生错误: $e');
      }
      print('--- 表 $table 查询结束 ---\n');
    }
  } catch (e) {
    print('发生严重错误: $e');
  } finally {
    await connection?.close();
    print('数据库连接已关闭。');
  }
}
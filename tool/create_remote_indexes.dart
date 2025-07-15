import 'package:postgres/postgres.dart' as pg;

// 该脚本用于连接到远程 PostgreSQL 数据库，并为关键表创建覆盖索引以优化查询性能。
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

    final indexCommands = [
      'CREATE INDEX IF NOT EXISTS idx_api_configs_sync_meta ON api_configs (id, created_at, updated_at);',
      'CREATE INDEX IF NOT EXISTS idx_chats_sync_meta ON chats (id, created_at, updated_at);',
      'CREATE INDEX IF NOT EXISTS idx_users_sync_meta ON users (uuid, created_at, updated_at);'
    ];

    for (final command in indexCommands) {
      print('--- 正在执行命令: $command ---');
      try {
        await connection.execute(command);
        print('命令成功执行。');
      } catch (e) {
        print('执行命令时发生错误: $e');
      }
      print('--- 命令执行结束 ---\n');
    }

  } catch (e) {
    print('发生严重错误: $e');
  } finally {
    await connection?.close();
    print('数据库连接已关闭。');
  }
}
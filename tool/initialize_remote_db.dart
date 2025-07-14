import 'dart:io';
import 'package:postgres/postgres.dart' as pg;

// 该脚本用于初始化远程 PostgreSQL 数据库。
// 它会读取项目根目录下的 'initialize_remote_db.sql' 文件，
// 并执行其中的 SQL 指令来清空和重建数据库表。
Future<void> main() async {
  // 从用户输入中获取的连接字符串
  final connectionString =
      'postgresql://neondb_owner:npg_JNQZ0m8SazcH@ep-late-poetry-a16kyduc-pooler.ap-southeast-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require';

  pg.Connection? connection;
  try {
    print('正在连接到远程数据库...');
    final uri = Uri.parse(connectionString);
    connection = await pg.Connection.open(
      pg.Endpoint(
        host: uri.host,
        port: uri.port == 0 ? 5432 : uri.port, // 如果未指定端口，则使用默认的5432
        database: uri.pathSegments.first,
        username: uri.userInfo.split(':')[0],
        password: uri.userInfo.split(':')[1],
      ),
      settings: pg.ConnectionSettings(
        sslMode: pg.SslMode.require,
      ),
    );
    print('数据库连接成功！');

    print('正在读取 schema.sql 文件...');
    final sqlFile = File('initialize_remote_db.sql');
    if (!await sqlFile.exists()) {
      print('错误: 未在项目根目录找到 initialize_remote_db.sql 文件。');
      return;
    }
    final sqlContent = await sqlFile.readAsString();
    print('SQL 文件读取成功。');

    print('正在执行数据库初始化脚本...');
    // `execute` 无法处理多个语句。我们需要将它们分开。
    final statements = sqlContent.split(';').where((s) => s.trim().isNotEmpty);

    // 按顺序执行分割后的每一条 SQL 语句。
    // 由于脚本开头有 DROP TABLE，因此整个过程是幂等的，事务不是必需的。
    for (final statement in statements) {
      // 使用 ! 是安全的，因为如果连接为空，在之前的步骤中就会抛出异常。
      await connection!.execute(statement);
    }

    print('数据库初始化成功！所有表已清空并根据最新结构重建。');
  } catch (e) {
    print('发生错误: $e');
  } finally {
    await connection?.close();
    print('数据库连接已关闭。');
  }
}
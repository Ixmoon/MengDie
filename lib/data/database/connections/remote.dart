import 'dart:async';

import 'package:postgres/postgres.dart';

/// Establishes a connection to the remote Neon (PostgreSQL) database.
///
/// This function creates and opens a new PostgreSQL connection using the provided
/// connection string. It is designed to be used by the [SyncService] to
/// acquire a remote database connection for synchronized transactions.
///
/// The connection string should be securely managed and provided at runtime.
Future<Connection> connectRemote() async {
  // The connection string for the Neon database.
  // It is recommended to load this from a secure configuration file or
  // environment variables rather than hardcoding it.
  const connectionString =
      'postgresql://neondb_owner:npg_JNQZ0m8SazcH@ep-late-poetry-a16kyduc-pooler.ap-southeast-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require';

  final uri = Uri.parse(connectionString);
  final endpoint = Endpoint(
    host: uri.host,
    port: uri.port == 0 ? 5432 : uri.port, // Explicitly use standard port 5432 as a fallback
    database: uri.pathSegments.first,
    username: uri.userInfo.split(':').first,
    password: uri.userInfo.split(':').last,
  );

  // Open the connection using Connection.open
  final connection = await Connection.open(
    endpoint,
    settings: const ConnectionSettings(sslMode: SslMode.require),
  );
  return connection;
}
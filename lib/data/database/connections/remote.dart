import 'dart:async';

import 'package:postgres/postgres.dart';

/// Establishes a connection to the remote Neon (PostgreSQL) database.
///
/// This function creates and opens a new PostgreSQL connection using the provided
/// connection string. It is designed to be used by the [SyncService] to
/// acquire a remote database connection for synchronized transactions.
///
/// The connection string should be securely managed and provided at runtime.
Future<Connection> connectRemote(String connectionString) async {
  if (connectionString.isEmpty) {
    throw Exception("Remote connection string is empty. Cannot connect.");
  }

  final uri = Uri.parse(connectionString);
  final endpoint = Endpoint(
    host: uri.host,
    port: uri.port == 0 ? 5432 : uri.port, // Explicitly use standard port 5432 as a fallback
    database: uri.pathSegments.first,
    username: uri.userInfo.split(':').first,
    password: uri.userInfo.contains(':') ? uri.userInfo.split(':').last : null,
  );

  // Open the connection using Connection.open
  final connection = await Connection.open(
    endpoint,
    settings: const ConnectionSettings(sslMode: SslMode.require),
  );
  return connection;
}
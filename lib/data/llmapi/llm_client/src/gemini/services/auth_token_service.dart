// lib/src/gemini/services/auth_token_service.dart
import '../http/http_client.dart';
import '../models/auth_token.dart';

/// Service for managing authentication tokens.
class AuthTokenService {
  final HttpClient _httpClient;

  AuthTokenService({required HttpClient httpClient}) : _httpClient = httpClient;

  Future<AuthToken> create(AuthTokenConfig config) async {
    // The successful Python capture shows the config object is the root of the request.
    final requestBody = config.toJson();

    // The path is 'auth_tokens'.
    final response = await _httpClient.post(
      'auth_tokens',
      requestBody,
      apiVersion: 'v1alpha',
    );
    return AuthToken.fromJson(response);
  }
}
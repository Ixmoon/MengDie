import '../../common/pagination.dart';
import '../http/http_client.dart';
import '../models/permission.dart';

/// Service for managing permissions for `tunedModels` and `corpora`.
class PermissionService {
  final HttpClient _httpClient;

  /// Default constructor for [PermissionService].
  PermissionService({required HttpClient httpClient}) : _httpClient = httpClient;

  /// Create a permission to a specific resource.
  ///
  /// The parent resource of the `Permission`.
  /// Formats: `tunedModels/{tunedModel}` or `corpora/{corpus}`.
  Future<Permission> create({
    required String parent,
    required Permission permission,
  }) async {
    final response = await _httpClient.post(
      '$parent/permissions',
      permission.toJson(),
    );
    return Permission.fromJson(response);
  }

  /// Get information about a specific Permission.
  ///
  /// The resource name of the permission.
  /// Formats: `tunedModels/{tunedModel}/permissions/{permission}` or
  /// `corpora/{corpus}/permissions/{permission}`.
  Future<Permission> get({required String name}) async {
    final response = await _httpClient.get(name);
    return Permission.fromJson(response);
  }

  /// List permissions for the specific resource.
  ///
  /// The parent resource of the permissions.
  /// Formats: `tunedModels/{tunedModel}` or `corpora/{corpus}`.
  Future<PaginatedResponse<Permission>> list({
    required String parent,
    int? pageSize,
    String? pageToken,
  }) async {
    final queryParameters = <String, dynamic>{
      if (pageSize != null) 'pageSize': pageSize,
      if (pageToken != null) 'pageToken': pageToken,
    };
    final response = await _httpClient.get(
      '$parent/permissions',
      queryParameters: queryParameters.isNotEmpty ? queryParameters : null,
    );
    return PaginatedResponse.fromJson(
        response, 'permissions', Permission.fromJson);
  }

  /// Update the permission.
  ///
  /// The resource name of the permission.
  /// Formats: `tunedModels/{tunedModel}/permissions/{permission}` or
  /// `corpora/{corpus}/permissions/{permission}`.
  Future<Permission> patch({
    required String name,
    required Role role,
  }) async {
    final response = await _httpClient.patch(
      name,
      {'role': role.value},
      queryParameters: {'updateMask': 'role'},
    );
    return Permission.fromJson(response);
  }

  /// Delete the permission.
  ///
  /// The resource name of the permission.
  /// Formats: `tunedModels/{tunedModel}/permissions/{permission}` or
  /// `corpora/{corpus}/permissions/{permission}`.
  Future<void> delete({required String name}) async {
    await _httpClient.delete(name);
  }
}
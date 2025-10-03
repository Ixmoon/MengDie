
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import '../../common/pagination.dart';
import '../http/http_client.dart';
import '../models/cache.dart';

/// Service for interacting with the CachedContent API.
class CachedContentService {
  final HttpClient _httpClient;
  CachedContentService({required HttpClient httpClient}) : _httpClient = httpClient;

  /// Creates a cached content instance.
  Future<CachedContent> create(CachedContent content) async {
    final response = await _httpClient.post(
      'cachedContents',
      content.toJson(),
      apiVersion: 'v1beta',
    );
    return CachedContent.fromJson(response);
  }

  /// Gets a specific cached content instance.
  Future<CachedContent> get(String name) async {
    final response = await _httpClient.get(name, apiVersion: 'v1beta');
    return CachedContent.fromJson(response);
  }

  /// Lists cached content.
  Future<PaginatedResponse<CachedContent>> list(
      {int? pageSize, String? pageToken}) async {
    final queryParameters = <String, String>{
      if (pageSize != null) 'pageSize': pageSize.toString(),
      if (pageToken != null) 'pageToken': pageToken,
    };

    final response = await _httpClient.get(
      'cachedContents',
      queryParameters: queryParameters.isNotEmpty ? queryParameters : null,
      apiVersion: 'v1beta',
    );
    return PaginatedResponse.fromJson(
        response, 'cachedContents', CachedContent.fromJson);
  }

  /// Updates a cached content instance.
  Future<CachedContent> patch(String name, {String? ttl, List<String>? updateMask}) async {
    final body = <String, dynamic>{
      if (ttl != null) 'ttl': ttl,
    };
    final queryParameters = <String, String>{
      if (updateMask != null) 'updateMask': updateMask.join(','),
    };

    final response = await _httpClient.patch(
      name,
      body,
      queryParameters: queryParameters.isNotEmpty ? queryParameters : null,
      apiVersion: 'v1beta',
    );
    return CachedContent.fromJson(response);
  }

  /// Deletes a cached content instance.
  Future<void> delete(String name) async {
    await _httpClient.delete(name, apiVersion: 'v1beta');
  }
}
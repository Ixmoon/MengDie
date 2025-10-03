
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import '../../common/pagination.dart';
import '../http/http_client.dart';
import '../models/retrieval.dart';

/// A service for managing `Corpus` resources in the Gemini API.
class CorporaService {
  final HttpClient _httpClient;

  CorporaService({required HttpClient httpClient}) : _httpClient = httpClient;

  /// Creates an empty `Corpus`.
  Future<Corpus> create(Corpus corpus) async {
    final response = await _httpClient.post(
      'corpora',
      corpus.toJson(),
    );
    return Corpus.fromJson(response);
  }

  /// Gets information about a specific `Corpus`.
  Future<Corpus> get(String name) async {
    final response = await _httpClient.get(name);
    return Corpus.fromJson(response);
  }

  /// Lists all `Corpora` owned by the user.
  Future<PaginatedResponse<Corpus>> list(
      {int? pageSize, String? pageToken}) async {
    final query = {
      if (pageSize != null) 'pageSize': pageSize.toString(),
      if (pageToken != null) 'pageToken': pageToken,
    };
    final response = await _httpClient.get('corpora', queryParameters: query);
    return PaginatedResponse.fromJson(response, 'corpora', Corpus.fromJson);
  }

  /// Updates a `Corpus`.
  Future<Corpus> patch(String name, Corpus corpus,
      {List<String>? updateMask}) async {
    final query = {
      if (updateMask != null) 'updateMask': updateMask.join(','),
    };
    final response = await _httpClient.patch(
      name,
      corpus.toJson(),
      queryParameters: query,
    );
    return Corpus.fromJson(response);
  }

  /// Deletes a `Corpus`.
  Future<void> delete(String name, {bool? force}) async {
    final path = '$name?${force != null ? 'force=$force' : ''}';
    await _httpClient.delete(path);
  }

  /// Performs semantic search over a `Corpus`.
  Future<List<RelevantChunk>> query(String name,
      {required String query,
      List<MetadataFilter>? metadataFilters,
      int? resultsCount}) async {
    final data = {
      'query': query,
      if (metadataFilters != null)
        'metadataFilters': metadataFilters.map((e) => e.toJson()).toList(),
      if (resultsCount != null) 'resultsCount': resultsCount,
    };
    final response = await _httpClient.post(
      '$name:query',
      data,
    );
    return (response['relevantChunks'] as List<dynamic>)
        .map((e) => RelevantChunk.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
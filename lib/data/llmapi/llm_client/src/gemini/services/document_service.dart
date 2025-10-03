
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import '../../common/pagination.dart';
import '../http/http_client.dart';
import '../models/retrieval.dart';

/// The `DocumentService` class encapsulates all API requests related to
/// the `documents` endpoint of the Gemini API.
class DocumentService {
  final HttpClient _httpClient;

  DocumentService({required HttpClient httpClient}) : _httpClient = httpClient;

  /// Creates an empty `Document`.
  Future<Document> create(
      {required String parent, required Document document}) async {
    final response = await _httpClient.post('$parent/documents', document.toJson());

    return Document.fromJson(response);
  }

  /// Gets information about a specific `Document`.
  Future<Document> get(String name) async {
    final response = await _httpClient.get(name);
    return Document.fromJson(response);
  }

  /// Lists all `Document`s in a `Corpus`.
  Future<PaginatedResponse<Document>> list(String parent,
      {int? pageSize, String? pageToken}) async {
    final query = {
      if (pageSize != null) 'pageSize': pageSize.toString(),
      if (pageToken != null) 'pageToken': pageToken,
    };

    final response =
        await _httpClient.get('$parent/documents', queryParameters: query);

    return PaginatedResponse.fromJson(
        response, 'documents', Document.fromJson);
  }

  /// Updates a `Document`.
  Future<Document> patch(String name, Document document,
      {List<String>? updateMask}) async {
    final query = {
      if (updateMask != null) 'updateMask': updateMask.join(','),
    };

    final response = await _httpClient
        .patch(name, document.toJson(), queryParameters: query);

    return Document.fromJson(response);
  }

  /// Deletes a `Document`.
  Future<void> delete(String name, {bool? force}) async {
    final query = {
      if (force != null) 'force': force.toString(),
    };

    await _httpClient.delete(name, queryParameters: query);
  }

  /// Performs semantic search over a `Document`.
  Future<List<RelevantChunk>> query(String name,
      {required String query,
      List<MetadataFilter>? metadataFilters,
      int? resultsCount}) async {
    if (metadataFilters != null &&
        metadataFilters.any((f) => f.key?.startsWith('document.') ?? false)) {
      throw ArgumentError(
          'Document-level metadata filtering is not supported when querying a specific document.');
    }
    final data = {
      'query': query,
      if (metadataFilters != null)
        'metadataFilters': metadataFilters.map((e) => e.toJson()).toList(),
      if (resultsCount != null) 'resultsCount': resultsCount,
    };

    final response = await _httpClient.post('$name:query', data);

    return (response['relevantChunks'] as List)
        .map((e) => RelevantChunk.fromJson(e))
        .toList();
  }
}
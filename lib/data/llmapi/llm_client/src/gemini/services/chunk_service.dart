
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import '../../common/pagination.dart';
import '../http/http_client.dart';
import '../models/retrieval.dart';

/// The `ChunkService` class provides methods for managing `Chunk` resources in the Gemini API.
///
/// A `Chunk` is a subpart of a `Document` that is treated as an independent unit for the
/// purposes of vector representation and storage. A `Corpus` can have a maximum of 1 million `Chunk`s.
class ChunkService {
  final HttpClient _httpClient;

  ChunkService({required HttpClient httpClient}) : _httpClient = httpClient;

  /// Creates a `Chunk`.
  Future<Chunk> create({required String parent, required Chunk chunk}) async {
    final response = await _httpClient.post(
      '$parent/chunks',
      chunk.toJson(),
    );
    return Chunk.fromJson(response);
  }

  /// Gets information about a specific `Chunk`.
  Future<Chunk> get(String name) async {
    final response = await _httpClient.get(name);
    return Chunk.fromJson(response);
  }

  /// Lists all `Chunk`s in a `Document`.
  Future<PaginatedResponse<Chunk>> list(String parent,
      {int? pageSize, String? pageToken}) async {
    final Map<String, dynamic> queryParameters = {
      if (pageSize != null) 'pageSize': pageSize.toString(),
      if (pageToken != null) 'pageToken': pageToken,
    };

    final response = await _httpClient.get(
      '$parent/chunks',
      queryParameters: queryParameters,
    );

    return PaginatedResponse.fromJson(response, 'chunks', Chunk.fromJson);
  }

  /// Updates a `Chunk`.
  Future<Chunk> patch(String name, Chunk chunk,
      {List<String>? updateMask}) async {
    final Map<String, dynamic> queryParameters = {
      if (updateMask != null) 'updateMask': updateMask.join(','),
    };
    final response = await _httpClient.patch(
      name,
      chunk.toJson(),
      queryParameters: queryParameters,
    );
    return Chunk.fromJson(response);
  }

  /// Deletes a `Chunk`.
  Future<void> delete(String name) async {
    await _httpClient.delete(name);
  }

  /// Batch create `Chunk`s.
  Future<List<Chunk>> batchCreate(
      {required String parent, required List<Chunk> chunks}) async {
    final requests = chunks
        .map((chunk) => {'parent': parent, 'chunk': chunk.toJson()})
        .toList();
    final response = await _httpClient.post(
      '$parent/chunks:batchCreate',
      {'requests': requests},
    );

    return (response['chunks'] as List)
        .map((chunk) => Chunk.fromJson(chunk))
        .toList();
  }

  /// Batch update `Chunk`s.
  Future<List<Chunk>> batchUpdate(
      {required String parent,
      required List<({Chunk chunk, List<String> updateMask})>
          requests}) async {
    final formattedRequests = requests
        .map((req) => {
              'chunk': req.chunk.toJson(),
              'updateMask': req.updateMask.join(','),
            })
        .toList();

    final response = await _httpClient.post(
      '$parent/chunks:batchUpdate',
      {'requests': formattedRequests},
    );

    return (response['chunks'] as List)
        .map((chunk) => Chunk.fromJson(chunk))
        .toList();
  }

  /// Batch delete `Chunk`s.
  Future<void> batchDelete(
      {required String parent, required List<String> names}) async {
    final requests = names.map((name) => ({'name': name})).toList();
    await _httpClient.post(
      '$parent/chunks:batchDelete',
      {'requests': requests},
    );
  }
}
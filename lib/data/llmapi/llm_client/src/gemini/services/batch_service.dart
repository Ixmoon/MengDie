// lib/src/gemini/services/batch_service.dart

// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import '../http/http_client.dart';
import '../models/batch.dart';

/// The `BatchService` is responsible for managing long-running operations (LROs).
class BatchService {
  final HttpClient _httpClient;

  BatchService({required HttpClient httpClient}) : _httpClient = httpClient;

  /// Gets the latest state of a long-running operation.
  /// Clients can use this method to poll the operation result at intervals.
  Future<Operation> get(String name) async {
    final response = await _httpClient.get(name);
    return Operation.fromJson(response);
  }

  /// Lists operations that match the specified filter in the request.
  Future<ListOperationsResponse> list(
      {String? filter, int? pageSize, String? pageToken}) async {
    final query = <String, dynamic>{
      if (filter != null) 'filter': filter,
      if (pageSize != null) 'pageSize': pageSize,
      if (pageToken != null) 'pageToken': pageToken,
    };
    final response = await _httpClient.get('batches', queryParameters: query);
    return ListOperationsResponse.fromJson(response);
  }

  /// Starts asynchronous cancellation on a long-running operation.
  /// The server makes a best effort to cancel the operation, but success is not guaranteed.
  Future<void> cancel(String name) async {
    await _httpClient.post('$name:cancel', {});
  }

  /// Deletes a long-running operation.
  /// This method indicates that the client is no longer interested in the operation result.
  Future<void> delete(String name) async {
    await _httpClient.delete(name);
  }
}

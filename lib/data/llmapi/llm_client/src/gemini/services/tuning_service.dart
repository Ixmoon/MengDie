// lib/src/gemini/services/tuning_service.dart


// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:async';

import '../../common/pagination.dart';
import '../models/batch.dart';
import '../models/tuning.dart';
import '../http/http_client.dart';
import '../utils/lro_poller.dart';

/// Service for managing tuned models.
class TuningService {
  final HttpClient _httpClient;
  final LroPoller _lroPoller;

  TuningService({required HttpClient httpClient})
      : _httpClient = httpClient,
        _lroPoller = LroPoller(httpClient);

  /// Creates a TunedModel and waits for the operation to complete.
  Future<TunedModel> create({
    String? tunedModelId,
    required TunedModel tunedModel,
    Duration pollingInterval = const Duration(seconds: 30),
    Duration? timeout,
    void Function(Operation operation)? onProgress,
  }) {
    return _lroPoller.poll<TunedModel>(
      startOperation: () => createTunedModel(
          tunedModelId: tunedModelId, tunedModel: tunedModel),
      responseParser: (json) => TunedModel.fromJson(json),
      pollingInterval: pollingInterval,
      timeout: timeout,
      onProgress: onProgress,
    );
  }

  /// Creates a TunedModel.
  Future<Operation> createTunedModel(
      {String? tunedModelId, required TunedModel tunedModel}) async {
    final Map<String, dynamic> queryParameters = {};
    if (tunedModelId != null) {
      queryParameters['tunedModelId'] = tunedModelId;
    }

    final response = await _httpClient.post(
      'tunedModels',
      tunedModel.toJson(),
      queryParameters: queryParameters,
    );
    return Operation.fromJson(response);
  }

  /// Gets information about a specific TunedModel.
  Future<TunedModel> get(String name) async {
    final response = await _httpClient.get(name);
    return TunedModel.fromJson(response);
  }

  /// Lists tuned models.
  Future<PaginatedResponse<TunedModel>> list(
      {int? pageSize, String? pageToken, String? filter}) async {
    final Map<String, dynamic> queryParameters = {};
    if (pageSize != null) {
      queryParameters['pageSize'] = pageSize;
    }
    if (pageToken != null) {
      queryParameters['pageToken'] = pageToken;
    }
    if (filter != null) {
      queryParameters['filter'] = filter;
    }

    final response = await _httpClient.get(
      'tunedModels',
      queryParameters: queryParameters,
    );

    return PaginatedResponse.fromJson(
        response, 'tunedModels', TunedModel.fromJson);
  }

  /// Updates a TunedModel.
  Future<TunedModel> patch(
      {required String name,
      required TunedModel tunedModel,
      List<String>? updateMask}) async {
    final Map<String, dynamic> queryParameters = {};
    if (updateMask != null) {
      queryParameters['updateMask'] = updateMask.join(',');
    }

    final response = await _httpClient.patch(
      name,
      tunedModel.toJson(),
      queryParameters: queryParameters,
    );
    return TunedModel.fromJson(response);
  }

  /// Deletes a TunedModel.
  Future<void> delete(String name) async {
    await _httpClient.delete(name);
  }

  /// Transfers ownership of the tuned model.
  ///
  /// This is the only way to change ownership of the tuned model.
  /// The current owner will be downgraded to writer role.
  Future<void> transferOwnership(
      {required String name, required String emailAddress}) async {
    await _httpClient.post(
      '$name:transferOwnership',
      {'emailAddress': emailAddress},
    );
  }
}
// lib/src/gemini/services/model_service.dart
import '../../common/pagination.dart';
import '../http/http_client.dart';
import '../models/generative.dart';

/// Service for interacting with the Model API.
class ModelService {
  final HttpClient _httpClient;
  ModelService({required HttpClient httpClient}) : _httpClient = httpClient;

  Future<ModelInfo> get(String modelName) async {
    final response = await _httpClient.get('models/$modelName');
    return ModelInfo.fromJson(response);
  }

  Future<PaginatedResponse<ModelInfo>> list(
      {int? pageSize, String? pageToken}) async {
    final queryParameters = <String, String>{
      if (pageSize != null) 'pageSize': pageSize.toString(),
      if (pageToken != null) 'pageToken': pageToken,
    };

    final response = await _httpClient.get(
      'models',
      queryParameters: queryParameters.isNotEmpty ? queryParameters : null,
    );
    return PaginatedResponse.fromJson(response, 'models', ModelInfo.fromJson);
  }
}
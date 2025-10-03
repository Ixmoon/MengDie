// lib/src/gemini/services/file_service.dart
import '../../common/pagination.dart';
import '../http/http_client.dart';
import '../http/upload_client.dart';
import '../models/file.dart';

/// Service for interacting with the File API.
class FileService {
  final HttpClient _httpClient;
  final UploadClient _uploadClient;

  FileService({required HttpClient httpClient, required UploadClient uploadClient})
      : _httpClient = httpClient,
        _uploadClient = uploadClient;

  Future<File> get(String fileName) async {
    final response = await _httpClient.get('files/$fileName');
    return File.fromJson(response);
  }

  Future<PaginatedResponse<File>> list(
      {int pageSize = 100, String? pageToken}) async {
    final params = <String, dynamic>{
      'pageSize': pageSize.toString(),
      if (pageToken != null) 'pageToken': pageToken,
    };
    final response = await _httpClient.get('files', queryParameters: params);
    return PaginatedResponse.fromJson(response, 'files', File.fromJson);
  }

  Future<void> delete(String fileName) async {
    await _httpClient.delete('files/$fileName');
  }

  Future<File> upload(
    List<int> fileBytes,
    String mimeType, {
    String? displayName,
    Function(int, int)? onProgress,
  }) async {
    final response = await _uploadClient.upload(
      'files',
      fileBytes,
      mimeType,
      displayName: displayName,
      onProgress: onProgress,
    );
    return File.fromJson(response['file']);
  }
}
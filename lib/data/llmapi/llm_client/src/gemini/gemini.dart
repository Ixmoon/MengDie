// lib/src/gemini/gemini.dart

// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'package:dio/dio.dart';
import 'dart:async';

import 'imagen_model.dart';
import 'live_model.dart';
import 'music_model.dart';
import 'video_model.dart';
import 'models.dart';
import 'http/http_client.dart';
import 'http/stream_client.dart';
import 'http/upload_client.dart';
import 'services/file_service.dart';
import 'services/model_service.dart';
import 'services/tuning_service.dart';
import 'services/auth_token_service.dart';
import 'services/corpora_service.dart';
import 'services/document_service.dart';
import 'services/chunk_service.dart';
import 'services/permission_service.dart';
import 'services/cached_content_service.dart';
import 'services/batch_service.dart';
import 'chat_manager.dart';

export 'models.dart';
export 'models/cache.dart';
export 'chat_session.dart';
export 'imagen_model.dart' show ImagenModel;
export 'video_model.dart' show VideoModel;
export 'music_model.dart' show MusicModel, MusicSession;
export 'live_model.dart' show LiveModel, LiveSession;
export 'gemini_exception.dart' show GeminiApiException;
export 'services/file_service.dart' show FileService;
export 'services/model_service.dart' show ModelService;
export 'services/tuning_service.dart' show TuningService;
export 'services/auth_token_service.dart' show AuthTokenService;
export 'services/corpora_service.dart' show CorporaService;
export 'services/document_service.dart' show DocumentService;
export 'services/chunk_service.dart' show ChunkService;
export 'services/cached_content_service.dart' show CachedContentService;
export 'services/batch_service.dart' show BatchService;

/// A centralized utility to get the final authentication token.
/// It prioritizes the explicitly provided [authToken], and falls back to the
/// client's default [apiKey]. Throws an error if neither is available.
String getAuthToken(String? authToken, HttpClient client) {
  final token = authToken ?? client.apiKey;
  if (token.isEmpty) {
    throw ArgumentError(
        'Authentication failed: No API key or auth token was provided.');
  }
  return token;
}

/// The main entry point for the Gemini API.
class Gemini {
  final String _baseUrl;
  final HttpClient _httpClient;
  final StreamClient _streamClient;
  final UploadClient _uploadClient;

  /// Access the File API.
  late final FileService files;

  /// Access model information.
  late final ModelService models;

  /// Access tuned model services.
  late final TuningService tunedModels;
  
  /// Access authentication token services.
  late final AuthTokenService authTokens;

  /// Access corpora services.
  late final CorporaService corpora;

  /// Access document services.
  late final DocumentService documents;

  /// Access chunk services.
  late final ChunkService chunks;

  /// Access permission services.
  late final PermissionService permissions;

  /// Access cached content services.
  late final CachedContentService cachedContents;

  /// Access batch services for long-running operations.
  late final BatchService batches;

  /// Access chat creation services.
  late final ChatManager chats;
  
  static const String _defaultBaseUrl = 'https://generativelanguage.googleapis.com';

  Gemini._(this._baseUrl, this._httpClient, this._streamClient, this._uploadClient) {
    files = FileService(httpClient: _httpClient, uploadClient: _uploadClient);
    models = ModelService(httpClient: _httpClient);
    tunedModels = TuningService(httpClient: _httpClient);
    authTokens = AuthTokenService(httpClient: _httpClient);
    corpora = CorporaService(httpClient: _httpClient);
    documents = DocumentService(httpClient: _httpClient);
    chunks = ChunkService(httpClient: _httpClient);
    permissions = PermissionService(httpClient: _httpClient);
    cachedContents = CachedContentService(httpClient: _httpClient);
    batches = BatchService(httpClient: _httpClient);
    chats = ChatManager(httpClient: _httpClient, streamClient: _streamClient);
  }

  factory Gemini({required String apiKey, String? baseUrl, Dio? dio}) {
    final aio = dio ?? Dio();
    final effectiveBaseUrl = baseUrl ?? _defaultBaseUrl;
    final httpClient = HttpClient(apiKey: apiKey, dio: aio, baseUrl: effectiveBaseUrl);
    final streamClient = StreamClient(dio: aio, httpClient: httpClient);
    final uploadClient = UploadClient(apiKey: apiKey, dio: aio, httpClient: httpClient, baseUrl: effectiveBaseUrl);
    return Gemini._(effectiveBaseUrl, httpClient, streamClient, uploadClient);
  }

  // ----------------- Public API Implementations -----------------

  Future<GenerateContentResponse> generateContent(
          String model, GenerateContentRequest request) =>
      _generateContent(model, request);

  Stream<GenerateContentResponse> streamGenerateContent(
          String model, GenerateContentRequest request) =>
      _streamGenerateContent(model, request);

  Future<CountTokensResponse> countTokens(
          String model, GenerateContentRequest generateContentRequest) =>
      _countTokens(model, generateContentRequest);

  Future<EmbedContentResponse> embedContent(EmbedContentRequest request) =>
      _embedContent(request);

  Future<BatchEmbedContentsResponse> batchEmbedContents(
          String model, BatchEmbedContentsRequest request) =>
      _batchEmbedContents(model, request);

  Future<GenerateAnswerResponse> generateAnswer(
          String model, GenerateAnswerRequest request) =>
      _generateAnswer(model, request);

  // ----------------- Private API Implementations -----------------

  Future<GenerateAnswerResponse> _generateAnswer(
      String model, GenerateAnswerRequest request) async {
    if (request.safetySettings != null) {
      const supportedCategories = {
        HarmCategory.hateSpeech,
        HarmCategory.sexuallyExplicit,
        HarmCategory.dangerousContent,
        HarmCategory.harassment,
      };
      final unsupported = request.safetySettings!
          .where((s) => !supportedCategories.contains(s.category));
      if (unsupported.isNotEmpty) {
        final unsupportedNames =
            unsupported.map((s) => s.category.name).join(', ');
        throw ArgumentError(
            'generateAnswer only supports HATE_SPEECH, SEXUALLY_EXPLICIT, DANGEROUS_CONTENT, and HARASSMENT safety categories. Unsupported categories provided: $unsupportedNames');
      }
    }
    final body = <String, dynamic>{
      'contents': request.contents.map((c) => c.toJson(includeRole: true)).toList(),
      'answerStyle': request.answerStyle.name.toUpperCase(),
      if (request.safetySettings != null)
        'safetySettings': request.safetySettings!.map((s) => s.toJson()).toList(),
      if (request.temperature != null) 'temperature': request.temperature,
    };

    if (request.inlinePassages != null) {
      body['inlinePassages'] = request.inlinePassages!.toJson();
    } else if (request.semanticRetriever != null) {
      body['semanticRetriever'] = request.semanticRetriever!.toJson();
    }

    final response =
        await _httpClient.post('${_modelPath(model)}:generateAnswer', body);
    return GenerateAnswerResponse.fromJson(response);
  }

  Future<GenerateContentResponse> _generateContent(
      String model, GenerateContentRequest request) async {
    final body = buildGenerateContentBody(request);

    final response = await _httpClient.post(
      '${_modelPath(model)}:generateContent',
      body,
    );

    return GenerateContentResponse.fromJson(response);
  }

  Stream<GenerateContentResponse> _streamGenerateContent(
      String model, GenerateContentRequest request) {
    final body = buildGenerateContentBody(request);

    return _streamClient
        .stream('${_modelPath(model)}:streamGenerateContent', body)
        .map(GenerateContentResponse.fromJson);
  }

  Future<CountTokensResponse> _countTokens(
      String model, GenerateContentRequest generateContentRequest) async {
    final body = buildGenerateContentBody(generateContentRequest);
    final response =
        await _httpClient.post('${_modelPath(model)}:countTokens', body);
    return CountTokensResponse.fromJson(response);
  }

  Future<EmbedContentResponse> _embedContent(EmbedContentRequest request) async {
    final body = request.toJson();
    final response =
        await _httpClient.post('${_modelPath(request.model)}:embedContent', body);
    return EmbedContentResponse.fromJson(response);
  }

  Future<BatchEmbedContentsResponse> _batchEmbedContents(
      String model, BatchEmbedContentsRequest request) async {
    final requests = request.requests
        .map((r) => r.toJson())
        .toList();
    final body = {'requests': requests};

    final response =
        await _httpClient.post('${_modelPath(model)}:batchEmbedContents', body);
    return BatchEmbedContentsResponse.fromJson(response);
  }

  // ----------------- Private Helper Methods -----------------

  String _modelPath(String model) {
      if (model.startsWith('models/') || model.startsWith('tunedModels/')) {
        return model;
      }
      return 'models/$model';
    }

  /// Returns an [ImagenModel] for the given model name.
  ImagenModel imagenModel({required String model}) {
    // This might need further refactoring if ImagenModel has complex dependencies
    return ImagenModel(client: _httpClient, model: model);
  }

  /// Returns a [VideoModel] for the given model name.
  VideoModel videoModel({required String model}) {
    // This might need further refactoring if VideoModel has complex dependencies
    return VideoModel(client: _httpClient, model: model);
  }

  /// Returns a [MusicModel] for the given model name.
  MusicModel musicModel({required String model}) {
    // This might need further refactoring if MusicModel has complex dependencies
    return MusicModel(client: _httpClient, model: model, baseUrl: _baseUrl);
  }

  /// Returns a [LiveModel] for real-time interactions.
  LiveModel liveModel({required String model, String? authToken}) {
    return LiveModel(
        model: model, client: _httpClient, authToken: authToken, baseUrl: _baseUrl);
  }
}
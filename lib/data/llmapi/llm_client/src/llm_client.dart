
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:dio/dio.dart';

import 'gemini/gemini.dart' as gemini;
import 'gemini/chat_manager.dart' as gemini_chat;
import 'gemini/services/permission_service.dart' as gemini_service;
import 'llm_service.dart';
import 'openai_adapter.dart';

/// An enumeration of the supported LLM providers.
enum LlmProvider {
  gemini,
  openAI,
}

/// The main entry point for the LLM library.
///
/// This client provides a unified interface to interact with different
/// underlying LLM providers like Google Gemini or OpenAI.
class LlmClient implements LlmService {
  final LlmService _service;

  /// Private constructor for internal use by the factory.
  LlmClient._internal(this._service);

  /// Factory constructor to create an [LlmClient] instance.
  ///
  /// Initializes the appropriate LLM service provider based on the
  /// [provider] parameter.
  ///
  /// - [provider]: The desired LLM provider (e.g., [LlmProvider.gemini]).
  /// - [apiKey]: The API key for the selected provider.
  /// - [dio]: An optional [Dio] instance for network requests.
  factory LlmClient(
      {required LlmProvider provider,
      required String apiKey,
      Dio? dio,
      String? baseUrl}) {
    final LlmService service;
    switch (provider) {
      case LlmProvider.gemini:
        service =
            _GeminiAdapter(gemini.Gemini(apiKey: apiKey, dio: dio, baseUrl: baseUrl));
        break;
      case LlmProvider.openAI:
        service = OpenAIAdapter(apiKey: apiKey, dio: dio, baseUrl: baseUrl);
        break;
    }
    return LlmClient._internal(service);
  }

  // --- Delegated LlmService Members ---

  @override
  gemini.AuthTokenService get authTokens => _service.authTokens;

  @override
  gemini.FileService get files => _service.files;

  @override
  gemini.ModelService get models => _service.models;

  @override
  gemini.TuningService get tunedModels => _service.tunedModels;

  @override
  gemini.CorporaService get corpora => _service.corpora;

  @override
  gemini.DocumentService get documents => _service.documents;

  @override
  gemini.ChunkService get chunks => _service.chunks;

  @override
  gemini_chat.ChatManager get chats => _service.chats;

  @override
  gemini_service.PermissionService get permissions => _service.permissions;

  @override
  gemini.ImagenModel imagenModel({required String model}) =>
      _service.imagenModel(model: model);

  @override
  gemini.LiveModel liveModel({required String model, String? authToken}) =>
      _service.liveModel(model: model, authToken: authToken);

  @override
  gemini.MusicModel musicModel({required String model}) =>
      _service.musicModel(model: model);

  @override
  gemini.VideoModel videoModel({required String model}) =>
      _service.videoModel(model: model);

  @override
  Future<void> createAssistant(String instructions) =>
      _service.createAssistant(instructions);

  @override
  Future<gemini.GenerateContentResponse> generateContent(
          String model, gemini.GenerateContentRequest request) =>
      _service.generateContent(model, request);

  @override
  Stream<gemini.GenerateContentResponse> streamGenerateContent(
          String model, gemini.GenerateContentRequest request) =>
      _service.streamGenerateContent(model, request);

  @override
  Future<gemini.CountTokensResponse> countTokens(
          String model, gemini.GenerateContentRequest request) =>
      _service.countTokens(model, request);

  @override
  Future<gemini.EmbedContentResponse> embedContent(
          gemini.EmbedContentRequest request) =>
      _service.embedContent(request);

  @override
  Future<gemini.BatchEmbedContentsResponse> batchEmbedContents(
          String model, gemini.BatchEmbedContentsRequest request) =>
      _service.batchEmbedContents(model, request);

  @override
  Future<gemini.GenerateAnswerResponse> generateAnswer(
          String model, gemini.GenerateAnswerRequest request) =>
      _service.generateAnswer(model, request);
}

/// An adapter to make the [gemini.Gemini] class compatible with the [LlmService] interface.
class _GeminiAdapter implements LlmService {
  final gemini.Gemini _gemini;

  _GeminiAdapter(this._gemini);

  @override
  gemini.AuthTokenService get authTokens => _gemini.authTokens;

  @override
  gemini.FileService get files => _gemini.files;

  @override
  gemini.ModelService get models => _gemini.models;

  @override
  gemini.TuningService get tunedModels => _gemini.tunedModels;

  @override
  gemini.CorporaService get corpora => _gemini.corpora;

  @override
  gemini.DocumentService get documents => _gemini.documents;

  @override
  gemini.ChunkService get chunks => _gemini.chunks;

  @override
  gemini_chat.ChatManager get chats => _gemini.chats;

  @override
  gemini_service.PermissionService get permissions => _gemini.permissions;

  @override
  gemini.ImagenModel imagenModel({required String model}) =>
      _gemini.imagenModel(model: model);

  @override
  gemini.LiveModel liveModel({required String model, String? authToken}) =>
      _gemini.liveModel(model: model, authToken: authToken);

  @override
  gemini.MusicModel musicModel({required String model}) =>
      _gemini.musicModel(model: model);

  @override
  gemini.VideoModel videoModel({required String model}) =>
      _gemini.videoModel(model: model);

  @override
  Future<void> createAssistant(String instructions) {
    throw UnsupportedError(
        'createAssistant is only supported for the OpenAI provider.');
  }

  @override
  Future<gemini.GenerateContentResponse> generateContent(
          String model, gemini.GenerateContentRequest request) =>
      _gemini.generateContent(model, request);

  @override
  Stream<gemini.GenerateContentResponse> streamGenerateContent(
          String model, gemini.GenerateContentRequest request) =>
      _gemini.streamGenerateContent(model, request);

  @override
  Future<gemini.CountTokensResponse> countTokens(
          String model, gemini.GenerateContentRequest request) =>
      _gemini.countTokens(model, request);

  @override
  Future<gemini.EmbedContentResponse> embedContent(
          gemini.EmbedContentRequest request) =>
      _gemini.embedContent(request);

  @override
  Future<gemini.BatchEmbedContentsResponse> batchEmbedContents(
          String model, gemini.BatchEmbedContentsRequest request) =>
      _gemini.batchEmbedContents(model, request);

  @override
  Future<gemini.GenerateAnswerResponse> generateAnswer(
          String model, gemini.GenerateAnswerRequest request) =>
      _gemini.generateAnswer(model, request);
}
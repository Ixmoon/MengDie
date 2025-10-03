import 'gemini/gemini.dart' as gemini;
import 'gemini/chat_manager.dart' as gemini;
import 'gemini/services/permission_service.dart' as gemini_service;

/// Defines the standard interface for all LLM services in this library.
///
/// This interface mirrors the public API of the `gemini.Gemini` class,
/// establishing it as the standard contract that all compliant providers,
/// including adapters for other services like OpenAI, must adhere to.
abstract class LlmService {
  gemini.AuthTokenService get authTokens;
  gemini.FileService get files;
  gemini.ModelService get models;
  gemini.TuningService get tunedModels;
  gemini.CorporaService get corpora;
  gemini.DocumentService get documents;
  gemini.ChunkService get chunks;
  gemini.ChatManager get chats;
  gemini_service.PermissionService get permissions;

  Future<gemini.GenerateContentResponse> generateContent(
      String model, gemini.GenerateContentRequest request);

  Stream<gemini.GenerateContentResponse> streamGenerateContent(
      String model, gemini.GenerateContentRequest request);

  Future<gemini.CountTokensResponse> countTokens(
      String model, gemini.GenerateContentRequest request);

  Future<gemini.EmbedContentResponse> embedContent(
      gemini.EmbedContentRequest request);

  Future<gemini.BatchEmbedContentsResponse> batchEmbedContents(
      String model, gemini.BatchEmbedContentsRequest request);

  gemini.ImagenModel imagenModel({required String model});

  gemini.VideoModel videoModel({required String model});

  gemini.MusicModel musicModel({required String model});

  gemini.LiveModel liveModel({required String model, String? authToken});

  Future<void> createAssistant(String instructions);

  Future<gemini.GenerateAnswerResponse> generateAnswer(
      String model, gemini.GenerateAnswerRequest request);
}

// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'chat_session.dart';
import 'http/http_client.dart';
import 'http/stream_client.dart';
import 'models.dart';

/// Manages chat sessions with the Gemini model.
///
/// This class provides a factory method [startChat] to create new
/// [ChatSession] instances.
class ChatManager {
  final HttpClient _httpClient;
  final StreamClient _streamClient;

  ChatManager(
      {required HttpClient httpClient, required StreamClient streamClient})
      : _httpClient = httpClient,
        _streamClient = streamClient;

  /// Starts a new chat session.
  ///
  /// The [history] parameter can be used to provide an initial set of
  /// messages for the chat.
  ChatSession startChat({
    required String model,
    List<Content>? history,
    GenerationConfig? generationConfig,
    List<SafetySetting>? safetySettings,
    List<Tool>? tools,
    ToolConfig? toolConfig,
    SystemInstruction? systemInstruction,
  }) {
    // Capture session-level settings
    final sessionGenerationConfig = generationConfig;
    final sessionSafetySettings = safetySettings;
    final sessionTools = tools;
    final sessionToolConfig = toolConfig;

    Future<GenerateContentResponse> generateContent(
      List<Content> history, {
      GenerationConfig? generationConfig,
      List<SafetySetting>? safetySettings,
      List<Tool>? tools,
      ToolConfig? toolConfig,
    }) async {
      final effectiveGenerationConfig =
          generationConfig ?? sessionGenerationConfig;
      final effectiveSafetySettings = safetySettings ?? sessionSafetySettings;
      final effectiveTools = tools ?? sessionTools;
      final effectiveToolConfig = toolConfig ?? sessionToolConfig;

      final request = GenerateContentRequest(
        contents: history,
        generationConfig: effectiveGenerationConfig,
        safetySettings: effectiveSafetySettings,
        tools: effectiveTools,
        toolConfig: effectiveToolConfig,
        systemInstruction: systemInstruction,
      );
      final body = buildGenerateContentBody(request);
      final response =
          await _httpClient.post('models/$model:generateContent', body);
      return GenerateContentResponse.fromJson(response);
    }

    Stream<GenerateContentResponse> streamGenerateContent(
      List<Content> history, {
      GenerationConfig? generationConfig,
      List<SafetySetting>? safetySettings,
      List<Tool>? tools,
      ToolConfig? toolConfig,
    }) {
      final effectiveGenerationConfig =
          generationConfig ?? sessionGenerationConfig;
      final effectiveSafetySettings = safetySettings ?? sessionSafetySettings;
      final effectiveTools = tools ?? sessionTools;
      final effectiveToolConfig = toolConfig ?? sessionToolConfig;

      final request = GenerateContentRequest(
        contents: history,
        generationConfig: effectiveGenerationConfig,
        safetySettings: effectiveSafetySettings,
        tools: effectiveTools,
        toolConfig: effectiveToolConfig,
        systemInstruction: systemInstruction,
      );
      final body = buildGenerateContentBody(request);
      return _streamClient
          .stream('models/$model:streamGenerateContent', body)
          .map(GenerateContentResponse.fromJson);
    }

    return ChatSession(
      generateContent: generateContent,
      streamGenerateContent: streamGenerateContent,
      history: history ?? [],
    );
  }
}
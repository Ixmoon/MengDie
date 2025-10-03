
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';

import 'common/pagination.dart';
import 'llm_service.dart';
import 'gemini/gemini.dart' as gemini;
import 'gemini/chat_manager.dart' as gemini_chat;
import 'gemini/services/model_service.dart' as gemini_service;
import 'gemini/services/permission_service.dart' as gemini_permission;
import 'gemini/gemini_exception.dart' as gemini_exception;
import 'openai/openai.dart' as openai;
import 'openai/models.dart' as openai_models;
import 'openai/openai_exception.dart';
import 'common/utils.dart';

/// An adapter to make the OpenAI API compatible with the [LlmService] interface.
class OpenAIAdapter implements LlmService, gemini_chat.ChatManager {
  final openai.CustomOpenAI _client;

  OpenAIAdapter({required String apiKey, Dio? dio, String? baseUrl})
      : _client = openai.CustomOpenAI(
          apiKey: apiKey,
          dio: dio,
          baseUrl: baseUrl ?? 'https://api.openai.com/v1/',
        );

  @override
  gemini.AuthTokenService get authTokens =>
      throw UnimplementedError('AuthTokenService is not available for OpenAI.');

  @override
  gemini.FileService get files =>
      throw UnimplementedError('FileService is not available for OpenAI.');

  @override
  gemini_service.ModelService get models => _OpenAIModelServiceAdapter(_client);

  @override
  gemini.TuningService get tunedModels =>
      throw UnimplementedError('TuningService is not available for OpenAI.');

  @override
  gemini.CorporaService get corpora =>
      throw UnimplementedError('CorporaService is not available for OpenAI.');

  @override
  gemini.DocumentService get documents =>
      throw UnimplementedError('DocumentService is not available for OpenAI.');

  @override
  gemini.ChunkService get chunks =>
      throw UnimplementedError('ChunkService is not available for OpenAI.');

  @override
  gemini_chat.ChatManager get chats => this;

  @override
  gemini_permission.PermissionService get permissions =>
      throw UnimplementedError('PermissionService is not available for OpenAI.');

  @override
  gemini.ChatSession startChat(
      {required String model,
      List<gemini.Content>? history,
      gemini.GenerationConfig? generationConfig,
      List<gemini.SafetySetting>? safetySettings,
      List<gemini.Tool>? tools,
      gemini.ToolConfig? toolConfig,
      gemini.SystemInstruction? systemInstruction}) {
    return gemini.ChatSession(
      history: history ?? [],
      generateContent: (history,
          {generationConfig, safetySettings, tools, toolConfig}) {
        final request = gemini.GenerateContentRequest(
          contents: history,
          generationConfig: generationConfig,
          safetySettings: safetySettings,
          tools: tools,
          toolConfig: toolConfig,
          systemInstruction: systemInstruction,
        );
        return generateContent(model, request);
      },
      streamGenerateContent: (history,
          {generationConfig, safetySettings, tools, toolConfig}) {
        final request = gemini.GenerateContentRequest(
          contents: history,
          generationConfig: generationConfig,
          safetySettings: safetySettings,
          tools: tools,
          toolConfig: toolConfig,
          systemInstruction: systemInstruction,
        );
        return streamGenerateContent(model, request);
      },
    );
  }

  @override
  gemini.ImagenModel imagenModel({required String model}) =>
      throw UnimplementedError('ImagenModel is not available for OpenAI.');

  @override
  gemini.LiveModel liveModel({required String model, String? authToken}) =>
      throw UnimplementedError('LiveModel is not available for OpenAI.');

  @override
  gemini.MusicModel musicModel({required String model}) =>
      throw UnimplementedError('MusicModel is not available for OpenAI.');

  @override
  gemini.VideoModel videoModel({required String model}) =>
      throw UnimplementedError('VideoModel is not available for OpenAI.');

  @override
  Future<void> createAssistant(String instructions) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<gemini.GenerateContentResponse> generateContent(
      String model, gemini.GenerateContentRequest request) async {
    try {
      final requestContents = processContents(request.contents);
      final openAIMessages = _convertContentToOpenAIMessages(
          requestContents, request.systemInstruction);
      final openAITools = _convertToolsToOpenAI(request.tools);
      final openAIToolChoice = _convertToolChoiceToString(request.toolConfig);

      final response = await _client.chat.create(
        model: model,
        messages: openAIMessages,
        temperature: request.generationConfig?.temperature,
        topP: request.generationConfig?.topP,
        maxTokens: request.generationConfig?.maxOutputTokens,
        n: request.generationConfig?.candidateCount,
        stop: request.generationConfig?.stopSequences,
        tools: openAITools,
        toolChoice: openAIToolChoice,
      );

      return _convertResponseFromOpenAI(response);
    } on OpenAIApiException catch (e) {
      throw gemini_exception.GeminiApiException(
        message: e.message ?? 'An unknown OpenAI API error occurred.',
        originalException: e,
      );
    }
  }

  @override
  Stream<gemini.GenerateContentResponse> streamGenerateContent(
      String model, gemini.GenerateContentRequest request) {
    final requestContents = processContents(request.contents);
    final openAIMessages = _convertContentToOpenAIMessages(
        requestContents, request.systemInstruction);
    final openAITools = _convertToolsToOpenAI(request.tools);
    final openAIToolChoice = _convertToolChoiceToString(request.toolConfig);

    final rawStream = _client.chat.createStream(
      model: model,
      messages: openAIMessages,
      temperature: request.generationConfig?.temperature,
      topP: request.generationConfig?.topP,
      maxTokens: request.generationConfig?.maxOutputTokens,
      n: request.generationConfig?.candidateCount,
      stop: request.generationConfig?.stopSequences,
      tools: openAITools,
      toolChoice: openAIToolChoice,
    );

    return _aggregateOpenAIStreamChunks(rawStream).handleError((error) {
      if (error is OpenAIApiException) {
        throw gemini_exception.GeminiApiException(
          message:
              error.message ?? 'An error occurred during the OpenAI stream.',
          originalException: error,
        );
      }
      throw error;
    });
  }

  @override
  Future<gemini.CountTokensResponse> countTokens(
      String model, gemini.GenerateContentRequest request) {
    throw UnimplementedError('countTokens is not implemented for OpenAI.');
  }

  @override
  Future<gemini.EmbedContentResponse> embedContent(
      gemini.EmbedContentRequest request) async {
    final text = request.content.parts
        .whereType<gemini.TextPart>()
        .map((p) => p.text)
        .join('\n');
    final response = await _client.embeddings.create(
      model: request.model.replaceFirst('models/', ''),
      input: text,
    );
    return gemini.EmbedContentResponse(
      gemini.ContentEmbedding(
        response.data.first.embedding.map((e) => e.toDouble()).toList(),
      ),
    );
  }

  @override
  Future<gemini.BatchEmbedContentsResponse> batchEmbedContents(
      String model, gemini.BatchEmbedContentsRequest request) async {
    final inputs = request.requests
        .map((r) => r.content.parts
            .whereType<gemini.TextPart>()
            .map((p) => p.text)
            .join('\n'))
        .toList();

    final response = await _client.embeddings.create(
      model: model,
      input: inputs,
    );
    final embeddings = response.data
        .map((e) =>
            gemini.ContentEmbedding(e.embedding.map((e) => e.toDouble()).toList()))
        .toList();
    return gemini.BatchEmbedContentsResponse(embeddings);
  }

  @override
  Future<gemini.GenerateAnswerResponse> generateAnswer(
      String model, gemini.GenerateAnswerRequest request) {
    throw UnsupportedError(
        'generateAnswer is not supported by the OpenAI provider.');
  }
}

class _OpenAIModelServiceAdapter implements gemini_service.ModelService {
  final openai.CustomOpenAI _client;

  _OpenAIModelServiceAdapter(this._client);

  @override
  Future<gemini.ModelInfo> get(String modelName) async {
    final response =
        await _client.models.retrieve(modelName.replaceFirst('models/', ''));
    return _convertOpenAIModelToGeminiModel(response);
  }

  @override
  Future<PaginatedResponse<gemini.ModelInfo>> list(
      {int? pageSize, String? pageToken}) async {
    final response = await _client.models.list();
    final models = response.map(_convertOpenAIModelToGeminiModel).toList();
    // OpenAI's list models endpoint doesn't support pagination, so we return all models at once.
    return PaginatedResponse(items: models, nextPageToken: null);
  }

  gemini.ModelInfo _convertOpenAIModelToGeminiModel(
      openai_models.OpenAIModelInfo model) {
    return gemini.ModelInfo(
      name: 'models/${model.id}',
      version: '1', // OpenAI API doesn't provide versioning info in this object
      displayName: model.id,
      description: 'Owned by ${model.ownedBy}',
      inputTokenLimit: 0, // Not provided by OpenAI models list endpoint
      outputTokenLimit: 0, // Not provided by OpenAI models list endpoint
      supportedGenerationMethods: [
        'generateContent',
        'embedContent',
        'batchEmbedContents'
      ],
    );
  }
}

// --- Top-level Conversion & Helper Logic ---

List<openai_models.OpenAIChatCompletionChoiceMessageModel>
    _convertContentToOpenAIMessages(Iterable<gemini.Content> contents,
        gemini.SystemInstruction? systemInstruction) {
  final messages =
      contents.map(_convertSingleContentToOpenAIMessage).toList();

  if (systemInstruction != null) {
    final systemPart = systemInstruction.part;
    if (systemPart is gemini.TextPart) {
      messages.insert(
          0,
          openai_models.OpenAIChatCompletionChoiceMessageModel(
            role: openai_models.OpenAIChatMessageRole.system,
            content: [openai_models.OpenAITextMessageContent(systemPart.text)],
          ));
    }
  }
  return messages;
}

openai_models.OpenAIChatCompletionChoiceMessageModel
    _convertSingleContentToOpenAIMessage(gemini.Content content) {
  final role = (content.role == 'model')
      ? openai_models.OpenAIChatMessageRole.assistant
      : openai_models.OpenAIChatMessageRole.user;

  final toolResponsePart =
      content.parts.whereType<gemini.FunctionResponsePart>().firstOrNull;
  if (toolResponsePart != null) {
    return openai_models.OpenAIChatCompletionChoiceMessageModel(
      role: openai_models.OpenAIChatMessageRole.tool,
      toolCallId: toolResponsePart.name,
      content: jsonEncode(toolResponsePart.response),
    );
  }

  final toolCallParts =
      content.parts.whereType<gemini.FunctionCallPart>().toList();
  if (toolCallParts.isNotEmpty) {
    return openai_models.OpenAIChatCompletionChoiceMessageModel(
        role: openai_models.OpenAIChatMessageRole.assistant,
        toolCalls: toolCallParts
            .map((p) => openai_models.OpenAIToolCall(
                  id: p.functionCall.name, // Using name as ID
                  type: 'function',
                  function: openai_models.OpenAIFunctionCall(
                    name: p.functionCall.name,
                    arguments: jsonEncode(p.functionCall.args),
                  ),
                ))
            .toList());
  }

  final contentItems = content.parts
      .map((part) {
        if (part is gemini.TextPart) {
          return openai_models.OpenAITextMessageContent(part.text);
        }
        if (part is gemini.DataPart) {
          final base64Image = base64Encode(part.bytes);
          return openai_models.OpenAIImageUrlMessageContent(
              'data:${part.mimeType};base64,$base64Image');
        }
        return null;
      })
      .whereType<
          openai_models.OpenAIChatCompletionChoiceMessageContentItemModel>()
      .toList();

  return openai_models.OpenAIChatCompletionChoiceMessageModel(
    role: role,
    content: contentItems,
  );
}

gemini.GenerateContentResponse _convertResponseFromOpenAI(
    openai_models.OpenAIChatCompletionModel response) {
  final choice = response.choices.first;
  final message = choice.message;
  final parts = <gemini.Part>[];

  if (message.content is String && (message.content as String).isNotEmpty) {
    parts.add(gemini.TextPart(message.content as String));
  }

  if (message.toolCalls != null) {
    for (final toolCall in message.toolCalls!) {
      parts.add(gemini.FunctionCallPart(gemini.FunctionCall(
        toolCall.function.name ?? '',
        toolCall.function.arguments != null
            ? jsonDecode(toolCall.function.arguments!)
            : {},
      )));
    }
  }

  final candidate = gemini.Candidate(
    gemini.Content('model', parts),
    _convertFinishReason(choice.finishReason),
    [], // OpenAI does not provide safety ratings in this response
    index: choice.index,
  );

  return gemini.GenerateContentResponse(
    [candidate],
    null, // OpenAI does not provide prompt feedback
    response.usage != null
        ? gemini.UsageMetadata(
            promptTokenCount: response.usage!.promptTokens,
            candidatesTokenCount: response.usage!.completionTokens,
            totalTokenCount: response.usage!.totalTokens,
          )
        : null,
  );
}

Stream<gemini.GenerateContentResponse> _aggregateOpenAIStreamChunks(
    Stream<openai_models.OpenAIChatCompletionModel> stream) {
  return stream.map((chunk) {
    final choice = chunk.choices.first;
    final delta = choice.delta!;
    final parts = <gemini.Part>[];

    if (delta.content != null && delta.content!.isNotEmpty) {
      parts.add(gemini.TextPart(delta.content!));
    }

    if (delta.toolCalls != null) {
      for (final toolCall in delta.toolCalls!) {
        parts.add(gemini.FunctionCallPart(gemini.FunctionCall(
          toolCall.function.name ?? '',
          toolCall.function.arguments != null
              ? jsonDecode(toolCall.function.arguments!)
              : {},
        )));
      }
    }

    return gemini.GenerateContentResponse(
      [
        gemini.Candidate(
          gemini.Content('model', parts),
          _convertFinishReason(choice.finishReason),
          [],
          index: choice.index,
        )
      ],
      null,
      chunk.usage != null
          ? gemini.UsageMetadata(
              promptTokenCount: chunk.usage!.promptTokens,
              candidatesTokenCount: chunk.usage!.completionTokens,
              totalTokenCount: chunk.usage!.totalTokens,
            )
          : null,
    );
  });
}

gemini.FinishReason? _convertFinishReason(String? reason) {
  if (reason == null) return null;
  return switch (reason) {
    'stop' => gemini.FinishReason.stop,
    'length' => gemini.FinishReason.maxTokens,
    'tool_calls' => gemini.FinishReason.stop,
    'content_filter' => gemini.FinishReason.safety,
    _ => gemini.FinishReason.other,
  };
}

List<openai_models.OpenAITool>? _convertToolsToOpenAI(
    List<gemini.Tool>? tools) {
  if (tools == null) return null;
  return tools
      .map((tool) {
        if (tool.functionDeclarations == null) return null;
        return tool.functionDeclarations!
            .map((dec) => openai_models.OpenAITool(
                  function: openai_models.OpenAIFunction(
                    name: dec.name,
                    description: dec.description,
                    parameters: dec.parameters ?? const {},
                  ),
                ));
      })
      .whereType<Iterable<openai_models.OpenAITool>>()
      .expand((e) => e)
      .toList();
}

String? _convertToolChoiceToString(gemini.ToolConfig? toolConfig) {
  if (toolConfig == null) {
    return 'auto';
  }

  final config = toolConfig.functionCallingConfig;
  final mode = config.mode;
  final allowedFunctionNames = config.allowedFunctionNames;

  if (mode == gemini.FunctionCallingMode.any) {
    return 'required';
  } else if (mode == gemini.FunctionCallingMode.none) {
    return 'none';
  } else if (mode == gemini.FunctionCallingMode.auto) {
    return 'auto';
  } else if (allowedFunctionNames != null && allowedFunctionNames.isNotEmpty) {
    return jsonEncode({
      "type": "function",
      "function": {"name": allowedFunctionNames.first},
    });
  } else {
    return 'auto';
  }
}

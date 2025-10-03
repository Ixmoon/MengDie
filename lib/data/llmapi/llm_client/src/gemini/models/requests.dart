
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import '../models.dart';
import '../../common/utils.dart';

/// Request for the `generativeModel.generateContent` method.
class GenerateContentRequest {
  /// The content to send to the model.
  final dynamic contents;

  /// The generation configuration.
  final GenerationConfig? generationConfig;

  /// The safety settings.
  final List<SafetySetting>? safetySettings;

  /// The tools to use.
  final List<Tool>? tools;

  /// The tool configuration.
  final ToolConfig? toolConfig;

  /// The cached content.
  final String? cachedContent;

  /// The system instruction.
  final SystemInstruction? systemInstruction;

  GenerateContentRequest({
    required this.contents,
    this.generationConfig,
    this.safetySettings,
    this.tools,
    this.toolConfig,
    this.cachedContent,
    this.systemInstruction,
  });
}

/// Request for the `generativeModel.embedContent` method.
class EmbedContentRequest {
  /// The model to use for the embedding.
  final String model;

  /// The content to embed.
  final Content content;

  /// The task type for the embedding.
  final TaskType? taskType;

  /// The title for the content.
  final String? title;

  /// The output dimensionality for the embedding.
  final int? outputDimensionality;

  EmbedContentRequest({
    required this.model,
    required this.content,
    this.taskType,
    this.title,
    this.outputDimensionality,
  });

  Map<String, dynamic> toJson() => {
        'model': model,
        'content': content.toJson(),
        if (taskType != null) 'taskType': taskType!.toScreamingSnakeCase(),
        if (title != null) 'title': title,
        if (outputDimensionality != null)
          'outputDimensionality': outputDimensionality,
      };
}

/// Request for the `generativeModel.batchEmbedContents` method.
class BatchEmbedContentsRequest {
  /// The list of embed content requests.
  final List<EmbedContentRequest> requests;

  BatchEmbedContentsRequest({required this.requests});
}

class GenerateAnswerRequest {
  final Iterable<Content> contents;
  final AnswerStyle answerStyle;
  final List<SafetySetting>? safetySettings;
  final GroundingPassages? inlinePassages;
  final SemanticRetrieverConfig? semanticRetriever;
  final double? temperature;

  const GenerateAnswerRequest({
    required this.contents,
    required this.answerStyle,
    this.safetySettings,
    this.inlinePassages,
    this.semanticRetriever,
    this.temperature,
  });
}

/// A centralized builder for the request body of generateContent,
/// streamGenerateContent, and countTokens methods.
Map<String, dynamic> buildGenerateContentBody(GenerateContentRequest request) {
  return {
    'contents': request.contents.map((c) => c.toJson(includeRole: true)).toList(),
    if (request.generationConfig != null)
      'generationConfig': request.generationConfig!.toJson(),
    if (request.safetySettings != null)
      'safetySettings': request.safetySettings!.map((s) => s.toJson()).toList(),
    if (request.tools != null)
      'tools': request.tools!.map((t) => t.toJson()).toList(),
    // Use correct snake_case keys as per API documentation
    if (request.toolConfig != null)
      'tool_config': request.toolConfig!.toJson(),
    if (request.cachedContent != null)
      'cachedContent': request.cachedContent,
    // Use correct snake_case keys as per API documentation
    if (request.systemInstruction != null)
      'system_instruction': request.systemInstruction!.toJson(),
  };
}
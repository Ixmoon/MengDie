// lib/src/gemini/models/generative.dart


// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'config.dart';
import 'package:collection/collection.dart';
import 'content.dart';
import 'grounding.dart';
import 'url_context.dart';

/// The response from a `generateContent` call.
class GenerateContentResponse {
  final List<Candidate> candidates;
  final PromptFeedback? promptFeedback;
  final UsageMetadata? usageMetadata;
  final String? modelVersion;
  final String? responseId;

  String? get text => candidates.firstOrNull?.content.parts
      .whereType<TextPart>()
      .map((p) => p.text)
      .join('');

  GenerateContentResponse(this.candidates, this.promptFeedback, this.usageMetadata,
      {this.modelVersion, this.responseId});

  factory GenerateContentResponse.fromJson(Map<String, dynamic> json) {
    return GenerateContentResponse(
      (json['candidates'] as List? ?? [])
          .map((candidateJson) => Candidate.fromJson(candidateJson))
          .toList(),
      json['promptFeedback'] != null
          ? PromptFeedback.fromJson(json['promptFeedback'])
          : null,
      json['usageMetadata'] != null
          ? UsageMetadata.fromJson(json['usageMetadata'])
          : null,
      modelVersion: json['modelVersion'],
      responseId: json['responseId'],
    );
  }
}

/// A candidate response from the model.
class CitationSource {
  final int? startIndex;
  final int? endIndex;
  final String? uri;
  final String? license;

  CitationSource({this.startIndex, this.endIndex, this.uri, this.license});

  factory CitationSource.fromJson(Map<String, dynamic> json) {
    return CitationSource(
      startIndex: json['startIndex'],
      endIndex: json['endIndex'],
      uri: json['uri'],
      license: json['license'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (startIndex != null) 'startIndex': startIndex,
      if (endIndex != null) 'endIndex': endIndex,
      if (uri != null) 'uri': uri,
      if (license != null) 'license': license,
    };
  }
}

class CitationMetadata {
  final List<CitationSource> citationSources;

  CitationMetadata({required this.citationSources});

  factory CitationMetadata.fromJson(Map<String, dynamic> json) {
    return CitationMetadata(
      citationSources: (json['citationSources'] as List? ?? [])
          .map((sourceJson) => CitationSource.fromJson(sourceJson))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'citationSources': citationSources.map((e) => e.toJson()).toList(),
    };
  }
}

class Candidate {
  final Content content;
  final FinishReason? finishReason;
  final List<SafetyRating> safetyRatings;
  final CitationMetadata? citationMetadata;
  final GroundingMetadata? groundingMetadata;
  final List<GroundingAttribution>? groundingAttributions;
  final UrlContextMetadata? urlContextMetadata;
  final int? tokenCount;
  final int? index;
  final double? avgLogprobs;
  final LogprobsResult? logprobsResult;

  Candidate(this.content, this.finishReason, this.safetyRatings,
      {this.citationMetadata,
      this.groundingMetadata,
      this.groundingAttributions,
      this.urlContextMetadata,
      this.tokenCount,
      this.index,
      this.avgLogprobs,
      this.logprobsResult});

  factory Candidate.fromJson(Map<String, dynamic> json) {
    return Candidate(
      Content.fromJson(json['content']),
      json['finishReason'] != null
          ? FinishReason.values.firstWhere(
              (e) =>
                  e.name.toLowerCase() ==
                  (json['finishReason'] as String).toLowerCase(),
              orElse: () => FinishReason.unspecified,
            )
          : null,
      (json['safetyRatings'] as List? ?? [])
          .map((ratingJson) => SafetyRating.fromJson(ratingJson))
          .toList(),
      citationMetadata: json['citationMetadata'] != null
          ? CitationMetadata.fromJson(json['citationMetadata'])
          : null,
      groundingMetadata: json['groundingMetadata'] != null
          ? GroundingMetadata.fromJson(json['groundingMetadata'])
          : null,
      groundingAttributions: (json['groundingAttributions'] as List? ?? [])
          .map((attributionJson) =>
              GroundingAttribution.fromJson(attributionJson))
          .toList(),
      urlContextMetadata: json['urlContextMetadata'] != null
          ? UrlContextMetadata.fromJson(json['urlContextMetadata'])
          : null,
      tokenCount: json['tokenCount'],
      index: json['index'],
      avgLogprobs: json['avgLogprobs'],
      logprobsResult: json['logprobsResult'] != null
          ? LogprobsResult.fromJson(json['logprobsResult'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content.toJson(),
      if (finishReason != null) 'finishReason': finishReason?.name,
      'safetyRatings': safetyRatings.map((e) => e.toJson()).toList(),
      if (citationMetadata != null)
        'citationMetadata': citationMetadata!.toJson(),
      if (groundingMetadata != null) 'groundingMetadata': groundingMetadata,
      if (groundingAttributions != null)
        'groundingAttributions':
            groundingAttributions!.map((e) => e.toJson()).toList(),
      if (urlContextMetadata != null) 'urlContextMetadata': urlContextMetadata,
      if (tokenCount != null) 'tokenCount': tokenCount,
      if (index != null) 'index': index,
      if (avgLogprobs != null) 'avgLogprobs': avgLogprobs,
      if (logprobsResult != null) 'logprobsResult': logprobsResult!.toJson(),
    };
  }
}

/// The reason why the model stopped generating output.
enum FinishReason {
  unspecified,
  stop,
  maxTokens,
  safety,
  recitation,
  other,
  language,
  blocklist,
  prohibitedContent,
  spii,
  malformedFunctionCall,
  imageSafety,
  unexpectedToolCall,
}

/// A safety rating for a specific harm category in a prompt.
class SafetyRating {
  final HarmCategory category;
  final HarmProbability probability;
  final bool? blocked;
  const SafetyRating(this.category, this.probability, {this.blocked});

  factory SafetyRating.fromJson(Map<String, dynamic> json) {
    return SafetyRating(
      HarmCategory.values.firstWhere(
          (e) => 'HARM_CATEGORY_${e.name.toUpperCase()}' == json['category'],
          orElse: () => HarmCategory.unspecified),
      HarmProbability.values.firstWhere(
          (e) => e.name.toUpperCase() == json['probability'],
          orElse: () => HarmProbability.unspecified),
      blocked: json['blocked'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category.name,
      'probability': probability.name,
    };
  }
}

/// Safety feedback for the entire prompt.
class PromptFeedback {
  final BlockReason? blockReason;
  final List<SafetyRating> safetyRatings;
  const PromptFeedback(this.safetyRatings, {this.blockReason});

  factory PromptFeedback.fromJson(Map<String, dynamic> json) {
    return PromptFeedback(
      (json['safetyRatings'] as List? ?? [])
          .map((ratingJson) => SafetyRating.fromJson(ratingJson))
          .toList(),
      blockReason: json['blockReason'] != null
          ? BlockReason.values.firstWhere(
              (e) => e.name.toUpperCase() == json['blockReason'],
              orElse: () => BlockReason.unspecified)
          : null,
    );
  }
}

/// The probability that a harm exists.
enum HarmProbability {
  unspecified,
  negligible,
  low,
  medium,
  high,
}

/// The reason why a prompt was blocked.
enum BlockReason {
  unspecified,
  safety,
  other,
  blocklist,
  prohibitedContent,
  imageSafety,
}

/// Metadata on the token count for a request.
class UsageMetadata {
  final int? promptTokenCount;
  final int? candidatesTokenCount;
  final int? totalTokenCount;
  final int? thoughtsTokenCount;
  final int? cachedContentTokenCount;
  final int? toolUsePromptTokenCount;
  final List<ModalityTokenCount>? promptTokensDetails;
  final List<ModalityTokenCount>? cacheTokensDetails;
  final List<ModalityTokenCount>? candidatesTokensDetails;
  final List<ModalityTokenCount>? toolUsePromptTokensDetails;

  const UsageMetadata({
    this.promptTokenCount,
    this.candidatesTokenCount,
    this.totalTokenCount,
    this.thoughtsTokenCount,
    this.cachedContentTokenCount,
    this.toolUsePromptTokenCount,
    this.promptTokensDetails,
    this.cacheTokensDetails,
    this.candidatesTokensDetails,
    this.toolUsePromptTokensDetails,
  });

  factory UsageMetadata.fromJson(Map<String, dynamic> json) {
    return UsageMetadata(
      promptTokenCount: json['promptTokenCount'] as int? ?? 0,
      candidatesTokenCount: json['candidatesTokenCount'] as int? ?? 0,
      totalTokenCount: json['totalTokenCount'] as int? ?? 0,
      thoughtsTokenCount: json['thoughtsTokenCount'] as int? ?? 0,
      cachedContentTokenCount: json['cachedContentTokenCount'],
      toolUsePromptTokenCount: json['toolUsePromptTokenCount'],
      promptTokensDetails: (json['promptTokensDetails'] as List? ?? [])
          .map((detail) => ModalityTokenCount.fromJson(detail))
          .toList(),
      cacheTokensDetails: (json['cacheTokensDetails'] as List? ?? [])
          .map((detail) => ModalityTokenCount.fromJson(detail))
          .toList(),
      candidatesTokensDetails: (json['candidatesTokensDetails'] as List? ?? [])
          .map((detail) => ModalityTokenCount.fromJson(detail))
          .toList(),
      toolUsePromptTokensDetails: (json['toolUsePromptTokensDetails'] as List? ?? [])
          .map((detail) => ModalityTokenCount.fromJson(detail))
          .toList(),
    );
  }
}

/// Attribution for a source that contributed to an answer.
class GroundingAttribution {
  final AttributionSourceId sourceId;
  final Content content;

  const GroundingAttribution({required this.sourceId, required this.content});

  factory GroundingAttribution.fromJson(Map<String, dynamic> json) {
    return GroundingAttribution(
      sourceId: AttributionSourceId.fromJson(json['sourceId']),
      content: Content.fromJson(json['content']),
    );
  }

  Map<String, dynamic> toJson() => {
        'sourceId': sourceId.toJson(),
        'content': content.toJson(),
      };
}

/// Identifier for the source contributing to this attribution.
class AttributionSourceId {
  final GroundingPassageId? groundingPassage;
  final SemanticRetrieverChunk? semanticRetrieverChunk;

  const AttributionSourceId(
      {this.groundingPassage, this.semanticRetrieverChunk});

  factory AttributionSourceId.fromJson(Map<String, dynamic> json) {
    return AttributionSourceId(
      groundingPassage: json['groundingPassage'] != null
          ? GroundingPassageId.fromJson(json['groundingPassage'])
          : null,
      semanticRetrieverChunk: json['semanticRetrieverChunk'] != null
          ? SemanticRetrieverChunk.fromJson(json['semanticRetrieverChunk'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        if (groundingPassage != null)
          'groundingPassage': groundingPassage!.toJson(),
        if (semanticRetrieverChunk != null)
          'semanticRetrieverChunk': semanticRetrieverChunk!.toJson(),
      };
}

/// Identifier for a part within a `GroundingPassage`.
class GroundingPassageId {
  final String passageId;
  final int? partIndex;

  const GroundingPassageId(
      {required this.passageId, this.partIndex});

  factory GroundingPassageId.fromJson(Map<String, dynamic> json) {
    return GroundingPassageId(
      passageId: json['passageId'],
      partIndex: json['partIndex'],
    );
  }

  Map<String, dynamic> toJson() => {
        'passageId': passageId,
        if (partIndex != null) 'partIndex': partIndex,
      };
}

/// Identifier for a `Chunk` retrieved via Semantic Retriever.
class SemanticRetrieverChunk {
  final String source;
  final String chunk;

  const SemanticRetrieverChunk({required this.source, required this.chunk});

  factory SemanticRetrieverChunk.fromJson(Map<String, dynamic> json) {
    return SemanticRetrieverChunk(
      source: json['source'],
      chunk: json['chunk'],
    );
  }

  Map<String, dynamic> toJson() => {
        'source': source,
        'chunk': chunk,
      };
}

/// Logprobs Result
class LogprobsResult {
  final List<TopCandidates> topCandidates;
  final List<LogprobsCandidate> chosenCandidates;

  const LogprobsResult(
      {required this.topCandidates, required this.chosenCandidates});

  factory LogprobsResult.fromJson(Map<String, dynamic> json) {
    return LogprobsResult(
      topCandidates: (json['topCandidates'] as List? ?? [])
          .map((c) => TopCandidates.fromJson(c))
          .toList(),
      chosenCandidates: (json['chosenCandidates'] as List? ?? [])
          .map((c) => LogprobsCandidate.fromJson(c))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'topCandidates': topCandidates.map((c) => c.toJson()).toList(),
        'chosenCandidates': chosenCandidates.map((c) => c.toJson()).toList(),
      };
}

/// Candidates with top log probabilities at each decoding step.
class TopCandidates {
  final List<LogprobsCandidate> candidates;

  const TopCandidates({required this.candidates});

  factory TopCandidates.fromJson(Map<String, dynamic> json) {
    return TopCandidates(
      candidates: (json['candidates'] as List? ?? [])
          .map((c) => LogprobsCandidate.fromJson(c))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'candidates': candidates.map((c) => c.toJson()).toList(),
      };
}

/// Candidate for the logprobs token and score.
class LogprobsCandidate {
  final String token;
  final int tokenId;
  final double logProbability;

  const LogprobsCandidate(
      {required this.token,
      required this.tokenId,
      required this.logProbability});

  factory LogprobsCandidate.fromJson(Map<String, dynamic> json) {
    return LogprobsCandidate(
      token: json['token'],
      tokenId: json['tokenId'],
      logProbability: json['logProbability'],
    );
  }

  Map<String, dynamic> toJson() => {
        'token': token,
        'tokenId': tokenId,
        'logProbability': logProbability,
      };
}

/// Represents token counting info for a single modality.
class ModalityTokenCount {
  final Modality modality;
  final int tokenCount;

  const ModalityTokenCount({required this.modality, required this.tokenCount});

  factory ModalityTokenCount.fromJson(Map<String, dynamic> json) {
    return ModalityTokenCount(
      modality: Modality.values
          .firstWhere((e) => e.name.toUpperCase() == json['modality']),
      tokenCount: json['tokenCount'],
    );
  }
}

/// Content Part modality
enum Modality {
  unspecified,
  text,
  image,
  video,
  audio,
  document,
}

/// The response from a `batchGenerateContent` call.
class BatchGenerateContentResponse {
  final List<GenerateContentResponse> responses;
  const BatchGenerateContentResponse(this.responses);

  factory BatchGenerateContentResponse.fromJson(Map<String, dynamic> json) {
    final responsesJson = json['responses'] as List;
    return BatchGenerateContentResponse(
        responsesJson.map((r) => GenerateContentResponse.fromJson(r)).toList());
  }
}

/// Information about a specific model.
class ModelInfo {
  final String name;
  final String? baseModelId;
  final String version;
  final String displayName;
  final String description;
  final int inputTokenLimit;
  final int outputTokenLimit;
  final List<String> supportedGenerationMethods;
  final bool? thinking;
  final double? temperature;
  final double? maxTemperature;
  final double? topP;
  final int? topK;

  const ModelInfo(
      {required this.name,
      this.baseModelId,
      required this.version,
      required this.displayName,
      required this.description,
      required this.inputTokenLimit,
      required this.outputTokenLimit,
      required this.supportedGenerationMethods,
      this.thinking,
      this.temperature,
      this.maxTemperature,
      this.topP,
      this.topK});

  factory ModelInfo.fromJson(Map<String, dynamic> json) {
    return ModelInfo(
      name: json['name'],
      baseModelId: json['baseModelId'],
      version: json['version'],
      displayName: json['displayName'] ?? '',
      description: json['description'] ?? '',
      inputTokenLimit: json['inputTokenLimit'],
      outputTokenLimit: json['outputTokenLimit'],
      supportedGenerationMethods:
          List<String>.from(json['supportedGenerationMethods']),
      thinking: json['thinking'],
      temperature: (json['temperature'] as num?)?.toDouble(),
      maxTemperature: (json['maxTemperature'] as num?)?.toDouble(),
      topP: (json['topP'] as num?)?.toDouble(),
      topK: json['topK'],
    );
  }
}

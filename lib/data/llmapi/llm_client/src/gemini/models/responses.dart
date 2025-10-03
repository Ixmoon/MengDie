
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'generative.dart';

/// Response from the `generativeModel.countTokens` method.
class CountTokensResponse {
  /// The total number of tokens.
  final int totalTokens;
  final int? cachedContentTokenCount;
  final List<ModalityTokenCount>? promptTokensDetails;
  final List<ModalityTokenCount>? cacheTokensDetails;

  CountTokensResponse(
      {required this.totalTokens,
      this.cachedContentTokenCount,
      this.promptTokensDetails,
      this.cacheTokensDetails});

  factory CountTokensResponse.fromJson(Map<String, dynamic> json) {
    return CountTokensResponse(
      totalTokens: json['totalTokens'] as int,
      cachedContentTokenCount: json['cachedContentTokenCount'],
      promptTokensDetails: (json['promptTokensDetails'] as List<dynamic>?)
          ?.map((e) => ModalityTokenCount.fromJson(e as Map<String, dynamic>))
          .toList(),
      cacheTokensDetails: (json['cacheTokensDetails'] as List<dynamic>?)
          ?.map((e) => ModalityTokenCount.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// The response from a `generateAnswer` call.
class GenerateAnswerResponse {
  final Candidate? answer;
  final double? answerableProbability;
  final PromptFeedback? inputFeedback;

  GenerateAnswerResponse({
    this.answer,
    this.answerableProbability,
    this.inputFeedback,
  });

  factory GenerateAnswerResponse.fromJson(Map<String, dynamic> json) {
    return GenerateAnswerResponse(
      answer:
          json['answer'] != null ? Candidate.fromJson(json['answer']) : null,
      answerableProbability:
          (json['answerableProbability'] as num?)?.toDouble(),
      inputFeedback: json['inputFeedback'] != null
          ? PromptFeedback.fromJson(json['inputFeedback'])
          : null,
    );
  }
}

/// Style for grounded answers.
enum AnswerStyle {
  abstractive,
  extractive,
  verbose,
  answerStyleUnspecified,
}
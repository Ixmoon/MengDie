// lib/src/gemini/models/grounding.dart


// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

/// Metadata returned to the user grounding the model's response on search results.
class GroundingMetadata {
  final List<String>? webSearchQueries;
  final SearchEntryPoint? searchEntryPoint;
  final RetrievalMetadata? retrievalMetadata;
  final List<GroundingChunk>? groundingChunks;
  final List<GroundingSupport>? groundingSupports;

  const GroundingMetadata({
    this.webSearchQueries,
    this.searchEntryPoint,
    this.retrievalMetadata,
    this.groundingChunks,
    this.groundingSupports,
  });

  factory GroundingMetadata.fromJson(Map<String, dynamic> json) {
    return GroundingMetadata(
      webSearchQueries: json['webSearchQueries'] != null
          ? List<String>.from(json['webSearchQueries'])
          : null,
      searchEntryPoint: json['searchEntryPoint'] != null
          ? SearchEntryPoint.fromJson(json['searchEntryPoint'])
          : null,
      retrievalMetadata: json['retrievalMetadata'] != null
          ? RetrievalMetadata.fromJson(json['retrievalMetadata'])
          : null,
      groundingChunks: (json['groundingChunks'] as List? ?? [])
          .map((c) => GroundingChunk.fromJson(c))
          .toList(),
      groundingSupports: (json['groundingSupports'] as List? ?? [])
          .map((s) => GroundingSupport.fromJson(s))
          .toList(),
    );
  }
}

/// A chunk of web content used for grounding.
class GroundingChunk {
  final WebDetails web;
  const GroundingChunk({required this.web});

  factory GroundingChunk.fromJson(Map<String, dynamic> json) {
    return GroundingChunk(web: WebDetails.fromJson(json['web']));
  }
}

/// Details of a web search result.
class WebDetails {
  final String uri;
  final String title;
  const WebDetails({required this.uri, required this.title});

  factory WebDetails.fromJson(Map<String, dynamic> json) {
    return WebDetails(uri: json['uri'], title: json['title']);
  }
}

/// A segment of the model's response that is supported by a grounding chunk.
class GroundingSupport {
  final TextSegment segment;
  final List<int> groundingChunkIndices;
  final List<double>? confidenceScores;

  const GroundingSupport(
      {required this.segment,
      required this.groundingChunkIndices,
      this.confidenceScores});

  factory GroundingSupport.fromJson(Map<String, dynamic> json) {
    return GroundingSupport(
      segment: TextSegment.fromJson(json['segment']),
      groundingChunkIndices: List<int>.from(json['groundingChunkIndices']),
      confidenceScores: (json['confidenceScores'] as List? ?? [])
          .map<double>((e) => (e as num).toDouble())
          .toList(),
    );
  }
}

/// A segment of text within the model's response.
class TextSegment {
  final int partIndex;
  final int startIndex;
  final int endIndex;
  final String text;

  const TextSegment(
      {required this.partIndex,
      required this.startIndex,
      required this.endIndex,
      required this.text});

  factory TextSegment.fromJson(Map<String, dynamic> json) {
    return TextSegment(
      partIndex: json['partIndex'] ?? 0,
      startIndex: json['startIndex'] ?? 0,
      endIndex: json['endIndex'],
      text: json['text'],
    );
  }
}

/// Google search entry point.
class SearchEntryPoint {
  final String renderedContent;
  final String? sdkBlob;

  const SearchEntryPoint({required this.renderedContent, this.sdkBlob});

  factory SearchEntryPoint.fromJson(Map<String, dynamic> json) {
    return SearchEntryPoint(
      renderedContent: json['renderedContent'],
      sdkBlob: json['sdkBlob'],
    );
  }
}

/// Metadata related to retrieval in the grounding flow.
class RetrievalMetadata {
  final double googleSearchDynamicRetrievalScore;

  const RetrievalMetadata({required this.googleSearchDynamicRetrievalScore});

  factory RetrievalMetadata.fromJson(Map<String, dynamic> json) {
    return RetrievalMetadata(
      googleSearchDynamicRetrievalScore:
          json['googleSearchDynamicRetrievalScore'],
    );
  }
}
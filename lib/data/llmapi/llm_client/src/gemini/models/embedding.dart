// lib/src/gemini/models/embedding.dart


// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

/// The response from an `embedContent` call.
class EmbedContentResponse {
  final ContentEmbedding embedding;
  const EmbedContentResponse(this.embedding);

  factory EmbedContentResponse.fromJson(Map<String, dynamic> json) {
    return EmbedContentResponse(
        ContentEmbedding.fromJson(json['embedding']));
  }
}

/// A list of values for a single embedding.
class ContentEmbedding {
  final List<double> values;
  const ContentEmbedding(this.values);

  factory ContentEmbedding.fromJson(Map<String, dynamic> json) {
    return ContentEmbedding(
        (json['values'] as List).map<double>((e) => (e as num).toDouble()).toList());
  }
}

/// The type of task for which the embedding will be used.
enum TaskType {
  unspecified,
  retrievalQuery,
  retrievalDocument,
  semanticSimilarity,
  classification,
  clustering,
  questionAnswering,
  factVerification,
  codeRetrievalQuery,
}

/// The response from a `batchEmbedContents` call.
class BatchEmbedContentsResponse {
  final List<ContentEmbedding> embeddings;

  const BatchEmbedContentsResponse(this.embeddings);

  factory BatchEmbedContentsResponse.fromJson(Map<String, dynamic> json) {
    return BatchEmbedContentsResponse((json['embeddings'] as List)
        .map((e) => ContentEmbedding.fromJson(e as Map<String, dynamic>))
        .toList());
  }
}
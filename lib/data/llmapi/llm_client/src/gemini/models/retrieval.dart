
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'content.dart';

/// A `Corpus` is a collection of `Document`s.
class Corpus {
  /// The `Corpus` resource name.
  final String? name;

  /// The human-readable display name for the `Corpus`.
  final String? displayName;

  /// The Timestamp of when the `Corpus` was created.
  final String? createTime;

  /// The Timestamp of when the `Corpus` was last updated.
  final String? updateTime;

  Corpus({
    this.name,
    this.displayName,
    this.createTime,
    this.updateTime,
  });

  factory Corpus.fromJson(Map<String, dynamic> json) {
    return Corpus(
      name: json['name'],
      displayName: json['displayName'],
      createTime: json['createTime'],
      updateTime: json['updateTime'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      if (displayName != null) 'displayName': displayName,
      if (createTime != null) 'createTime': createTime,
      if (updateTime != null) 'updateTime': updateTime,
    };
  }
}

/// A `Document` is a collection of `Chunk`s.
class Document {
  /// The `Document` resource name.
  final String? name;

  /// The human-readable display name for the `Document`.
  final String? displayName;

  /// User provided custom metadata stored as key-value pairs.
  final List<CustomMetadata>? customMetadata;

  /// The Timestamp of when the `Document` was last updated.
  final String? updateTime;

  /// The Timestamp of when the `Document` was created.
  final String? createTime;

  Document({
    this.name,
    this.displayName,
    this.customMetadata,
    this.updateTime,
    this.createTime,
  });

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      name: json['name'],
      displayName: json['displayName'],
      customMetadata: (json['customMetadata'] as List<dynamic>?)
          ?.map((e) => CustomMetadata.fromJson(e as Map<String, dynamic>))
          .toList(),
      updateTime: json['updateTime'],
      createTime: json['createTime'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      if (displayName != null) 'displayName': displayName,
      if (customMetadata != null)
        'customMetadata': customMetadata?.map((e) => e.toJson()).toList(),
      if (updateTime != null) 'updateTime': updateTime,
      if (createTime != null) 'createTime': createTime,
    };
  }
}

/// User provided metadata stored as key-value pairs.
class CustomMetadata {
  /// The key of the metadata to store.
  final String? key;

  /// The string value of the metadata to store.
  final String? stringValue;

  /// The StringList value of the metadata to store.
  final StringList? stringListValue;

  /// The numeric value of the metadata to store.
  final double? numericValue;

  CustomMetadata({
    this.key,
    this.stringValue,
    this.stringListValue,
    this.numericValue,
  });

  factory CustomMetadata.fromJson(Map<String, dynamic> json) {
    return CustomMetadata(
      key: json['key'],
      stringValue: json['stringValue'],
      stringListValue: json['stringListValue'] != null
          ? StringList.fromJson(json['stringListValue'])
          : null,
      numericValue: json['numericValue'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (key != null) 'key': key,
      if (stringValue != null) 'stringValue': stringValue,
      if (stringListValue != null) 'stringListValue': stringListValue?.toJson(),
      if (numericValue != null) 'numericValue': numericValue,
    };
  }
}

/// User provided string values assigned to a single metadata key.
class StringList {
  /// The string values of the metadata to store.
  final List<String>? values;

  StringList({this.values});

  factory StringList.fromJson(Map<String, dynamic> json) {
    return StringList(
      values:
          (json['values'] as List<dynamic>?)?.map((e) => e as String).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (values != null) 'values': values,
    };
  }
}

/// A `Chunk` is a subpart of a `Document`.
class Chunk {
  /// The `Chunk` resource name.
  final String? name;

  /// The content for the `Chunk`.
  final ChunkData? data;

  /// User provided custom metadata.
  final List<CustomMetadata>? customMetadata;

  /// The Timestamp of when the `Chunk` was created.
  final String? createTime;

  /// The Timestamp of when the `Chunk` was last updated.
  final String? updateTime;

  /// Current state of the `Chunk`.
  final ChunkState? state;

  Chunk({
    this.name,
    this.data,
    this.customMetadata,
    this.createTime,
    this.updateTime,
    this.state,
  });

  factory Chunk.fromJson(Map<String, dynamic> json) {
    return Chunk(
      name: json['name'],
      data: json['data'] != null ? ChunkData.fromJson(json['data']) : null,
      customMetadata: (json['customMetadata'] as List<dynamic>?)
          ?.map((e) => CustomMetadata.fromJson(e as Map<String, dynamic>))
          .toList(),
      createTime: json['createTime'],
      updateTime: json['updateTime'],
      state: json['state'] != null
          ? ChunkState.values.firstWhere((e) => e.value == json['state'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      if (data != null) 'data': data?.toJson(),
      if (customMetadata != null)
        'customMetadata': customMetadata?.map((e) => e.toJson()).toList(),
      if (createTime != null) 'createTime': createTime,
      if (updateTime != null) 'updateTime': updateTime,
      if (state != null) 'state': state?.value,
    };
  }
}

/// Extracted data that represents the `Chunk` content.
class ChunkData {
  /// The `Chunk` content as a string.
  final String? stringValue;

  ChunkData({this.stringValue});

  factory ChunkData.fromJson(Map<String, dynamic> json) {
    return ChunkData(
      stringValue: json['stringValue'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (stringValue != null) 'stringValue': stringValue,
    };
  }
}

/// States for the lifecycle of a `Chunk`.
enum ChunkState {
  stateUnspecified('STATE_UNSPECIFIED'),
  statePendingProcessing('STATE_PENDING_PROCESSING'),
  stateActive('STATE_ACTIVE'),
  stateFailed('STATE_FAILED');

  const ChunkState(this.value);
  final String value;
}

/// Filter for `Chunk` and `Document` metadata.
class MetadataFilter {
  /// The key of the metadata to filter on.
  final String? key;

  /// The `Condition`s for the given key.
  final List<Condition>? conditions;

  MetadataFilter({this.key, this.conditions});

  factory MetadataFilter.fromJson(Map<String, dynamic> json) {
    return MetadataFilter(
      key: json['key'],
      conditions: (json['conditions'] as List<dynamic>?)
          ?.map((e) => Condition.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (key != null) 'key': key,
      if (conditions != null)
        'conditions': conditions?.map((e) => e.toJson()).toList(),
    };
  }
}

/// Filter condition for a key-value pair.
class Condition {
  /// Operator applied to the key-value pair.
  final Operator? operation;

  /// The string value to filter on.
  final String? stringValue;

  /// The numeric value to filter on.
  final double? numericValue;

  Condition({this.operation, this.stringValue, this.numericValue});

  factory Condition.fromJson(Map<String, dynamic> json) {
    return Condition(
      operation: json['operation'] != null
          ? Operator.values.firstWhere((e) => e.value == json['operation'])
          : null,
      stringValue: json['stringValue'],
      numericValue: json['numericValue'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (operation != null) 'operation': operation?.value,
      if (stringValue != null) 'stringValue': stringValue,
      if (numericValue != null) 'numericValue': numericValue,
    };
  }
}

/// Defines valid operators for metadata filtering.
enum Operator {
  operatorUnspecified('OPERATOR_UNSPECIFIED'),
  less('LESS'),
  lessEqual('LESS_EQUAL'),
  equal('EQUAL'),
  greaterEqual('GREATER_EQUAL'),
  greater('GREATER'),
  notEqual('NOT_EQUAL'),
  includes('INCLUDES'),
  excludes('EXCLUDES');

  const Operator(this.value);
  final String value;
}

/// Information for a chunk relevant to a query.
class RelevantChunk {
  /// `Chunk` relevance to the query.
  final double? chunkRelevanceScore;

  /// `Chunk` associated with the query.
  final Chunk? chunk;

  RelevantChunk({this.chunkRelevanceScore, this.chunk});

  factory RelevantChunk.fromJson(Map<String, dynamic> json) {
    return RelevantChunk(
      chunkRelevanceScore: json['chunkRelevanceScore'],
      chunk: json['chunk'] != null ? Chunk.fromJson(json['chunk']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (chunkRelevanceScore != null)
        'chunkRelevanceScore': chunkRelevanceScore,
      if (chunk != null) 'chunk': chunk?.toJson(),
    };
  }
}

/// A repeated list of passages.
class GroundingPassages {
  /// List of passages.
  final List<GroundingPassage>? passages;

  GroundingPassages({this.passages});

  factory GroundingPassages.fromJson(Map<String, dynamic> json) {
    return GroundingPassages(
      passages: (json['passages'] as List<dynamic>?)
          ?.map((e) => GroundingPassage.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (passages != null)
        'passages': passages?.map((e) => e.toJson()).toList(),
    };
  }
}

/// Passage included inline with a grounding configuration.
class GroundingPassage {
  /// Identifier for the passage.
  final String? id;

  /// Content of the passage.
  final Content? content;

  GroundingPassage({this.id, this.content});

  factory GroundingPassage.fromJson(Map<String, dynamic> json) {
    return GroundingPassage(
      id: json['id'],
      content:
          json['content'] != null ? Content.fromJson(json['content']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (content != null) 'content': content?.toJson(),
    };
  }
}

/// Configuration for retrieving grounding content.
class SemanticRetrieverConfig {
  /// Name of the resource for retrieval.
  final String? source;

  /// Query to use for matching `Chunk`s.
  final Content? query;

  /// Filters for selecting `Document`s and/or `Chunk`s.
  final List<MetadataFilter>? metadataFilters;

  /// Maximum number of relevant `Chunk`s to retrieve.
  final int? maxChunksCount;

  /// Minimum relevance score for retrieved `Chunk`s.
  final double? minimumRelevanceScore;

  SemanticRetrieverConfig({
    this.source,
    this.query,
    this.metadataFilters,
    this.maxChunksCount,
    this.minimumRelevanceScore,
  });

  factory SemanticRetrieverConfig.fromJson(Map<String, dynamic> json) {
    return SemanticRetrieverConfig(
      source: json['source'],
      query: json['query'] != null ? Content.fromJson(json['query']) : null,
      metadataFilters: (json['metadataFilters'] as List<dynamic>?)
          ?.map((e) => MetadataFilter.fromJson(e as Map<String, dynamic>))
          .toList(),
      maxChunksCount: json['maxChunksCount'],
      minimumRelevanceScore: json['minimumRelevanceScore'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (source != null) 'source': source,
      if (query != null) 'query': query?.toJson(),
      if (metadataFilters != null)
        'metadataFilters': metadataFilters?.map((e) => e.toJson()).toList(),
      if (maxChunksCount != null) 'maxChunksCount': maxChunksCount,
      if (minimumRelevanceScore != null)
        'minimumRelevanceScore': minimumRelevanceScore,
    };
  }
}



// lib/src/gemini/models/batch.dart


// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

/// This resource represents a long-running operation that is the result of a
/// network API call.
class Operation {
  final String name;
  final Map<String, dynamic>? metadata;
  final bool done;
  final Map<String, dynamic>? error;
  final Map<String, dynamic>? response;
  final DateTime? createTime;
  final DateTime? updateTime;

  const Operation({
    required this.name,
    this.metadata,
    required this.done,
    this.error,
    this.response,
    this.createTime,
    this.updateTime,
  });

  factory Operation.fromJson(Map<String, dynamic> json) {
    return Operation(
      name: json['name'],
      metadata: json['metadata'],
      done: json['done'] ?? false,
      error: json['error'],
      response: json['response'],
      createTime:
          json['createTime'] != null ? DateTime.parse(json['createTime']) : null,
      updateTime:
          json['updateTime'] != null ? DateTime.parse(json['updateTime']) : null,
    );
  }
}

/// The state of a batch job.
enum JobState {
  jobStateUnspecified,
  jobStatePending,
  jobStateRunning,
  jobStateSucceeded,
  jobStateFailed,
  jobStateCancelled,
}

/// Response from `batches.list` containing a paginated list of Operations.
class ListOperationsResponse {
  /// The returned Operations.
  final List<Operation> operations;

  /// A token, which can be sent as `pageToken` to retrieve the next page.
  ///
  /// If this field is omitted, there are no more pages.
  final String? nextPageToken;

  const ListOperationsResponse({
    required this.operations,
    this.nextPageToken,
  });

  factory ListOperationsResponse.fromJson(Map<String, dynamic> json) {
    return ListOperationsResponse(
      operations: (json['operations'] as List<dynamic>? ?? [])
          .map((e) => Operation.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextPageToken: json['nextPageToken'],
    );
  }
}
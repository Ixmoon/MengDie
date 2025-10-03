import 'dart:async';

import '../http/http_client.dart';
import '../models/batch.dart';

/// A utility class to poll long-running operations (LROs).
class LroPoller {
  final HttpClient _httpClient;

  /// Creates an instance of [LroPoller].
  ///
  /// [httpClient] is used to make requests to check the operation status.
  LroPoller(this._httpClient);

  /// Polls a long-running operation until it is completed or fails.
  ///
  /// [startOperation] is a function that initiates the LRO and returns the
  /// initial [Operation] object.
  ///
  /// [responseParser] is a function that parses the successful response
  /// of the operation into an object of type [T].
  ///
  /// [pollingInterval] is the duration to wait between polling requests.
  /// Defaults to 10 seconds.
  ///
  /// [timeout] is the maximum duration to wait for the operation to complete.
  /// If the operation does not complete within this duration, a [TimeoutException]
  /// is thrown.
  ///
  /// [onProgress] is a callback that is invoked with the current [Operation]
  /// status after each polling request.
  Future<T> poll<T>({
    required Future<Operation> Function() startOperation,
    required T Function(Map<String, dynamic>) responseParser,
    Duration pollingInterval = const Duration(seconds: 10),
    Duration? timeout,
    void Function(Operation operation)? onProgress,
  }) async {
    final poller = _poll<T>(
      startOperation: startOperation,
      responseParser: responseParser,
      pollingInterval: pollingInterval,
      onProgress: onProgress,
    );

    if (timeout != null) {
      return poller.timeout(timeout);
    }

    return poller;
  }

  Future<T> _poll<T>({
    required Future<Operation> Function() startOperation,
    required T Function(Map<String, dynamic>) responseParser,
    Duration pollingInterval = const Duration(seconds: 10),
    void Function(Operation operation)? onProgress,
  }) async {
    var currentOperation = await startOperation();
    onProgress?.call(currentOperation);

    while (!currentOperation.done) {
      await Future.delayed(pollingInterval);
      final response = await _httpClient.get(currentOperation.name);
      currentOperation = Operation.fromJson(response);
      onProgress?.call(currentOperation);
    }

    if (currentOperation.error != null) {
      throw Exception('Operation failed: ${currentOperation.error}');
    }

    if (currentOperation.response != null) {
      return responseParser(currentOperation.response!);
    }

    throw Exception('Operation completed but no response was found.');
  }
}
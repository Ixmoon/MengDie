// lib/src/gemini/gemini_exception.dart


// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

/// An exception thrown when an error occurs while interacting with the Gemini API.
class GeminiApiException implements Exception {
  /// A message describing the error, usually from the API response.
  final String? message;

  /// The HTTP status code of the error response.
  final int? statusCode;

  /// The HTTP status message of the error response.
  final String? statusMessage;

  /// The specific error code from the Gemini API (e.g., "invalid_argument").
  final String? code;

  /// The specific error status from the Gemini API (e.g., "INVALID_ARGUMENT").
  final String? status;

  /// The original exception that caused this error, if any (e.g., a DioException).
  final Object? originalException;

  GeminiApiException({
    this.message,
    this.statusCode,
    this.statusMessage,
    this.code,
    this.status,
    this.originalException,
  });

  @override
  String toString() {
    final parts = [
      'GeminiApiException',
      if (statusCode != null) '[$statusCode $statusMessage]',
      if (code != null) '($code)',
      if (message != null) message,
      if (status != null) 'Status: $status',
      if (originalException != null) 'Original Exception: $originalException',
    ];
    return parts.join(' ');
  }
}
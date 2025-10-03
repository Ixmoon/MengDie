// In new file: lib/src/openai/openai_exception.dart

class OpenAIApiException implements Exception {
  final int? statusCode;
  final String? message;
  final String? type;
  final String? code;

  OpenAIApiException({
    this.statusCode,
    this.message,
    this.type,
    this.code,
  });

  @override
  String toString() {
    return 'OpenAIApiException: [$statusCode] $type ($code) - $message';
  }
}
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    required this.retryable,
    this.statusCode,
  });

  final String code;
  final String message;
  final bool retryable;
  final int? statusCode;

  @override
  String toString() => 'ApiException($code, $message)';
}

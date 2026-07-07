class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
    this.code,
    this.fields = const {},
  });

  final String message;
  final int? statusCode;
  final String? code;
  final Map<String, String> fields;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

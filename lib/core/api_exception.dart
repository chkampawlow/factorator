class ApiException implements Exception {
  const ApiException({
    required this.message,
    required this.statusCode,
    this.code,
    this.requestId,
  });

  final String message;
  final int statusCode;
  final String? code;
  final String? requestId;

  @override
  String toString() {
    if (statusCode <= 0) return message;

    final details = <String>['HTTP $statusCode'];
    if (code != null && code!.isNotEmpty) details.add(code!);
    if (requestId != null && requestId!.isNotEmpty) {
      details.add('request $requestId');
    }
    return '$message (${details.join(' • ')})';
  }
}

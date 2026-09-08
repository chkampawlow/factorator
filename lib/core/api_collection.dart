class ApiCollection {
  const ApiCollection._();

  static List<Map<String, dynamic>> parse(
    dynamic response, {
    required Iterable<String> keys,
    required String resourceName,
  }) {
    if (response is List) return _maps(response, resourceName);

    if (response is Map) {
      final envelope = Map<String, dynamic>.from(response);
      if (envelope['success'] == false) {
        throw Exception(envelope['message'] ?? 'Failed to load $resourceName');
      }

      for (final key in keys) {
        final value = envelope[key];
        if (value is List) return _maps(value, resourceName);
      }
    }

    throw Exception('Invalid $resourceName response');
  }

  static List<Map<String, dynamic>> _maps(
    List<dynamic> values,
    String resourceName,
  ) {
    try {
      return values
          .map((value) => Map<String, dynamic>.from(value as Map))
          .toList();
    } on Object {
      throw Exception('Invalid item in $resourceName response');
    }
  }
}

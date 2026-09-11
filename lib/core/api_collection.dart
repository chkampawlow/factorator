class ApiCollection {
  const ApiCollection._();

  /// Fetches a standard paginated API collection until every available row
  /// has been loaded or [maxPages] is reached.
  ///
  /// The backend normally returns `total` and `page_size`. The short-page
  /// fallback keeps this compatible with older endpoints that omit `total`.
  static Future<List<Map<String, dynamic>>> collectPages({
    required Future<dynamic> Function(int page, int pageSize) fetchPage,
    required Iterable<String> keys,
    required String resourceName,
    int pageSize = 100,
    int maxPages = 1000,
  }) async {
    if (pageSize < 1) {
      throw ArgumentError.value(pageSize, 'pageSize', 'Must be positive.');
    }
    if (maxPages < 1) {
      throw ArgumentError.value(maxPages, 'maxPages', 'Must be positive.');
    }

    final rows = <Map<String, dynamic>>[];
    for (var page = 1; page <= maxPages; page++) {
      final response = await fetchPage(page, pageSize);
      final pageRows = parse(
        response,
        keys: keys,
        resourceName: resourceName,
      );
      rows.addAll(pageRows);

      if (pageRows.isEmpty || response is! Map) break;

      final envelope = Map<String, dynamic>.from(response);
      final total = _positiveOrZeroInteger(envelope['total']);
      if (total != null && rows.length >= total) break;

      final responsePageSize =
          _positiveInteger(envelope['page_size']) ?? pageSize;
      if (total == null && pageRows.length < responsePageSize) break;
    }

    return rows;
  }

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

  static int? _positiveOrZeroInteger(dynamic value) {
    final parsed = value is int ? value : int.tryParse('$value');
    return parsed != null && parsed >= 0 ? parsed : null;
  }

  static int? _positiveInteger(dynamic value) {
    final parsed = value is int ? value : int.tryParse('$value');
    return parsed != null && parsed > 0 ? parsed : null;
  }
}

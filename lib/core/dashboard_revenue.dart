List<Map<String, dynamic>> dashboardRevenueRows(Map<String, dynamic> overview) {
  final sales = overview['sales'];
  final accounting = overview['accounting'];
  for (final candidate in [
    overview['monthly_series'],
    if (sales is Map) sales['monthly_series'],
    if (accounting is Map) accounting['monthly_series'],
  ]) {
    if (candidate is! List || candidate.isEmpty) continue;
    final rows = candidate
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    if (rows.isEmpty) continue;
    rows.sort((a, b) => '${a['month']}'.compareTo('${b['month']}'));
    return rows;
  }
  return [];
}

dynamic dashboardRevenueValue(Map<String, dynamic> overview, String key) {
  for (final section in ['sales', 'invoice', 'accounting']) {
    final values = overview[section];
    if (values is Map && values[key] != null) return values[key];
  }
  return overview[key];
}

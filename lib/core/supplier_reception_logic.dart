double receptionNumber(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

bool receptionBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return const {'1', 'true', 'yes'}.contains(value?.toString().toLowerCase());
}

String supplierReceptionLineKey(Map<dynamic, dynamic> line) {
  final catalogId = int.tryParse(
        '${line['catalogId'] ?? line['catalog_id'] ?? 0}',
      ) ??
      0;
  if (catalogId > 0) return 'catalog:$catalogId';

  final code =
      '${line['code'] ?? line['product_code'] ?? ''}'.trim().toLowerCase();
  final type = '${line['itemType'] ?? line['item_type'] ?? 'PRODUCT'}'
      .trim()
      .toUpperCase();
  if (code.isNotEmpty) return 'code:$code|type:$type';

  final name =
      '${line['name'] ?? line['description'] ?? ''}'.trim().toLowerCase();
  final unit = '${line['unit'] ?? 'piece'}'.trim().toLowerCase();
  return 'manual:$name|type:$type|unit:$unit';
}

Map<String, double> confirmedAcceptedQuantities(
  Iterable<Map<String, dynamic>> receptions,
) {
  final accepted = <String, double>{};
  for (final reception in receptions) {
    if (!receptionBool(reception['stockApplied'])) continue;
    final lines = reception['lines'];
    if (lines is! List) continue;
    for (final raw in lines.whereType<Map>()) {
      final key = supplierReceptionLineKey(raw);
      accepted[key] = (accepted[key] ?? 0) +
          receptionNumber(raw['acceptedQty'] ?? raw['qty']);
    }
  }
  return accepted;
}

double remainingSupplierOrderQuantity(
  Map<String, dynamic> orderLine,
  Map<String, double> alreadyAccepted,
) {
  final ordered = receptionNumber(orderLine['qty'] ?? orderLine['orderedQty']);
  final received = alreadyAccepted[supplierReceptionLineKey(orderLine)] ?? 0;
  final remaining = ordered - received;
  return remaining > 0 ? remaining : 0;
}

Map<String, double> supplierReceptionTotals(
  Iterable<Map<String, dynamic>> lines,
) {
  var totalHt = 0.0;
  var totalVat = 0.0;
  for (final line in lines) {
    final quantity = receptionNumber(line['qty']);
    final price = receptionNumber(line['price']);
    final vatRate = receptionNumber(line['tvaRate'] ?? line['tva_rate']);
    final subtotal = quantity * price;
    totalHt += subtotal;
    totalVat += subtotal * vatRate / 100;
  }
  return {
    'totalHt': _roundMoney(totalHt),
    'totalVat': _roundMoney(totalVat),
    'totalTtc': _roundMoney(totalHt + totalVat),
  };
}

double _roundMoney(double value) => (value * 1000).round() / 1000;

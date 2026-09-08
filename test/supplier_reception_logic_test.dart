import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/supplier_reception_logic.dart';

void main() {
  test('remaining quantity only subtracts confirmed stock postings', () {
    final orderLine = <String, dynamic>{'catalogId': 8, 'qty': 10};
    final accepted = confirmedAcceptedQuantities([
      {
        'stockApplied': true,
        'lines': [
          {'catalogId': 8, 'acceptedQty': 4},
        ],
      },
      {
        'stockApplied': false,
        'lines': [
          {'catalogId': 8, 'acceptedQty': 3},
        ],
      },
    ]);

    expect(remainingSupplierOrderQuantity(orderLine, accepted), 6);
  });

  test('manual lines have stable matching keys', () {
    expect(
      supplierReceptionLineKey({
        'description': 'Cable',
        'itemType': 'PRODUCT',
        'unit': 'PCS',
      }),
      supplierReceptionLineKey({
        'name': ' cable ',
        'item_type': 'product',
        'unit': 'pcs',
      }),
    );
  });

  test('reception totals include damaged and rejected delivered units', () {
    final totals = supplierReceptionTotals([
      {'qty': 5, 'price': 10, 'tvaRate': 19},
      {'qty': 2, 'price': 4.5, 'tvaRate': 7},
    ]);

    expect(totals['totalHt'], 59);
    expect(totals['totalVat'], 10.13);
    expect(totals['totalTtc'], 69.13);
  });
}

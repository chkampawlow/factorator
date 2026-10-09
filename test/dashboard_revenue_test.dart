import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/dashboard_revenue.dart';

void main() {
  test('nested history loads when the top level is absent or empty', () {
    final rows = dashboardRevenueRows({
      'monthly_series': [],
      'sales': {
        'monthly_series': [
          {'month': '2026-10', 'revenue': 200},
          {'month': '2026-09', 'revenue': 100},
        ]
      },
    });
    expect(rows.map((row) => row['revenue']), [100, 200]);
  });
  test('unrelated sales metrics do not hide invoice revenue', () {
    expect(
        dashboardRevenueValue({
          'sales': {'invoice_count': 2},
          'invoice': {'monthly_revenue': 500},
        }, 'monthly_revenue'),
        500);
    expect(
        dashboardRevenueValue({
          'sales': {'monthly_revenue': 0},
          'invoice': {'monthly_revenue': 500},
        }, 'monthly_revenue'),
        0);
  });
}

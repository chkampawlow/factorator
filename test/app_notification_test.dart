import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/app_notification.dart';

void main() {
  test('parses a permission-filtered backend notification', () {
    final notification = AppNotification.fromJson({
      'key': 'OVERDUE_INVOICE:42',
      'type': 'OVERDUE_INVOICE',
      'category': 'SALES',
      'title': 'Invoice overdue',
      'body': 'Client A',
      'severity': 'CRITICAL',
      'occurredAt': '2026-09-01',
      'entityType': 'INVOICE',
      'entityId': '42',
      'entityNumber': 'INV-42',
      'status': 'UNPAID',
      'filters': {'status': 'OVERDUE'},
      'isRead': 0,
      'readAt': '',
    });

    expect(notification.entityId, 42);
    expect(notification.severity, NotificationSeverity.critical);
    expect(notification.filters['status'], 'OVERDUE');
    expect(notification.isRead, isFalse);
  });

  test('copyWith only changes read state', () {
    const notification = AppNotification(
      key: 'LOW_STOCK:1',
      type: 'LOW_STOCK',
      category: 'STOCK',
      title: 'Low stock',
      body: 'Product A',
      severity: NotificationSeverity.warning,
      occurredAt: '2026-09-05',
      entityType: 'PRODUCT',
      entityId: 1,
      entityNumber: 'P-1',
      status: 'LOW',
      filters: {},
      isRead: false,
      readAt: '',
    );

    final read = notification.copyWith(isRead: true, readAt: 'now');
    expect(read.isRead, isTrue);
    expect(read.readAt, 'now');
    expect(read.key, notification.key);
  });
}

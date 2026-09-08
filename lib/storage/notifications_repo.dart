import 'package:my_app/core/api_client.dart';
import 'package:my_app/core/api_config.dart';
import 'package:my_app/core/app_notification.dart';

class NotificationsRepo {
  final ApiClient _api = ApiClient.instance;

  Future<NotificationPage> list({
    String search = '',
    String category = '',
    NotificationReadFilter read = NotificationReadFilter.all,
  }) async {
    const pageSize = 100;
    final items = <AppNotification>[];
    var total = 0;
    var unread = 0;
    var categoryCounts = <String, int>{};
    for (var page = 1; page <= 5; page++) {
      final raw = await _api.get(
        ApiConfig.notificationsList,
        authRequired: true,
        queryParams: {
          'page': page,
          'page_size': pageSize,
          if (search.trim().isNotEmpty) 'search': search.trim(),
          if (category.isNotEmpty) 'category': category,
          if (read.apiValue.isNotEmpty) 'read': read.apiValue,
        },
      );
      final envelope = raw is Map ? Map<String, dynamic>.from(raw) : const {};
      final rows = envelope['data'];
      if (rows is! List) throw Exception('Invalid notification response.');
      items.addAll(rows
          .whereType<Map>()
          .map((row) => AppNotification.fromJson(
                Map<String, dynamic>.from(row),
              ))
          .where((item) => item.key.isNotEmpty));
      total = _integer(envelope['total']);
      final aggregates = envelope['aggregates'];
      if (aggregates is Map) {
        unread = _integer(aggregates['unread']);
        final rawCategories = aggregates['categories'];
        if (rawCategories is Map) {
          categoryCounts = rawCategories.map(
            (key, value) => MapEntry('$key', _integer(value)),
          );
        }
      }
      if (items.length >= total || rows.isEmpty) break;
    }
    return NotificationPage(
      items: items,
      total: total,
      unread: unread,
      categoryCounts: categoryCounts,
    );
  }

  Future<int> setRead(String key, bool read) async {
    final raw = await _api.post(
      ApiConfig.notificationsMarkRead,
      authRequired: true,
      body: {
        'action': read ? 'READ' : 'UNREAD',
        'keys': [key],
      },
    );
    final envelope = raw is Map ? Map<String, dynamic>.from(raw) : const {};
    return _integer(envelope['unread']);
  }

  Future<int> markAllRead() async {
    final raw = await _api.post(
      ApiConfig.notificationsMarkRead,
      authRequired: true,
      body: const {'action': 'READ_ALL'},
    );
    final envelope = raw is Map ? Map<String, dynamic>.from(raw) : const {};
    return _integer(envelope['unread']);
  }

  int _integer(dynamic value) =>
      value is int ? value : int.tryParse('$value') ?? 0;
}

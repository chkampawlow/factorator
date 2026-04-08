import 'dart:convert';

import 'package:my_app/core/api_client.dart';
import 'package:my_app/core/api_config.dart';

class NotificationsRepo {
  final ApiClient _api = ApiClient.instance;

  Future<List<Map<String, dynamic>>> list({
    int limit = 30,
    bool unreadOnly = false,
  }) async {
    final raw = await _api.get(
      ApiConfig.notificationsList,
      authRequired: true,
      queryParams: {
        'limit': limit.toString(),
        if (unreadOnly) 'unread': 'true',
      },
    );

    // Accept: {success:true, items:[...]} OR {success:true, data:[...]} OR List
    if (raw is List) {
      return raw.map<Map<String, dynamic>>(_mapOne).toList();
    }

    if (raw is! Map) {
      throw Exception('Invalid notifications response');
    }

    final res = Map<String, dynamic>.from(raw as Map);

    if (res['success'] == false) {
      throw Exception((res['message'] ?? 'Failed to load notifications').toString());
    }

    final items = (res['items'] is List)
        ? (res['items'] as List)
        : (res['data'] is List)
            ? (res['data'] as List)
            : <dynamic>[];

    return items.map<Map<String, dynamic>>(_mapOne).toList();
  }

  Future<void> markRead(int id) async {
    if (id <= 0) return;

    Object raw;
    try {
      raw = await _api.post(
        ApiConfig.notificationsMarkRead,
        authRequired: true,
        body: {'id': id, 'notification_id': id},
      );
    } catch (_) {
      raw = await _api.get(
        ApiConfig.notificationsMarkRead,
        authRequired: true,
        queryParams: {'id': '$id', 'notification_id': '$id'},
      );
    }

    if (raw is! Map) throw Exception('Invalid mark_read response');

    final res = Map<String, dynamic>.from(raw as Map);
    if (res['success'] != true) {
      throw Exception((res['message'] ?? 'Failed to mark read').toString());
    }
  }

  Future<void> markAllRead() async {
    Object raw;
    try {
      raw = await _api.post(
        ApiConfig.notificationsMarkRead,
        authRequired: true,
        body: {'all': 1},
      );
    } catch (_) {
      raw = await _api.get(
        ApiConfig.notificationsMarkRead,
        authRequired: true,
        queryParams: {'all': '1'},
      );
    }

    if (raw is! Map) throw Exception('Invalid mark_all response');

    final res = Map<String, dynamic>.from(raw as Map);
    if (res['success'] != true) {
      throw Exception((res['message'] ?? 'Failed to mark all read').toString());
    }
  }

  Map<String, dynamic> _mapOne(dynamic e) {
    final m = (e is Map) ? Map<String, dynamic>.from(e) : <String, dynamic>{};

    dynamic data = m['data_json'];
    if (data is String && data.trim().isNotEmpty) {
      try {
        data = jsonDecode(data);
      } catch (_) {}
    }

    return {
      'id': _toInt(m['id']),
      'user_id': _toInt(m['user_id']),
      'type': (m['type'] ?? '').toString(),
      'title': (m['title'] ?? '').toString(),
      'body': (m['body'] ?? '').toString(),
      'data': (data is Map) ? Map<String, dynamic>.from(data) : data,
      'is_read': _toInt(m['is_read']) == 1,
      'created_at': (m['created_at'] ?? '').toString(),
    };
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }
}
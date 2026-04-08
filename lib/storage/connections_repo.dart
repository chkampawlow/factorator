import 'package:my_app/core/api_client.dart';
import 'package:my_app/core/api_config.dart';

class ConnectionsRepo {
  final ApiClient _api = ApiClient.instance;

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final q = query.trim();
    if (q.length < 2) return [];

    final url = '${ApiConfig.connectionsSearch}?q=${Uri.encodeComponent(q)}';
    Map<String, dynamic> res;
    try {
      final raw = await _api.get(url, authRequired: true);
      res = Map<String, dynamic>.from(raw as Map);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('method not allowed') && msg.contains('post')) {
        final raw = await _api.post(
          ApiConfig.connectionsSearch,
          authRequired: true,
          body: {'q': q},
        );
        res = Map<String, dynamic>.from(raw as Map);
      } else {
        rethrow;
      }
    }

    if (res['success'] != true) {
      throw Exception(res['message'] ?? 'Failed to search users');
    }

    final items = res['items'];
    if (items is! List) return [];

    return items.map<Map<String, dynamic>>((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return {
        ...map,
        'id': map['id'],
        'display_name': map['display_name'] ?? '',
        'email': map['email'] ?? '',
        'organization_name': map['organization_name'] ?? '',
        'role': map['role'] ?? '',
      };
    }).toList();
  }

  Future<int> sendInvitation({required int targetId}) async {
    final id = targetId;
    if (id <= 0) {
      throw Exception('target id is required');
    }

    final raw = await _api.post(
      ApiConfig.connectionsSend,
      authRequired: true,
      body: {
        'target_id': id,
        'taget_id': id,
        'targetId': id,
        'tagetId': id,
      },
    );
    final res = Map<String, dynamic>.from(raw as Map);

    if (res['success'] != true) {
      final msg = (res['message'] ?? '').toString().trim();
      throw Exception(msg.isEmpty ? 'Failed to send invitation: $res' : msg);
    }

    return int.tryParse((res['id'] ?? '0').toString()) ?? 0;
  }

  Future<List<Map<String, dynamic>>> inbox() async {
    final url = ApiConfig.connectionsInbox;
    Map<String, dynamic> res;
    try {
      final raw = await _api.get(url, authRequired: true);
      res = Map<String, dynamic>.from(raw as Map);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('method not allowed') && msg.contains('post')) {
        final raw = await _api.post(url, authRequired: true, body: const {});
        res = Map<String, dynamic>.from(raw as Map);
      } else {
        rethrow;
      }
    }

    if (res['success'] != true) {
      throw Exception(res['message'] ?? 'Failed to load inbox');
    }

    final items = res['items'];
    if (items is! List) return [];

    return items.map<Map<String, dynamic>>((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return {
        ...map,
        'id': map['id'],
        'connection_id': map['id'],
        'requester_id': map['requester_id'],
        'target_id': map['target_id'],
        'status': _uiStatusFromBackend((map['status'] ?? 'PENDING').toString()),
        'created_at': map['created_at'] ?? '',
        'requester_display_name': map['requester_display_name'] ?? '',
        'requester_email': map['requester_email'] ?? '',
        'requester_organization_name': map['requester_organization_name'] ?? '',
        'requester_role': map['requester_role'] ?? '',
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> sent() async {
    final url = ApiConfig.connectionsSent;
    Map<String, dynamic> res;
    try {
      final raw = await _api.get(url, authRequired: true);
      if (raw is! Map) {
        throw Exception('Invalid sent response (GET): $raw');
      }
      res = Map<String, dynamic>.from(raw as Map);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('method not allowed') && msg.contains('post')) {
        final raw = await _api.post(url, authRequired: true, body: const {});
        if (raw is! Map) {
          throw Exception('Invalid sent response (POST): $raw');
        }
        res = Map<String, dynamic>.from(raw as Map);
      } else {
        rethrow;
      }
    }

    if (res['success'] != true) {
      throw Exception(res['message'] ?? 'Failed to load sent invitations');
    }

    final items = res['items'];
    if (items is! List) return [];

    return items.map<Map<String, dynamic>>((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return {
        ...map,
        'id': map['id'],
        'connection_id': map['id'],
        'requester_id': map['requester_id'],
        'target_id': map['target_id'],
        'status': _uiStatusFromBackend((map['status'] ?? 'PENDING').toString()),
        'created_at': map['created_at'] ?? '',
        'target_display_name': map['target_display_name'] ?? '',
        'target_email': map['target_email'] ?? '',
        'target_organization_name': map['target_organization_name'] ?? '',
        'target_role': map['target_role'] ?? '',
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> accepted() async {
    final url = ApiConfig.connectionsAccepted;

    Map<String, dynamic> res;
    try {
      final raw = await _api.get(url, authRequired: true);
      res = Map<String, dynamic>.from(raw as Map);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('method not allowed') && msg.contains('post')) {
        final raw = await _api.post(url, authRequired: true, body: const {});
        res = Map<String, dynamic>.from(raw as Map);
      } else {
        rethrow;
      }
    }

    if (res['success'] != true) {
      throw Exception(res['message'] ?? 'Failed to load accepted');
    }

    final items = res['items'];
    if (items is! List) return [];
    return items
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<String> respond({
    required int id,
    required String action, // ACCEPT | DECLINE | BLOCK
  }) async {
    final raw = await _api.post(
      ApiConfig.connectionsRespond,
      authRequired: true,
      body: {
        'id': id,
        'action': _backendAction(action),
      },
    );
    final res = Map<String, dynamic>.from(raw as Map);

    if (res['success'] != true) {
      throw Exception(res['message'] ?? 'Failed to respond');
    }

    return _uiStatusFromBackend((res['status'] ?? '').toString());
  }

  Future<void> remove(int id) async {
    final raw = await _api.post(
      ApiConfig.connectionsRemove,
      authRequired: true,
      body: {'id': id},
    );
    final res = Map<String, dynamic>.from(raw as Map);

    if (res['success'] != true) {
      throw Exception(res['message'] ?? 'Failed to remove');
    }
  }

  String _backendAction(String action) {
    switch (action.trim().toLowerCase()) {
      case 'accept':
      case 'accepted':
        return 'ACCEPT';
      case 'decline':
      case 'declined':
      case 'reject':
      case 'rejected':
        return 'DECLINE';
      case 'block':
      case 'blocked':
        return 'BLOCK';
      default:
        return action.toUpperCase();
    }
  }

  // For UI tabs/buttons (you can keep using backend words if you prefer)
  // accepted | pending | declined | blocked
  String _uiStatusFromBackend(String status) {
    switch (status.trim().toUpperCase()) {
      case 'ACCEPTED':
        return 'accepted';
      case 'DECLINED':
        return 'declined';
      case 'BLOCKED':
        return 'blocked';
      case 'PENDING':
      default:
        return 'pending';
    }
  }
  Future<void> respondInvitation({
  required int connectionId,
  required String action, // "ACCEPT" | "REJECT"
}) async {
  final raw = await _api.post(
    ApiConfig.connectionsRespond, // make sure this exists in ApiConfig
    authRequired: true,
    body: {
      'connection_id': connectionId,
      'id': connectionId, // backward compatible if your PHP expects id
      'action': action,
    },
  );

  final res = Map<String, dynamic>.from(raw as Map);

  if (res['success'] != true) {
    throw Exception(res['message'] ?? 'Failed to respond to invitation');
  }
}
}
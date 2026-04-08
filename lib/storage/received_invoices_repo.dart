

import 'package:my_app/core/api_client.dart';
import 'package:my_app/core/api_config.dart';

class ReceivedInvoicesRepo {
  final ApiClient _api = ApiClient.instance;

  /// GET /invoices/received/list.php
  /// Optional: status, limit, offset
  Future<List<Map<String, dynamic>>> listReceivedInvoices({
    String status = '',
    int limit = 50,
    int offset = 0,
  }) async {
    final raw = await _api.get(
      ApiConfig.invoicesReceivedList,
      authRequired: true,
      queryParams: {
        if (status.trim().isNotEmpty) 'status': status.trim(),
        'limit': limit,
        'offset': offset,
      },
    );

    final res = Map<String, dynamic>.from(raw as Map);

    if (res['success'] != true) {
      throw Exception(res['message'] ?? 'Failed to load received invoices');
    }

    final items = res['items'];
    if (items is! List) return [];

    return items.map<Map<String, dynamic>>((e) {
      final m = Map<String, dynamic>.from(e as Map);

      // issuer is nested object in backend response
      final issuer = (m['issuer'] is Map)
          ? Map<String, dynamic>.from(m['issuer'] as Map)
          : <String, dynamic>{};

      return {
        ...m,
        'id': _toInt(m['id']),
        'invoice': (m['invoice'] ?? '').toString(),
        'status': (m['status'] ?? '').toString(),
        'invoice_date': (m['invoice_date'] ?? '').toString(),
        'invoice_due_date': (m['invoice_due_date'] ?? '').toString(),
        'total': _toDouble(m['total']),
        'issuer': issuer,
      };
    }).toList();
  }

  /// GET /invoices/received/get_received_by_id.php?id=123
  Future<Map<String, dynamic>> getReceivedInvoiceById(int id) async {
    final raw = await _api.get(
      ApiConfig.invoicesReceivedById,
      authRequired: true,
      queryParams: {'id': id},
    );

    final res = Map<String, dynamic>.from(raw as Map);

    if (res['success'] != true) {
      throw Exception(res['message'] ?? 'Failed to load invoice');
    }

    // Your PHP currently returns { success:true, items:[...] } (not "invoice")
    // If you want it to return a single object, change PHP to "invoice".
    // For now we support BOTH.
    if (res['invoice'] is Map) {
      return Map<String, dynamic>.from(res['invoice'] as Map);
    }

    final items = res['items'];
    if (items is List && items.isNotEmpty) {
      return Map<String, dynamic>.from(items.first as Map);
    }

    throw Exception('Invoice not found');
  }

  int _toInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? fallback;
  }

  double _toDouble(dynamic v, [double fallback = 0]) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.')) ?? fallback;
  }
}
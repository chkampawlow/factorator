import 'package:my_app/core/api_client.dart';
import 'package:my_app/core/api_config.dart';
import 'package:my_app/services/exchange_rate_service.dart';

class InvoicesRepo {
  final ApiClient _api = ApiClient.instance;

  int _toInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? fallback;
  }

  Future<List<Map<String, dynamic>>> getAllInvoices() async {
    final response = await _api.get(
      ApiConfig.getInvoices,
      authRequired: true,
    );

    if (response is List) {
      return response.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is List) {
        return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    }

    throw Exception('Invalid invoices response');
  }

  Future<int> createInvoiceHeader({
    int? clientId,
    required DateTime issueDate,
    DateTime? dueDate,
    required String status,
    required double subtotal,
    required double totalVat,
    required double total,
    double timbre = ExchangeRateService.timbreTnd,
  }) async {
    final cid = _toInt(clientId);
    final totalWithTimbre = total + timbre;

    final response = await _api.post(
      ApiConfig.addInvoice,
      authRequired: true,
      body: {
        if (cid > 0) 'client_id': cid,
        'invoice_date': issueDate.toIso8601String().split('T').first,
        if (dueDate != null)
          'invoice_due_date': dueDate.toIso8601String().split('T').first,
        'status': status.trim().isEmpty ? 'DRAFT' : status.trim(),
        'subtotal': subtotal,
        'montant_tva': totalVat,
        'subtotal_ttc': total,
        'timbre': timbre,
        'total': totalWithTimbre,
        'invoice_type': 'FACTURE',
        'notes': '',
      },
    ) as Map<String, dynamic>;

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Create invoice failed');
    }

    final id = response['id'];
    if (id == null) {
      throw Exception('Invoice created but id is missing');
    }

    return id is int ? id : int.parse(id.toString());
  }

  Future<Map<String, dynamic>> getInvoiceById(int invoiceId) async {
    final response = await _api.get(
      ApiConfig.getInvoiceById,
      authRequired: true,
      queryParams: {'id': invoiceId},
    ) as Map<String, dynamic>;

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Load invoice failed');
    }

    final invoice = response['invoice'];
    if (invoice is Map<String, dynamic>) {
      return invoice;
    }
    if (invoice is Map) {
      return Map<String, dynamic>.from(invoice);
    }

    throw Exception('Invalid invoice response');
  }

  Future<void> recomputeInvoiceTotals(int invoiceId) async {
    final response = await _api.post(
      ApiConfig.recomputeInvoiceTotals,
      authRequired: true,
      body: {
        'invoice_id': invoiceId,
      },
    ) as Map<String, dynamic>;

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Recompute totals failed');
    }
  }

  Future<void> updateInvoiceDates({
    required int id,
    required DateTime issueDate,
    DateTime? dueDate,
  }) async {
    final res = await _api.post(
      ApiConfig.updateInvoice,
      authRequired: true,
      body: {
        'id': id,
        'invoice_date': issueDate.toIso8601String().split('T').first,
        if (dueDate != null)
          'invoice_due_date': dueDate.toIso8601String().split('T').first,
      },
    ) as Map<String, dynamic>;

    if (res['success'] != true) {
      throw Exception(res['message'] ?? 'Failed to update invoice date');
    }
  }

  Future<void> updateInvoiceNotes({
    required int id,
    required String notes,
  }) async {
    final res = await _api.post(
      ApiConfig.updateInvoice,
      authRequired: true,
      body: {
        'id': id,
        'notes': notes,
      },
    ) as Map<String, dynamic>;

    if (res['success'] != true) {
      throw Exception(res['message'] ?? 'Failed to update invoice notes');
    }
  }

  Future<void> updateInvoiceStatus(
    int id,
    String status, {
    String? paymentMethod,
  }) async {
    final res = await _api.post(
      ApiConfig.updateInvoice,
      authRequired: true,
      body: {
        'id': id,
        'status': status,
        'payment_method': paymentMethod,
      },
    ) as Map<String, dynamic>;

    if (res['success'] != true) {
      throw Exception(res['message'] ?? 'Failed to update invoice status');
    }
  }
  Future<void> deleteInvoice(int invoiceId) async {
  final res = await _api.post(
    ApiConfig.deleteInvoice, // <-- add this in ApiConfig
    authRequired: true,
    body: {'id': invoiceId},
  ) as Map<String, dynamic>;

  if (res['success'] != true) {
    throw Exception(res['message'] ?? 'Delete invoice failed');
  }
}
}

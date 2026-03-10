import 'package:my_app/core/api_client.dart';
import 'package:my_app/core/api_config.dart';

class InvoiceItemsRepo {
  final ApiClient _api = ApiClient.instance;

  Future<List<Map<String, dynamic>>> getInvoiceItems(int invoiceId) async {
    final response = await _api.get(
      ApiConfig.getInvoiceItems,
      authRequired: true,
      queryParams: {
        'invoice_id': invoiceId,
      },
    );

    if (response is List) {
      return response
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is List) {
        return data
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    }

    throw Exception('Invalid invoice items response');
  }

  Future<void> addInvoiceItem({
    required int invoiceId,
    required String invoice,
    String? productCode,
    required String product,
    required double qty,
    required double tvaRate,
    required double montantTva,
    required double price,
    required double discount,
    required double subtotal,
    required double subtotalTTC,
    required String invoiceDate,
  }) async {
    final response = await _api.post(
      ApiConfig.addInvoiceItem,
      authRequired: true,
      body: {
        'invoice_id': invoiceId,
        'invoice': invoice,
        'product_code': productCode,
        'product': product,
        'qty': qty,
        'tva_rate': tvaRate,
        'montant_tva': montantTva,
        'price': price,
        'discount': discount,
        'subtotal': subtotal,
        'subtotalTTC': subtotalTTC,
        'invoice_date': invoiceDate,
      },
    ) as Map<String, dynamic>;

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Add invoice item failed');
    }
  }

  Future<void> updateInvoiceItem({
    required int id,
    required int invoiceId,
    required String invoice,
    String? productCode,
    required String product,
    required double qty,
    required double tvaRate,
    required double montantTva,
    required double price,
    required double discount,
    required double subtotal,
    required double subtotalTTC,
    required String invoiceDate,
  }) async {
    final response = await _api.post(
      ApiConfig.updateInvoiceItem,
      authRequired: true,
      body: {
        'id': id,
        'invoice_id': invoiceId,
        'invoice': invoice,
        'product_code': productCode,
        'product': product,
        'qty': qty,
        'tva_rate': tvaRate,
        'montant_tva': montantTva,
        'price': price,
        'discount': discount,
        'subtotal': subtotal,
        'subtotalTTC': subtotalTTC,
        'invoice_date': invoiceDate,
      },
    ) as Map<String, dynamic>;

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Update invoice item failed');
    }
  }

  Future<void> deleteInvoiceItem(int id) async {
    final response = await _api.post(
      ApiConfig.deleteInvoiceItem,
      authRequired: true,
      body: {
        'id': id,
      },
    ) as Map<String, dynamic>;

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Delete invoice item failed');
    }
  }
}
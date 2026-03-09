import 'dart:convert';
import 'package:http/http.dart' as http;

class InvoiceItemsRepo {
  static const String baseUrl = "http://localhost/facturation_api";

  Future<List<Map<String, dynamic>>> getInvoiceItems(int invoiceId) async {
    final uri = Uri.parse("$baseUrl/get_invoice_items.php?invoice_id=$invoiceId");

    final response = await http.get(
      uri,
      headers: const {"Accept": "application/json"},
    );

    if (response.statusCode != 200) {
      throw Exception("HTTP ${response.statusCode}: ${response.body}");
    }

    final decoded = jsonDecode(response.body);

    if (decoded is List) {
      return decoded
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    throw Exception("Invalid invoice items response");
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
    final uri = Uri.parse("$baseUrl/add_invoice_item.php");

    final response = await http.post(
      uri,
      headers: const {
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
      body: jsonEncode({
        "invoice_id": invoiceId,
        "invoice": invoice,
        "product_code": productCode,
        "product": product,
        "qty": qty,
        "tva_rate": tvaRate,
        "montant_tva": montantTva,
        "price": price,
        "discount": discount,
        "subtotal": subtotal,
        "subtotalTTC": subtotalTTC,
        "invoice_date": invoiceDate,
      }),
    );

    final decoded = jsonDecode(response.body);

    if (response.statusCode != 200 || decoded["success"] != true) {
      throw Exception(decoded["message"] ?? "Add invoice item failed");
    }
  }

  Future<void> deleteInvoiceItem(int id) async {
    final uri = Uri.parse("$baseUrl/delete_invoice_item.php");

    final response = await http.post(
      uri,
      headers: const {
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
      body: jsonEncode({"id": id}),
    );

    final decoded = jsonDecode(response.body);

    if (response.statusCode != 200 || decoded["success"] != true) {
      throw Exception(decoded["message"] ?? "Delete invoice item failed");
    }
  }
}
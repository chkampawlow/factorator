import 'dart:convert';
import 'package:http/http.dart' as http;

class InvoicesRepo {
  static const String baseUrl = "http://localhost/facturation_api";

  Future<List<Map<String, dynamic>>> getAllInvoices() async {
    final uri = Uri.parse("$baseUrl/get_invoices.php");

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

    throw Exception("Invalid invoices response");
  }

  Future<int> createInvoiceHeader({
    required int clientId,
    required DateTime issueDate,
    required DateTime dueDate,
    required String status,
    required double subtotal,
    required double totalVat,
    required double total,
  }) async {
    final uri = Uri.parse("$baseUrl/add_invoice.php");

    final response = await http.post(
      uri,
      headers: const {
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
      body: jsonEncode({
        "client_id": clientId,
        "invoice_date": issueDate.toIso8601String().split('T').first,
        "invoice_due_date": dueDate.toIso8601String().split('T').first,
        "status": status,
        "subtotal": subtotal,
        "montant_tva": totalVat,
        "subtotal_ttc": total,
        "total": total,
        "invoice_type": "FACTURE",
        "notes": "",
      }),
    );

    final decoded = jsonDecode(response.body);

    if (response.statusCode != 200 || decoded["success"] != true) {
      throw Exception(decoded["message"] ?? "Create invoice failed");
    }

    final id = decoded["id"];
    return id is int ? id : int.parse(id.toString());
  }
  Future<Map<String, dynamic>> getInvoiceById(int invoiceId) async {
  final uri = Uri.parse("$baseUrl/get_invoice_by_id.php?id=$invoiceId");

  final response = await http.get(
    uri,
    headers: const {"Accept": "application/json"},
  );

  final decoded = jsonDecode(response.body);

  if (response.statusCode != 200 || decoded["success"] != true) {
    throw Exception(decoded["message"] ?? "Load invoice failed");
  }

  return Map<String, dynamic>.from(decoded["invoice"]);
}
}
import 'dart:convert';
import 'package:http/http.dart' as http;

class InvoicesApiRepo {
  static const String baseUrl = "http://localhost/facturation_api";

  Future<void> recomputeInvoiceTotals(int invoiceId) async {
    final uri = Uri.parse("$baseUrl/recompute_invoice_totals.php");

    final response = await http.post(
      uri,
      headers: const {
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
      body: jsonEncode({"invoice_id": invoiceId}),
    );

    final decoded = jsonDecode(response.body);

    if (response.statusCode != 200 || decoded["success"] != true) {
      throw Exception(decoded["message"] ?? "Recompute totals failed");
    }
  }
}
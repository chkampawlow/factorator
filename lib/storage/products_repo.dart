import 'dart:convert';
import 'package:http/http.dart' as http;

class ProductsRepo {
  static const String baseUrl = "http://localhost/facturation_api";

  Future<List<Map<String, dynamic>>> getAllProducts() async {
    final uri = Uri.parse("$baseUrl/get_products.php");

    final response = await http.get(
      uri,
      headers: const {"Accept": "application/json"},
    );

    if (response.statusCode != 200) {
      throw Exception("HTTP ${response.statusCode}: ${response.body}");
    }

    final body = response.body.trim();

    if (body.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(body);

    if (decoded is List) {
      return decoded
          .map<Map<String, dynamic>>(
            (e) => Map<String, dynamic>.from(e as Map),
          )
          .toList();
    }

    throw Exception("Invalid products response");
  }

  Future<void> addProduct({
    required String name,
    required double price,
    required double tvaRate,
    String? unit,
    String? code,
  }) async {
    final uri = Uri.parse("$baseUrl/add_product.php");

    final response = await http.post(
      uri,
      headers: const {
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
      body: jsonEncode({
        "code": code,
        "name": name,
        "price": price,
        "tva_rate": tvaRate,
        "unit": unit,
      }),
    );

    final decoded = jsonDecode(response.body);

    if (response.statusCode != 200 || decoded["success"] != true) {
      throw Exception(decoded["message"] ?? "Add product failed");
    }
  }

  Future<void> updateProduct({
    required int id,
    required String name,
    required double price,
    required double tvaRate,
    String? unit,
    String? code,
  }) async {
    final uri = Uri.parse("$baseUrl/update_product.php");

    final response = await http.post(
      uri,
      headers: const {
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
      body: jsonEncode({
        "id": id,
        "code": code,
        "name": name,
        "price": price,
        "tva_rate": tvaRate,
        "unit": unit,
      }),
    );

    final decoded = jsonDecode(response.body);

    if (response.statusCode != 200 || decoded["success"] != true) {
      throw Exception(decoded["message"] ?? "Update product failed");
    }
  }

  Future<void> deleteProduct(int id) async {
    final uri = Uri.parse("$baseUrl/delete_product.php");

    final response = await http.post(
      uri,
      headers: const {
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
      body: jsonEncode({
        "id": id,
      }),
    );

    final decoded = jsonDecode(response.body);

    if (response.statusCode != 200 || decoded["success"] != true) {
      throw Exception(decoded["message"] ?? "Delete product failed");
    }
  }
}
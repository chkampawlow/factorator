import 'package:my_app/core/api_client.dart';
import 'package:my_app/core/api_config.dart';

class ProductsRepo {
  final ApiClient _api = ApiClient.instance;

  Future<List<Map<String, dynamic>>> getAllProducts() async {
    final response = await _api.get(
      ApiConfig.getProducts,
      authRequired: true,
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

    throw Exception('Invalid products response');
  }

  Future<void> addProduct({
    required String name,
    required double price,
    required double tvaRate,
    String? unit,
    String? code,
  }) async {
    final response = await _api.post(
      ApiConfig.addProduct,
      authRequired: true,
      body: {
        'code': code,
        'name': name,
        'price': price,
        'tva_rate': tvaRate,
        'unit': unit,
      },
    ) as Map<String, dynamic>;

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Add product failed');
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
    final response = await _api.post(
      ApiConfig.updateProduct,
      authRequired: true,
      body: {
        'id': id,
        'code': code,
        'name': name,
        'price': price,
        'tva_rate': tvaRate,
        'unit': unit,
      },
    ) as Map<String, dynamic>;

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Update product failed');
    }
  }

  Future<void> deleteProduct(int id) async {
    final response = await _api.post(
      ApiConfig.deleteProduct,
      authRequired: true,
      body: {
        'id': id,
      },
    ) as Map<String, dynamic>;

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Delete product failed');
    }
  }
}
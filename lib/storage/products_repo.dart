import 'package:my_app/core/api_client.dart';
import 'package:my_app/core/api_config.dart';

class ProductsRepo {
  final ApiClient _api = ApiClient.instance;

  Future<List<Map<String, dynamic>>> getAllProducts({
    String stock = '',
    String pricing = '',
  }) async {
    return _api.getAllPages(
      ApiConfig.getProducts,
      resourceName: 'products',
      queryParams: {
        if (stock.isNotEmpty) 'stock': stock,
        if (pricing.isNotEmpty) 'pricing': pricing,
      },
    );
  }

  Future<Map<String, dynamic>> getInventoryDetail(
    int id, {
    bool includeHistory = true,
  }) async {
    final productResponse = await _api.get(
      ApiConfig.getProduct,
      authRequired: true,
      queryParams: {'id': id},
    );
    final productEnvelope = Map<String, dynamic>.from(productResponse as Map);
    final product =
        Map<String, dynamic>.from(productEnvelope['product'] as Map);

    if (!includeHistory) {
      return {
        ...product,
        'current_stock': product['stock_quantity'],
        'movements': const <dynamic>[],
      };
    }

    Map<String, dynamic> historyEnvelope = const {};
    try {
      final historyResponse = await _api.get(
        ApiConfig.productStockHistory,
        authRequired: true,
        queryParams: {'id': id, 'page': 1, 'page_size': 25},
      );
      historyEnvelope = Map<String, dynamic>.from(historyResponse as Map);
    } catch (_) {
      // The product itself remains useful when stock history is temporarily
      // unavailable or is not installed on an older backend deployment.
    }

    final movements = historyEnvelope['movements'] ?? historyEnvelope['data'];
    return {
      ...product,
      'current_stock': historyEnvelope['aggregates'] is Map
          ? (historyEnvelope['aggregates'] as Map)['current_stock']
          : product['stock_quantity'],
      'movements': movements is List ? movements : const [],
    };
  }

  Future<Map<String, dynamic>> findByBarcode(String barcode) async {
    final raw = await _api.get(ApiConfig.productBarcodeLookup,
        authRequired: true, queryParams: {'barcode': barcode});
    final envelope = Map<String, dynamic>.from(raw as Map);
    return Map<String, dynamic>.from(envelope['product'] as Map);
  }

  Future<double> createStockAdjustment({
    required int productId,
    required double quantityDelta,
    required String reasonCode,
    required String reasonDetail,
  }) async {
    final key =
        'mobile-stock-$productId-${DateTime.now().microsecondsSinceEpoch}';
    final raw = await _api.post(
      ApiConfig.createStockAdjustment,
      authRequired: true,
      body: {
        'product_id': productId,
        'quantity_delta': quantityDelta,
        'reason_code': reasonCode,
        'reason_detail': reasonDetail,
        'idempotency_key': key,
      },
    );
    final envelope = Map<String, dynamic>.from(raw as Map);
    return double.tryParse('${envelope['stock_quantity'] ?? 0}') ?? 0;
  }

  Future<Map<String, dynamic>> addProduct({
    required String name,
    required double price,
    required double tvaRate,
    String? unit,
    String? code,
    String? barcode,
    String itemType = 'PRODUCT',
  }) async {
    final idempotencyKey =
        'mobile-product-${DateTime.now().microsecondsSinceEpoch}';
    final response = await _api.post(
      ApiConfig.addProduct,
      authRequired: true,
      body: {
        'code': code,
        'barcode': barcode,
        'name': name,
        'item_type': itemType,
        'price': price,
        'tva_rate': tvaRate,
        'unit': unit,
        'idempotency_key': idempotencyKey,
      },
    ) as Map<String, dynamic>;

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Add product failed');
    }

    // Prefer backend-returned product payload when available.
    final dynamic p =
        response['product'] ?? response['item'] ?? response['data'];
    if (p is Map) {
      return Map<String, dynamic>.from(p);
    }

    // Fallback: backend returned only an id.
    final dynamic id = response['id'];
    final int parsedId =
        (id is int) ? id : int.tryParse(id?.toString() ?? '') ?? 0;

    if (parsedId > 0) {
      try {
        return await getInventoryDetail(parsedId, includeHistory: false);
      } catch (_) {
        // Keep the local fallback for older deployments without get_product.
      }
    }

    return <String, dynamic>{
      'id': parsedId,
      'code': code,
      'barcode': barcode,
      'name': name,
      'item_type': itemType,
      'price': price,
      'tva_rate': tvaRate,
      'unit': unit,
    };
  }

  Future<Map<String, dynamic>> updateProduct({
    required int id,
    required String name,
    required double price,
    required double tvaRate,
    String? unit,
    String? code,
    String? barcode,
    String itemType = 'PRODUCT',
  }) async {
    final response = await _api.post(
      ApiConfig.updateProduct,
      authRequired: true,
      body: {
        'id': id,
        'code': code,
        'barcode': barcode,
        'name': name,
        'item_type': itemType,
        'price': price,
        'tva_rate': tvaRate,
        'unit': unit,
      },
    ) as Map<String, dynamic>;

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Update product failed');
    }

    return getInventoryDetail(id, includeHistory: false);
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

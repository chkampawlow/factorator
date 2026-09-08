import 'package:my_app/core/api_client.dart';
import 'package:my_app/core/api_config.dart';

class SupplierReceptionsRepo {
  final ApiClient _api = ApiClient.instance;

  Future<List<Map<String, dynamic>>> list({
    String search = '',
    String status = '',
  }) {
    return _api.getAllPages(
      ApiConfig.supplierReceptionsList,
      resourceName: 'supplier receptions',
      queryParams: {
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (status.isNotEmpty) 'status': status,
      },
    );
  }

  Future<Map<String, dynamic>> detail(int id) async {
    final raw = await _api.get(
      ApiConfig.supplierReceptionDetail,
      authRequired: true,
      queryParams: {'id': id},
    );
    final envelope = Map<String, dynamic>.from(raw as Map);
    final reception = envelope['reception'];
    if (reception is! Map) throw Exception('Invalid supplier reception');
    return Map<String, dynamic>.from(reception);
  }

  Future<List<Map<String, dynamic>>> forSupplierOrder(int orderId) async {
    final raw = await _api.get(
      ApiConfig.supplierReceptionDetail,
      authRequired: true,
      queryParams: {'supplier_order_id': orderId},
    );
    final envelope = Map<String, dynamic>.from(raw as Map);
    final rows = envelope['data'];
    if (rows is! List) return [];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listOpenSupplierOrders() async {
    final results = await Future.wait([
      _listSupplierOrders(status: 'SENT'),
      _listSupplierOrders(status: 'PARTIALLY_RECEIVED'),
    ]);
    final byId = <int, Map<String, dynamic>>{};
    for (final order in results.expand((rows) => rows)) {
      final id = int.tryParse('${order['id'] ?? 0}') ?? 0;
      if (id > 0) byId[id] = order;
    }
    final orders = byId.values.toList();
    orders.sort((a, b) => (int.tryParse('${b['id']}') ?? 0)
        .compareTo(int.tryParse('${a['id']}') ?? 0));
    return orders;
  }

  Future<List<Map<String, dynamic>>> _listSupplierOrders({
    required String status,
  }) {
    return _api.getAllPages(
      ApiConfig.supplierOrdersList,
      resourceName: 'supplier orders',
      queryParams: {'status': status},
    );
  }

  Future<Map<String, dynamic>> supplierOrderDetail(int id) async {
    final raw = await _api.get(
      ApiConfig.supplierOrderDetail,
      authRequired: true,
      queryParams: {'id': id},
    );
    final envelope = Map<String, dynamic>.from(raw as Map);
    final order = envelope['order'];
    if (order is! Map) throw Exception('Invalid supplier order');
    return Map<String, dynamic>.from(order);
  }

  Future<int> saveDraft(Map<String, dynamic> payload) async {
    final id = int.tryParse('${payload['id'] ?? 0}') ?? 0;
    final body = <String, dynamic>{
      ...payload,
      if (id <= 0)
        'idempotency_key':
            'mobile-reception-${DateTime.now().microsecondsSinceEpoch}',
    };
    final raw = await _api.post(
      ApiConfig.supplierReceptionSave,
      authRequired: true,
      body: body,
    );
    final envelope = Map<String, dynamic>.from(raw as Map);
    final savedId = int.tryParse('${envelope['id'] ?? 0}') ?? 0;
    if (savedId <= 0) throw Exception('Reception saved without an id');
    return savedId;
  }

  Future<Map<String, dynamic>> confirm(
    int id, {
    bool createExpense = false,
  }) async {
    final raw = await _api.post(
      ApiConfig.supplierReceptionConfirm,
      authRequired: true,
      body: {
        'supplier_reception_id': id,
        'create_expense': createExpense,
      },
    );
    return Map<String, dynamic>.from(raw as Map);
  }

  Future<void> uploadDiscrepancyAttachment(int id, String filePath) async {
    await _api.multipartPost(
      ApiConfig.supplierReceptionUpload,
      fileField: 'attachment',
      filePath: filePath,
      fields: {'supplier_reception_id': '$id'},
    );
  }
}

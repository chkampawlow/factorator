import 'package:my_app/core/api_client.dart';
import 'package:my_app/core/api_config.dart';

class SalesOrdersRepo {
  final ApiClient _api = ApiClient.instance;

  Future<List<Map<String, dynamic>>> list(
          {String search = '', String status = ''}) =>
      _api.getAllPages(
        ApiConfig.salesOrdersList,
        resourceName: 'sales orders',
        queryParams: {
          if (search.trim().isNotEmpty) 'search': search.trim(),
          if (status.isNotEmpty) 'status': status,
        },
      );

  Future<Map<String, dynamic>> detail(int id) async {
    final raw = await _api.get(ApiConfig.salesOrderDetail,
        authRequired: true, queryParams: {'id': id});
    final envelope = Map<String, dynamic>.from(raw as Map);
    return {
      ...Map<String, dynamic>.from(envelope['order'] as Map),
      'items': (envelope['items'] as List? ?? const []),
    };
  }
}

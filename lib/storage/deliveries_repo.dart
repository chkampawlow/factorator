import 'package:my_app/core/api_client.dart';
import 'package:my_app/core/api_config.dart';

class DeliveriesRepo {
  final ApiClient _api = ApiClient.instance;
  Future<List<Map<String, dynamic>>> list(
          {String search = '', String status = ''}) =>
      _api.getAllPages(ApiConfig.deliveriesList,
          resourceName: 'deliveries',
          queryParams: {
            if (search.trim().isNotEmpty) 'search': search.trim(),
            if (status.isNotEmpty) 'status': status
          });
  Future<Map<String, dynamic>> detail(int id) async {
    final raw = await _api.get(ApiConfig.deliveryDetail,
        authRequired: true, queryParams: {'id': id});
    final envelope = Map<String, dynamic>.from(raw as Map);
    final delivery = {
      ...Map<String, dynamic>.from(envelope['delivery'] as Map),
      'items': envelope['items'] as List? ?? const []
    };
    // Older deployed delivery endpoints omit the customer's contact fields.
    final clientId = int.tryParse('${delivery['client_id'] ?? ''}') ?? 0;
    if ((delivery['client_phone'] ?? '').toString().trim().isEmpty &&
        clientId > 0) {
      try {
        final response = await _api.get(
            '${ApiConfig.baseUrl}/clients/get_client.php',
            authRequired: true,
            queryParams: {'id': clientId}) as Map;
        final client = response['client'];
        if (client is Map) delivery['client_phone'] = client['phone'];
      } catch (_) {
        // Keep delivery details available when contact access is denied.
      }
    }
    return delivery;
  }

  Future<void> action(int id, String action) async {
    await _api.post(ApiConfig.deliveryAction,
        authRequired: true, body: {'id': id, 'action': action});
  }
}

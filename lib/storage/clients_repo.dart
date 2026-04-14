import 'package:my_app/core/api_client.dart';
import 'package:my_app/core/api_config.dart';

class ClientsRepo {
  final ApiClient _api = ApiClient.instance;

  Future<int> addClient({
    required String type,
    required String name,
    String? email,
    String? phone,
    String? address,
    String? fiscalId,
    String? cin,
  }) async {
    final response = await _api.post(
      ApiConfig.addClient,
      authRequired: true,
      body: {
        'type': type,
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
        // Send both keys for backward/forward compatibility with PHP.
        'fiscalId': fiscalId,
        'fiscal_id': fiscalId,
        'cin': cin,
      },
    ) as Map<String, dynamic>;

    if (response['success'] == true && response['id'] != null) {
      return int.tryParse(response['id'].toString()) ?? 0;
    }

    throw Exception(response['message'] ?? 'Failed to add client');
  }

  Future<List<Map<String, dynamic>>> getAllClients() async {
    final response = await _api.get(
      ApiConfig.getClients,
      authRequired: true,
    );

    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is List) {
        return data
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    }

    if (response is List) {
      return response
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    throw Exception('Invalid clients response');
  }

  Future<List<Map<String, dynamic>>> getAllClientsarchived() async {
    // Backward-compatible name: we no longer support archived clients.
    // This now returns the same list as getAllClients().
    final response = await _api.get(
      ApiConfig.getClients,
      authRequired: true,
    );

    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is List) {
        return data
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    }

    if (response is List) {
      return response
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    throw Exception('Invalid clients response');
  }

  Future<int> updateClient({
    required int id,
    required String type,
    required String name,
    String? email,
    String? phone,
    String? address,
    String? fiscalId,
    String? cin,
  }) async {
    final response = await _api.post(
      ApiConfig.updateClient,
      authRequired: true,
      body: {
        'id': id,
        'type': type,
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
        // Send both keys for backward/forward compatibility with PHP.
        'fiscalId': fiscalId,
        'fiscal_id': fiscalId,
        'cin': cin,
      },
    ) as Map<String, dynamic>;

    if (response['success'] == true) {
      return 1;
    }

    throw Exception(response['message'] ?? 'Failed to update client');
  }

  Future<void> deleteClient(int id) async {
    try {
      final response = await _api.post(
        ApiConfig.deleteClient,
        authRequired: true,
        body: {
          // Some older endpoints expect `client_id` instead of `id`.
          'id': id,
          'client_id': id,
        },
      ) as Map<String, dynamic>;

      if (response['success'] == true) {
        return;
      }

      throw Exception(response['message'] ?? 'Failed to delete client');
    } catch (e) {
      // Re-throw with a cleaner message so UI can display it.
      throw Exception(
        'Delete client failed: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }
  Future<Map<String, dynamic>> getClientById(int id) async {
    final items = await getAllClients();

    for (final c in items) {
      final rawId = c['id'];
      final clientId = rawId is int ? rawId : int.tryParse(rawId.toString());
      if (clientId == id) {
        return c;
      }
    }

    throw Exception('Client not found');
  }
}
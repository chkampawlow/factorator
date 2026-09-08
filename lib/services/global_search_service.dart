import 'package:my_app/core/api_client.dart';
import 'package:my_app/core/api_config.dart';
import 'package:my_app/core/permission_service.dart';

class GlobalSearchResult {
  final String type;
  final String title;
  final String subtitle;
  final Map<String, dynamic> data;

  const GlobalSearchResult(this.type, this.title, this.subtitle, this.data);
}

class GlobalSearchService {
  final ApiClient _api = ApiClient.instance;

  Future<List<GlobalSearchResult>> search(
    String query,
    PermissionService permissions,
  ) async {
    final q = query.trim();
    if (q.length < 2) return [];
    final tasks = <Future<List<GlobalSearchResult>>>[];

    void add(
        String permission,
        String endpoint,
        String type,
        String Function(Map<String, dynamic>) title,
        String Function(Map<String, dynamic>) subtitle) {
      if (!permissions.allows(permission) && !permissions.hasWildcard) return;
      tasks.add(_search(endpoint, q, type, title, subtitle));
    }

    add(
        'clients.view',
        ApiConfig.getClients,
        'Client',
        (r) => '${r['name'] ?? ''}',
        (r) => '${r['email'] ?? r['phone'] ?? ''}');
    add('products.view', ApiConfig.getProducts, 'Product',
        (r) => '${r['name'] ?? ''}', (r) => '${r['code'] ?? r['unit'] ?? ''}');
    add(
        'invoices.view',
        ApiConfig.getInvoices,
        'Invoice',
        (r) => '${r['invoice'] ?? ''}',
        (r) => '${r['client_name'] ?? ''} • ${r['status'] ?? ''}');
    add(
        'expenses.view',
        ApiConfig.expenseNotesList,
        'Expense',
        (r) => '${r['title'] ?? ''}',
        (r) => '${r['category'] ?? ''} • ${r['status'] ?? ''}');
    add(
        'suppliers.view',
        ApiConfig.suppliersList,
        'Supplier',
        (r) => '${r['name'] ?? ''}',
        (r) => '${r['reference'] ?? r['email'] ?? ''}');
    add(
        'supplierOrders.view',
        ApiConfig.supplierOrdersList,
        'Supplier order',
        (r) => '${r['orderNumber'] ?? r['order_number'] ?? ''}',
        (r) =>
            '${r['supplierName'] ?? r['supplier_name'] ?? ''} • ${r['status'] ?? ''}');
    add(
        'supplierReceptions.view',
        ApiConfig.supplierReceptionsList,
        'Reception',
        (r) =>
            '${r['supplierDeliveryNoteNumber'] ?? r['supplier_delivery_note_number'] ?? r['invoiceNumber'] ?? r['invoice_number'] ?? r['id'] ?? ''}',
        (r) =>
            '${r['supplierName'] ?? r['supplier_name'] ?? ''} • ${r['status'] ?? ''}');

    final groups = await Future.wait(tasks);
    return groups.expand((items) => items).take(60).toList();
  }

  Future<List<GlobalSearchResult>> _search(
    String endpoint,
    String query,
    String type,
    String Function(Map<String, dynamic>) title,
    String Function(Map<String, dynamic>) subtitle,
  ) async {
    try {
      final rows = await _api.getAllPages(endpoint,
          resourceName: type, queryParams: {'search': query});
      return rows
          .map(
              (row) => GlobalSearchResult(type, title(row), subtitle(row), row))
          .where((result) => result.title.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }
}

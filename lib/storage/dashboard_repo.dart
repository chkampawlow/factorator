import 'package:my_app/storage/invoices_repo.dart';

class DashboardRepo {
  final InvoicesRepo _invoicesRepo = InvoicesRepo();

  Future<List<Map<String, dynamic>>> getRecentInvoices({int limit = 5}) async {
    final invoices = await _invoicesRepo.getAllInvoices();

    // sort newest first (same behavior as invoices screen)
    invoices.sort((a, b) {
      final aId = int.tryParse(a['id'].toString()) ?? 0;
      final bId = int.tryParse(b['id'].toString()) ?? 0;
      return bId.compareTo(aId);
    });

    // only return the last invoices
    return invoices.take(limit).toList();
  }
}
import 'app_db.dart';

class DashboardRepo {
  Future<Map<String, dynamic>> getStats() async {
    final db = await AppDb.instance;

    final totalRow = (await db.rawQuery("SELECT COUNT(*) AS c FROM invoices")).first;
    final paidRow = (await db.rawQuery(
      "SELECT COUNT(*) AS c FROM invoices WHERE UPPER(status) = 'PAID'",
    )).first;

    final unpaidRow = (await db.rawQuery(
      "SELECT COUNT(*) AS c FROM invoices WHERE UPPER(status) = 'UNPAID'",
    )).first;

    return {
      'totalInvoices': (totalRow['c'] as int),
      'paidInvoices': (paidRow['c'] as int),
      'pendingInvoices': (unpaidRow['c'] as int), // pending = unpaid (simple)
    };
  }

  Future<List<Map<String, dynamic>>> getRecentInvoices({int limit = 5}) async {
    final db = await AppDb.instance;

    // Join invoices with clients to show client name
    return db.rawQuery('''
      SELECT 
        i.id,
        i.invoiceNumber,
        i.status,
        i.issueDate,
        i.dueDate,
        i.total,
        c.name AS clientName
      FROM invoices i
      JOIN clients c ON c.id = i.clientId
      ORDER BY i.id DESC
      LIMIT ?
    ''', [limit]);
  }
}
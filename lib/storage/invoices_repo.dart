import 'package:sqflite/sqflite.dart';
import 'app_db.dart';

class InvoicesRepo {
  Future<int> createInvoice({
    required int clientId,
    required DateTime issueDate,
    required DateTime dueDate,
    required String status, // "UNPAID" / "PAID"
    required double subtotal,
    required double totalVat,
    required double total,
    required List<InvoiceItemInput> items,
    String? invoiceNumber,
  }) async {
    final db = await AppDb.instance;
    final invNumber = invoiceNumber ?? _generateInvoiceNumber();

    return db.transaction<int>((txn) async {
      final invoiceId = await txn.insert('invoices', {
        'invoiceNumber': invNumber,
        'clientId': clientId,
        'issueDate': _dateOnly(issueDate),
        'dueDate': _dateOnly(dueDate),
        'status': status,
        'subtotal': subtotal,
        'totalVat': totalVat,
        'total': total,
      });

      for (final it in items) {
        final lineHt = it.quantity * it.unitPrice;
        final lineVat = lineHt * it.vat / 100;
        final lineTtc = lineHt + lineVat;

        await txn.insert('invoice_items', {
          'invoice_id': invoiceId,
          'invoice': invNumber,
          'product_code': it.productCode,
          'product': it.description,
          'qty': it.quantity,
          'tva_rate': it.vat,
          'montant_tva': lineVat,
          'price': it.unitPrice,
          'discount': it.discount,
          'subtotal': lineHt,
          'subtotalTTC': lineTtc,
          'invoice_date': _dateOnly(issueDate),
        });
      }

      return invoiceId;
    });
  }

  Future<List<Map<String, dynamic>>> getAllInvoicesWithClient() async {
    final db = await AppDb.instance;

    return db.rawQuery('''
      SELECT 
        i.id,
        i.invoiceNumber,
        i.issueDate,
        i.dueDate,
        i.status,
        i.subtotal,
        i.totalVat,
        i.total,
        c.name AS clientName,
        c.type AS clientType,
        c.fiscalId AS fiscalId,
        c.cin AS cin
      FROM invoices i
      JOIN clients c ON c.id = i.clientId
      ORDER BY i.id DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getInvoiceItems(int invoiceId) async {
    final db = await AppDb.instance;

    return db.query(
      'invoice_items',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
      orderBy: 'id DESC',
    );
  }

  Future<int> deleteInvoice(int invoiceId) async {
    final db = await AppDb.instance;
    return db.delete(
      'invoices',
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
  }

  String _generateInvoiceNumber() {
    final now = DateTime.now();
    final year = now.year;
    final seq = now.millisecondsSinceEpoch.toString().substring(7);
    return "INV-$year-$seq";
  }

  String _dateOnly(DateTime d) {
    return d.toIso8601String().split('T').first;
  }
}

class InvoiceItemInput {
  final String description;
  final double quantity;
  final double unitPrice;
  final double vat;

  // optional snapshot/catalog fields
  final String? productCode;
  final double discount;

  const InvoiceItemInput({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.vat,
    this.productCode,
    this.discount = 0.0,
  });
}
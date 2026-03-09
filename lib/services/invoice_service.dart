import 'package:my_app/storage/app_db.dart';

class InvoiceService {
  Future<int> createInvoice({
    required int clientId,
    required String invoiceNumber,
    required String issueDate,
    required String dueDate,
  }) async {
    final db = await AppDb.instance;
    return db.insert("invoices", {
      "invoiceNumber": invoiceNumber,
      "clientId": clientId,
      "issueDate": issueDate,
      "dueDate": dueDate,
      "status": "open",
      "subtotal": 0.0,
      "totalVat": 0.0,
      "total": 0.0,
    });
  }

  double _round3(double v) => double.parse(v.toStringAsFixed(3));

  Map<String, double> calcLine({
    required double qty,
    required double price,
    required double discount,
    required double tvaRate,
  }) {
    final ht = qty * price - discount;
    final tva = ht * (tvaRate / 100.0);
    final ttc = ht + tva;

    return {
      "subtotal": _round3(ht < 0 ? 0 : ht),
      "montant_tva": _round3(tva < 0 ? 0 : tva),
      "subtotalTTC": _round3(ttc < 0 ? 0 : ttc),
    };
  }

  Future<void> addItemFromProduct({
    required int invoiceId,
    required String invoiceNumber,
    required String invoiceDate,
    required Map<String, dynamic> product, // row from products table
    required double qty,
    double discount = 0.0,
    double? overridePrice,
    double? overrideTvaRate,
  }) async {
    final db = await AppDb.instance;

    final price = (overridePrice ?? (product["price"] as num)).toDouble();
    final tvaRate = (overrideTvaRate ?? (product["tva_rate"] ?? 0) as num).toDouble();

    final line = calcLine(
      qty: qty,
      price: price,
      discount: discount,
      tvaRate: tvaRate,
    );

    await db.insert("invoice_items", {
      "invoice_id": invoiceId,
      "invoice": invoiceNumber,
      "product_id": product["id"],
      "product_code": product["code"],
      "product": product["name"],
      "unit": product["unit"],
      "qty": qty,
      "tva_rate": tvaRate,
      "montant_tva": line["montant_tva"],
      "price": price,
      "discount": discount,
      "subtotal": line["subtotal"],
      "subtotalTTC": line["subtotalTTC"],
      "invoice_date": invoiceDate,
    });

    await recomputeInvoiceTotals(invoiceId);
  }

  Future<void> updateItem({
    required int itemId,
    required int invoiceId,
    required double qty,
    required double price,
    required double discount,
    required double tvaRate,
  }) async {
    final db = await AppDb.instance;

    final line = calcLine(qty: qty, price: price, discount: discount, tvaRate: tvaRate);

    await db.update(
      "invoice_items",
      {
        "qty": qty,
        "price": price,
        "discount": discount,
        "tva_rate": tvaRate,
        "montant_tva": line["montant_tva"],
        "subtotal": line["subtotal"],
        "subtotalTTC": line["subtotalTTC"],
      },
      where: "id = ?",
      whereArgs: [itemId],
    );

    await recomputeInvoiceTotals(invoiceId);
  }

  Future<void> deleteItem({required int itemId, required int invoiceId}) async {
    final db = await AppDb.instance;
    await db.delete("invoice_items", where: "id = ?", whereArgs: [itemId]);
    await recomputeInvoiceTotals(invoiceId);
  }

  Future<void> recomputeInvoiceTotals(int invoiceId) async {
    final db = await AppDb.instance;

    final rows = await db.rawQuery('''
      SELECT
        COALESCE(SUM(subtotal), 0) as subtotal,
        COALESCE(SUM(montant_tva), 0) as totalVat,
        COALESCE(SUM(subtotalTTC), 0) as total
      FROM invoice_items
      WHERE invoice_id = ?
    ''', [invoiceId]);

    final subtotal = (rows.first["subtotal"] as num).toDouble();
    final totalVat = (rows.first["totalVat"] as num).toDouble();
    final total = (rows.first["total"] as num).toDouble();

    await db.update(
      "invoices",
      {
        "subtotal": double.parse(subtotal.toStringAsFixed(3)),
        "totalVat": double.parse(totalVat.toStringAsFixed(3)),
        "total": double.parse(total.toStringAsFixed(3)),
      },
      where: "id = ?",
      whereArgs: [invoiceId],
    );
  }
}
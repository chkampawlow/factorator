import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class InvoicePdfService {
  static Future<Uint8List> buildInvoicePdf({
    required Map<String, dynamic> invoice,
    required Map<String, dynamic> client,
    required List<Map<String, dynamic>> items,
  }) async {
    final pdf = pw.Document();

    String money(dynamic v) {
      final n = v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
      return n.toStringAsFixed(3);
    }

    final invoiceNumber = (invoice['invoiceNumber'] ?? '').toString();
    final issueDate = (invoice['issueDate'] ?? '').toString();
    final dueDate = (invoice['dueDate'] ?? '').toString();
    final status = (invoice['status'] ?? '').toString().toUpperCase();

    final clientName = (client['name'] ?? '').toString();
    final clientType = (client['type'] ?? '').toString();
    final clientEmail = (client['email'] ?? '').toString();
    final clientPhone = (client['phone'] ?? '').toString();
    final clientAddress = (client['address'] ?? '').toString();
    final clientFiscalId = (client['fiscalId'] ?? '').toString();
    final clientCin = (client['cin'] ?? '').toString();

    final clientIdText = clientType == 'company'
        ? "MF: ${clientFiscalId.isEmpty ? '-' : clientFiscalId}"
        : "CIN: ${clientCin.isEmpty ? '-' : clientCin}";

    final subtotal = money(invoice['subtotal']);
    final totalVat = money(invoice['totalVat']);
    final total = money(invoice['total']);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                "INVOICE",
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey300,
                  borderRadius: pw.BorderRadius.circular(20),
                ),
                child: pw.Text(
                  status,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("Client", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 6),
                      pw.Text(clientName),
                      pw.Text(clientIdText),
                      if (clientEmail.isNotEmpty) pw.Text(clientEmail),
                      if (clientPhone.isNotEmpty) pw.Text(clientPhone),
                      if (clientAddress.isNotEmpty) pw.Text(clientAddress),
                    ],
                  ),
                ),
                pw.SizedBox(width: 20),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("Invoice info", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 6),
                      pw.Text("Number: $invoiceNumber"),
                      pw.Text("Issue date: $issueDate"),
                      pw.Text("Due date: $dueDate"),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(4),
              1: const pw.FlexColumnWidth(1.2),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1.2),
              4: const pw.FlexColumnWidth(1.8),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _cell("Description", bold: true),
                  _cell("Qty", bold: true),
                  _cell("Price", bold: true),
                  _cell("TVA", bold: true),
                  _cell("Total", bold: true),
                ],
              ),
              ...items.map((it) {
                final description = (it['product'] ?? '').toString();
                final qty = money(it['qty'] ?? 0);
                final price = money(it['price'] ?? 0);
                final tvaRate = money(it['tva_rate'] ?? 0);
                final lineTotal = money(it['subtotalTTC'] ?? 0);

                return pw.TableRow(
                  children: [
                    _cell(description),
                    _cell(qty),
                    _cell(price),
                    _cell("$tvaRate%"),
                    _cell(lineTotal),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 220,
              child: pw.Column(
                children: [
                  _totalRow("Subtotal (HT)", subtotal),
                  _totalRow("TVA", totalVat),
                  pw.Divider(),
                  _totalRow("Total (TTC)", total, bold: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _cell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: 10,
        ),
      ),
    );
  }

  static pw.Widget _totalRow(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            "$value TND",
            style: pw.TextStyle(
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
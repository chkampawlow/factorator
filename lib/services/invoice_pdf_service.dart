import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class InvoicePdfService {
  static final NumberFormat _money = NumberFormat('#,##0.000', 'en_US');

  static double _toDouble(dynamic value, [double fallback = 0.0]) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.')) ?? fallback;
  }

  static String _safe(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    final s = value.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  static String _moneyText(dynamic value) {
    return _money.format(_toDouble(value));
  }

  static pw.Widget _infoLine(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 105,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _summaryRow(String label, String value, {bool bold = false}) {
    final style = pw.TextStyle(
      fontSize: bold ? 12 : 10,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(value, style: style),
        ],
      ),
    );
  }

  static Future<Uint8List> buildInvoicePdf({
    required Map<String, dynamic> invoice,
    required Map<String, dynamic> client,
    required List<Map<String, dynamic>> items,
  }) async {
    final pdf = pw.Document();

    final invoiceNumber = _safe(invoice['invoiceNumber'], 'N/A');
    final issueDate = _safe(invoice['issueDate'], '-');
    final dueDate = _safe(invoice['dueDate'], '-');
    final status = _safe(invoice['status'], 'OPEN').toUpperCase();

    final userFirstName = _safe(invoice['userFirstName'], '-');
    final userLastName = _safe(invoice['userLastName'], '-');
    final userFiscalId = _safe(invoice['userFiscalId'], '-');
    final fullUserName = '$userFirstName $userLastName'.trim() == ''
        ? '-'
        : '$userFirstName $userLastName'.trim();

    final clientName = _safe(client['name'], 'Client');
    final clientType = _safe(client['type'], 'individual');
    final clientEmail = _safe(client['email']);
    final clientPhone = _safe(client['phone']);
    final clientAddress = _safe(client['address'], '-');
    final clientFiscalId = _safe(client['fiscalId']);
    final clientCin = _safe(client['cin']);

    final subtotal = _moneyText(invoice['subtotal']);
    final totalVat = _moneyText(invoice['totalVat']);
    final total = _moneyText(invoice['total']);

    final identityValue = clientFiscalId.isNotEmpty ? clientFiscalId : clientCin;
    final identityLabel = clientFiscalId.isNotEmpty
        ? 'Matricule fiscal'
        : (clientCin.isNotEmpty ? 'CIN' : 'Identifiant');

    final tableData = items.map((item) {
      final productId = _safe(
        item['product_id'] ??
            item['id_product'] ??
            item['productCode'] ??
            item['product_code'],
        '-',
      );
      final product = _safe(item['product'], '-');
      final qty = _toDouble(item['qty']).toStringAsFixed(2);
      final price = _moneyText(item['price']);
      final tvaRate = '${_toDouble(item['tva_rate']).toStringAsFixed(0)}%';
      final discount = '${_toDouble(item['discount']).toStringAsFixed(0)}%';
      final ht = _moneyText(item['subtotal']);
      final ttc = _moneyText(item['subtotalTTC']);

      return [productId, product, qty, price, tvaRate, discount, ht, ttc];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 18),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'INVOICE',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.teal700,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Professional Invoice Document',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.teal50,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.teal200),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        invoiceNumber,
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        status,
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: status == 'PAID'
                              ? PdfColors.green700
                              : PdfColors.orange700,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 14),

          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey50,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Bill To',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.teal700,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      _infoLine('Date facture', issueDate),
                      _infoLine('Échéance', dueDate),
                      _infoLine('Nom et prénom', fullUserName),
                      _infoLine('MF utilisateur', userFiscalId),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 14),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey50,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Invoice Details',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.teal700,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      _infoLine('Nom', clientName),
                      _infoLine(
                        identityLabel,
                        identityValue.isNotEmpty ? identityValue : '-',
                      ),
                      _infoLine('Adresse', clientAddress),
                      if (clientEmail.isNotEmpty) _infoLine('Email', clientEmail),
                      if (clientPhone.isNotEmpty) _infoLine('Phone', clientPhone),
                      _infoLine('Type', clientType),
                    ],
                  ),
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 18),

          pw.Text(
            'Items',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.teal700,
            ),
          ),

          pw.SizedBox(height: 8),

          pw.Table.fromTextArray(
            headers: const [
              'ID',
              'Product',
              'Qty',
              'Price',
              'TVA',
              'Discount',
              'HT',
              'TTC',
            ],
            data: tableData,
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 10,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.teal700,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            headerAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 8,
            ),
            headerPadding: const pw.EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 8,
            ),
            border: pw.TableBorder.all(
              color: PdfColors.grey300,
              width: 0.5,
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.1),
              1: const pw.FlexColumnWidth(3.2),
              2: const pw.FlexColumnWidth(0.9),
              3: const pw.FlexColumnWidth(1.2),
              4: const pw.FlexColumnWidth(0.9),
              5: const pw.FlexColumnWidth(1.1),
              6: const pw.FlexColumnWidth(1.2),
              7: const pw.FlexColumnWidth(1.2),
            },
          ),

          pw.SizedBox(height: 18),

          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Notes',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 11,
                          color: PdfColors.teal700,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'Thank you for your business. Please verify the invoice details before payment.',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Container(
                width: 180,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey50,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  children: [
                    _summaryRow('Subtotal', '$subtotal TND'),
                    _summaryRow('TVA', '$totalVat TND'),
                    pw.Divider(color: PdfColors.grey400),
                    _summaryRow('TOTAL', '$total TND', bold: true),
                  ],
                ),
              ),
            ],
          ),
        ],
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 14),
          child: pw.Column(
            children: [
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 4),
              pw.Text(
                'Generated electronically • Page ${context.pageNumber} / ${context.pagesCount}',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return pdf.save();
  }
}
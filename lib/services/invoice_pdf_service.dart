import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart' show Color, ColorScheme;
import 'package:pdf/pdf.dart';
import 'currency_service.dart';
import 'exchange_rate_service.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;

class InvoicePdfService {
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

  static PdfColor _pdfColor(Color color) {
    return PdfColor(
      color.red / 255,
      color.green / 255,
      color.blue / 255,
    );
  }

  static pw.Widget _infoLine(
    String label,
    String value, {
    required PdfColor labelColor,
    required PdfColor valueColor,
  }) {
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
                color: labelColor,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 10,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _summaryRow(
    String label,
    String value, {
    bool bold = false,
    required PdfColor textColor,
  }) {
    final style = pw.TextStyle(
      fontSize: bold ? 12 : 10,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: textColor,
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
    required ColorScheme colorScheme,
    Map<String, String>? labels,
    Uint8List? logoBytes,
    String? logoPath,
  }) async {
    final isArabic = (labels?['invoice'] ?? '').contains('فاتورة');

    pw.Font? arabicFont;
    pw.Font? arabicBold;

    if (isArabic) {
      try {
        final fontData =
            await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
        final boldData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');

        arabicFont = pw.Font.ttf(fontData);
        arabicBold = pw.Font.ttf(boldData);
      } catch (_) {
        throw Exception(
          'Arabic PDF font assets are missing. Add assets/fonts/Cairo-Regular.ttf and assets/fonts/Cairo-Bold.ttf to your project and declare them in pubspec.yaml.',
        );
      }
    }

    final pdf = isArabic
        ? pw.Document(
            theme: pw.ThemeData.withFont(
              base: arabicFont!,
              bold: arabicBold!,
            ),
          )
        : pw.Document();

    final l = labels ??
        {
          'invoice': 'INVOICE',
          'issueDate': 'Issue date',
          'dueDate': 'Due date',
          'organization': 'Organization',
          'userFiscalId': 'User fiscal id',
          'name': 'Name',
          'fiscalId': 'Fiscal ID',
          'cin': 'CIN',
          'identifier': 'Identifier',
          'address': 'Address',
          'email': 'Email',
          'phone': 'Phone',
          'type': 'Type',
          'items': 'Items',
          'notes': 'Notes',
          'subtotal': 'Subtotal',
          'vat': 'TVA',
          'total': 'TOTAL',
          'product': 'Product',
          'qty': 'Qty',
          'price': 'Price',
          'discount': 'Discount',
          'ht': 'HT',
          'ttc': 'TTC',
          'website': 'Website',
          'fax': 'Fax',
        };

    // Resolve logo from either memory bytes or local file path
    Uint8List? resolvedLogo;

    if (logoBytes != null) {
      resolvedLogo = logoBytes;
    } else if (logoPath != null) {
      try {
        final file = File(logoPath);
        if (await file.exists()) {
          resolvedLogo = await file.readAsBytes();
        }
      } catch (_) {}
    }

    final primary = _pdfColor(colorScheme.primary);
    final onPrimary = _pdfColor(colorScheme.onPrimary);
    final surface = _pdfColor(colorScheme.surface);
    final surfaceContainer = _pdfColor(colorScheme.surfaceContainerHighest);
    final outline = _pdfColor(colorScheme.outlineVariant);
    final onSurface = _pdfColor(colorScheme.onSurface);
    final onSurfaceVariant = _pdfColor(colorScheme.onSurfaceVariant);
    final primaryContainer = _pdfColor(colorScheme.primaryContainer);
    final successColor = PdfColors.green700;
    final warningColor = PdfColors.orange700;

    final invoiceNumber = _safe(invoice['invoiceNumber'], 'N/A');
    final issueDate = _safe(invoice['issueDate'], '-');
    final dueDate = _safe(invoice['dueDate'], '-');
    final status = _safe(invoice['status'], 'OPEN').toUpperCase();

    final currency = _safe(invoice['currency'], 'TND');

    final userOrganizationName = _safe(invoice['userOrganizationName'], '-');
    final userFiscalId = _safe(invoice['userFiscalId'], '-');

    final clientName = _safe(client['name'], 'Client');
    final clientType = _safe(client['type'], 'individual');
    final clientEmail = _safe(client['email']);
    final clientPhone = _safe(client['phone']);
    final clientAddress = _safe(client['address'], '-');
    final clientFiscalId = _safe(client['fiscalId']);
    final clientCin = _safe(client['cin']);

    final notesText = _safe(invoice['notes']).isEmpty
        ? 'Thank you for your business. Please verify the invoice details before payment.'
        : _safe(invoice['notes']);
    final subtotalValue = _toDouble(invoice['subtotal']);
    final fodecRate = _toDouble(invoice['fodecRate']);
    final calculatedFodecValue =
        fodecRate > 0 ? subtotalValue * (fodecRate / 100.0) : 0.0;
    final storedBaseTvaValue = _toDouble(invoice['baseTva'], subtotalValue);
    final baseTvaValue = fodecRate <= 0
        ? subtotalValue
        : (storedBaseTvaValue <= subtotalValue + 0.0005
            ? subtotalValue + calculatedFodecValue
            : storedBaseTvaValue);
    final fodecValue = fodecRate > 0
        ? (baseTvaValue - subtotalValue).clamp(0.0, double.infinity)
        : 0.0;
    final totalVatValue = _toDouble(invoice['totalVat']);
    final timbreValue =
        _toDouble(invoice['timbre'], ExchangeRateService.timbreTnd);
    final storedTotalValue = _toDouble(invoice['total']);
    final itemTotalValue = baseTvaValue + totalVatValue;
    final displayTotalValue = storedTotalValue <= itemTotalValue + 0.0005
        ? itemTotalValue + timbreValue
        : storedTotalValue;

    final subtotal = CurrencyService.format(subtotalValue, currency);
    final fodec = CurrencyService.format(fodecValue, currency);
    final baseTva = CurrencyService.format(baseTvaValue, currency);
    final totalVat = CurrencyService.format(totalVatValue, currency);
    final timbre = CurrencyService.format(timbreValue, currency);
    final total = CurrencyService.format(displayTotalValue, currency);

    final identityValue =
        clientFiscalId.isNotEmpty ? clientFiscalId : clientCin;
    final identityLabel = clientFiscalId.isNotEmpty
        ? l['fiscalId']!
        : (clientCin.isNotEmpty ? l['cin']! : l['identifier']!);

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
      final price = CurrencyService.format(_toDouble(item['price']), currency);
      final tvaRate = '${_toDouble(item['tva_rate']).toStringAsFixed(0)}%';
      final discount = '${_toDouble(item['discount']).toStringAsFixed(0)}%';
      final ht = CurrencyService.format(_toDouble(item['subtotal']), currency);
      final ttc =
          CurrencyService.format(_toDouble(item['subtotalTTC']), currency);

      return [productId, product, qty, price, tvaRate, discount, ht, ttc];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Directionality(
            textDirection:
                isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            child: pw.Column(
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.only(bottom: 18),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          resolvedLogo != null
                              ? pw.Container(
                                  height: 80,
                                  child: pw.Image(
                                    pw.MemoryImage(resolvedLogo),
                                    fit: pw.BoxFit.contain,
                                  ),
                                )
                              : pw.Text(
                                  l['invoice']!,
                                  style: pw.TextStyle(
                                    fontSize: 24,
                                    fontWeight: pw.FontWeight.bold,
                                    color: primary,
                                  ),
                                ),
                          pw.SizedBox(height: 6),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: pw.BoxDecoration(
                          color: primaryContainer,
                          borderRadius: pw.BorderRadius.circular(8),
                          border: pw.Border.all(color: outline),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(
                              invoiceNumber,
                              style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                                color: onSurface,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              status,
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: status == 'PAID'
                                    ? successColor
                                    : warningColor,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Divider(color: outline),
                pw.SizedBox(height: 14),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                          color: surfaceContainer,
                          borderRadius: pw.BorderRadius.circular(8),
                          border: pw.Border.all(color: outline),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.SizedBox(height: 8),
                            _infoLine(
                              l['issueDate']!,
                              issueDate,
                              labelColor: onSurfaceVariant,
                              valueColor: onSurface,
                            ),
                            _infoLine(
                              l['dueDate']!,
                              dueDate,
                              labelColor: onSurfaceVariant,
                              valueColor: onSurface,
                            ),
                            _infoLine(
                              l['organization']!,
                              userOrganizationName,
                              labelColor: onSurfaceVariant,
                              valueColor: onSurface,
                            ),
                            _infoLine(
                              l['userFiscalId']!,
                              userFiscalId,
                              labelColor: onSurfaceVariant,
                              valueColor: onSurface,
                            ),
                          ],
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 14),
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                          color: surfaceContainer,
                          borderRadius: pw.BorderRadius.circular(8),
                          border: pw.Border.all(color: outline),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.SizedBox(height: 8),
                            _infoLine(
                              l['name']!,
                              clientName,
                              labelColor: onSurfaceVariant,
                              valueColor: onSurface,
                            ),
                            _infoLine(
                              identityLabel,
                              identityValue.isNotEmpty ? identityValue : '-',
                              labelColor: onSurfaceVariant,
                              valueColor: onSurface,
                            ),
                            _infoLine(
                              l['address']!,
                              clientAddress,
                              labelColor: onSurfaceVariant,
                              valueColor: onSurface,
                            ),
                            if (clientEmail.isNotEmpty)
                              _infoLine(
                                l['email']!,
                                clientEmail,
                                labelColor: onSurfaceVariant,
                                valueColor: onSurface,
                              ),
                            if (clientPhone.isNotEmpty)
                              _infoLine(
                                l['phone']!,
                                clientPhone,
                                labelColor: onSurfaceVariant,
                                valueColor: onSurface,
                              ),
                            _infoLine(
                              l['type']!,
                              clientType,
                              labelColor: onSurfaceVariant,
                              valueColor: onSurface,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 18),
                pw.Text(
                  l['items']!,
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: primary,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Table.fromTextArray(
                  headers: [
                    'ID',
                    l['product']!,
                    l['qty']!,
                    l['price']!,
                    l['vat']!,
                    l['discount']!,
                    l['ht']!,
                    l['ttc']!,
                  ],
                  data: tableData,
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: onPrimary,
                    fontSize: 10,
                  ),
                  headerDecoration: pw.BoxDecoration(
                    color: primary,
                  ),
                  cellStyle: pw.TextStyle(
                    fontSize: 9,
                    color: onSurface,
                  ),
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
                    color: outline,
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
                          color: surface,
                          border: pw.Border.all(color: outline),
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              l['notes']!,
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 11,
                                color: primary,
                              ),
                            ),
                            pw.SizedBox(height: 6),
                            pw.Text(
                              notesText,
                              style: pw.TextStyle(
                                fontSize: 9,
                                color: onSurface,
                              ),
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
                        color: surfaceContainer,
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: outline),
                      ),
                      child: pw.Column(
                        children: [
                          _summaryRow(
                            l['subtotal']!,
                            subtotal,
                            textColor: onSurface,
                          ),
                          if (fodecRate > 0) ...[
                            _summaryRow(
                              'FODEC ${fodecRate.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\\.$'), '')}%',
                              fodec,
                              textColor: onSurface,
                            ),
                            _summaryRow(
                              'Base TVA',
                              baseTva,
                              textColor: onSurface,
                            ),
                          ],
                          _summaryRow(
                            l['vat']!,
                            totalVat,
                            textColor: onSurface,
                          ),
                          _summaryRow(
                            'Timbre',
                            timbre,
                            textColor: onSurface,
                          ),
                          pw.Divider(color: outline),
                          _summaryRow(
                            l['total']!,
                            total,
                            bold: true,
                            textColor: primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        footer: (context) => pw.Directionality(
          textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          child: pw.Container(
            margin: const pw.EdgeInsets.only(top: 14),
            child: pw.Column(
              children: [
                pw.Divider(color: outline),
                pw.SizedBox(height: 4),
                pw.Text(
                  [
                    if (_safe(invoice['userPhone']).isNotEmpty)
                      '${l['phone']}: ${_safe(invoice['userPhone'])}',
                    if (_safe(invoice['userFax']).isNotEmpty)
                      '${l['fax']}: ${_safe(invoice['userFax'])}',
                    if (_safe(invoice['userAddress']).isNotEmpty)
                      '${l['address']}: ${_safe(invoice['userAddress'])}',
                    if (_safe(invoice['userWebsite']).isNotEmpty)
                      '${l['website']}: ${_safe(invoice['userWebsite'])}',
                    if (_safe(invoice['userEmail']).isNotEmpty)
                      '${l['email']}: ${_safe(invoice['userEmail'])}',
                  ].join(' | '),
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 8,
                    color: onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return pdf.save();
  }
}

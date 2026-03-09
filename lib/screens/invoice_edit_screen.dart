import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_app/screens/invoice_pdf_service.dart';
import 'package:my_app/services/pdf_preview.dart';
import 'package:my_app/storage/products_repo.dart';
import 'package:my_app/storage/invoice_items_repo.dart';
import 'package:my_app/storage/invoices_repo.dart';
import 'package:my_app/storage/invoices_api_repo.dart';

class InvoiceEditScreen extends StatefulWidget {
  final int invoiceId;

  const InvoiceEditScreen({
    super.key,
    required this.invoiceId,
  });

  @override
  State<InvoiceEditScreen> createState() => _InvoiceEditScreenState();
}

class _InvoiceEditScreenState extends State<InvoiceEditScreen> {
  bool _loading = true;
  String? _error;

  final _productsRepo = ProductsRepo();
  final _invoiceItemsRepo = InvoiceItemsRepo();
  final _invoicesApiRepo = InvoicesApiRepo();
  final _invoicesRepo = InvoicesRepo();

  Map<String, dynamic>? _invoice;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _products = [];

  Map<String, dynamic>? _selectedProduct;
  int? _selectedProductId;

  final TextEditingController _qtyCtrl = TextEditingController(text: "1");
  final TextEditingController _discountCtrl = TextEditingController(text: "0");
  final TextEditingController _customPriceCtrl = TextEditingController();

  final _money = NumberFormat("#,##0.000", "en_US");

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _discountCtrl.dispose();
    _customPriceCtrl.dispose();
    super.dispose();
  }

  int _toInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? fallback;
  }

  double _toD(dynamic v, [double fallback = 0.0]) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }

  double _qty() => double.tryParse(_qtyCtrl.text.trim().replaceAll(',', '.')) ?? 1.0;

  double _discountPct() =>
      double.tryParse(_discountCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final remoteInv = await _invoicesRepo.getInvoiceById(widget.invoiceId);
      final products = await _productsRepo.getAllProducts();
      final items = await _invoiceItemsRepo.getInvoiceItems(widget.invoiceId);

      final inv = {
        'id': remoteInv['id'],
        'invoiceNumber': remoteInv['invoice'],
        'issueDate': remoteInv['invoice_date'],
        'dueDate': remoteInv['invoice_due_date'],
        'subtotal': remoteInv['subtotal'],
        'totalVat': remoteInv['montant_tva'],
        'total': remoteInv['total'],
        'status': remoteInv['status'],
        'clientName': remoteInv['custom_email'] ?? 'Client',
        'clientEmail': remoteInv['custom_email'] ?? '',
        'clientPhone': '',
        'clientAddress': '',
        'clientType': 'individual',
        'clientFiscalId': '',
        'clientCin': remoteInv['custom_code'] ?? '',
      };

      setState(() {
        _invoice = inv;
        _products = products;
        _items = items;

        if (products.isEmpty) {
          _selectedProduct = null;
          _selectedProductId = null;
        } else {
          final exists = _selectedProductId != null &&
              products.any((p) => _toInt(p['id']) == _selectedProductId);

          if (exists) {
            _selectedProduct = products.firstWhere(
              (p) => _toInt(p['id']) == _selectedProductId,
            );
          } else {
            _selectedProduct = products.first;
            _selectedProductId = _toInt(products.first['id']);
          }
        }

        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  double _productPrice() {
    if (_selectedProduct == null) return 0.0;

    final override = _customPriceCtrl.text.trim().replaceAll(',', '.');
    if (override.isNotEmpty) {
      final p = double.tryParse(override);
      if (p != null && p >= 0) return p;
    }

    return _toD(_selectedProduct!['price'], 0.0);
  }

  double _productTvaRate() {
    if (_selectedProduct == null) return 0.0;
    return _toD(_selectedProduct!['tva_rate'], 0.0);
  }

  _LineTotals _computeLineTotals({
    required double qty,
    required double price,
    required double discountPct,
    required double tvaRate,
  }) {
    final htBeforeDiscount = qty * price;
    final discountValue = htBeforeDiscount * (discountPct / 100.0);
    final ht = (htBeforeDiscount - discountValue).clamp(0.0, double.infinity);
    final tva = ht * (tvaRate / 100.0);
    final ttc = ht + tva;

    return _LineTotals(ht: ht, tva: tva, ttc: ttc);
  }

  Future<void> _recomputeAndUpdateInvoiceTotals() async {
    await _invoicesApiRepo.recomputeInvoiceTotals(widget.invoiceId);
    await _loadAll();
  }

  Future<void> _addItem() async {
    if (_invoice == null || _selectedProduct == null) return;

    final qty = _qty();

    if (qty <= 0) {
      _toast("Qty must be > 0");
      return;
    }

    final price = _productPrice();
    final discountPct = _discountPct().clamp(0.0, 100.0);
    final tvaRate = _productTvaRate();

    final totals = _computeLineTotals(
      qty: qty,
      price: price,
      discountPct: discountPct,
      tvaRate: tvaRate,
    );

    final invoiceNumber = (_invoice!['invoiceNumber'] ?? '').toString();
    final issueDate = (_invoice!['issueDate'] ?? '').toString().split(' ').first;

    await _invoiceItemsRepo.addInvoiceItem(
      invoiceId: widget.invoiceId,
      invoice: invoiceNumber,
      productCode: (_selectedProduct!['code'] ?? '').toString(),
      product: (_selectedProduct!['name'] ?? '').toString(),
      qty: qty,
      tvaRate: tvaRate,
      montantTva: totals.tva,
      price: price,
      discount: discountPct,
      subtotal: totals.ht,
      subtotalTTC: totals.ttc,
      invoiceDate: issueDate,
    );

    _qtyCtrl.text = "1";
    _discountCtrl.text = "0";
    _customPriceCtrl.clear();

    await _recomputeAndUpdateInvoiceTotals();
  }

  Future<void> _deleteItem(int itemId) async {
    await _invoiceItemsRepo.deleteInvoiceItem(itemId);
    await _recomputeAndUpdateInvoiceTotals();
  }

  Future<void> _previewPdf() async {
    if (_invoice == null) {
      _toast("Invoice not found.");
      return;
    }

    if (_items.isEmpty) {
      _toast("Add at least one item before previewing the PDF.");
      return;
    }

    final client = <String, dynamic>{
      'name': _invoice!['clientName'],
      'type': _invoice!['clientType'],
      'fiscalId': _invoice!['clientFiscalId'],
      'cin': _invoice!['clientCin'],
      'email': _invoice!['clientEmail'],
      'phone': _invoice!['clientPhone'],
      'address': _invoice!['clientAddress'],
    };

    final bytes = await InvoicePdfService.buildInvoicePdf(
      invoice: _invoice!,
      client: client,
      items: _items,
    );

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfPreviewScreen(
          pdfBytes: bytes,
          title: (_invoice!['invoiceNumber'] ?? 'Invoice').toString(),
        ),
      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Invoice")),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Error", style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: cs.error)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadAll,
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    if (_invoice == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Invoice")),
        body: const Center(child: Text("Invoice not found")),
      );
    }

    final invNum = (_invoice!['invoiceNumber'] ?? '').toString();
    final status = (_invoice!['status'] ?? 'UNPAID').toString();
    final clientName = (_invoice!['clientName'] ?? 'Client').toString();

    final subtotal = _toD(_invoice!['subtotal']);
    final tva = _toD(_invoice!['totalVat']);
    final total = _toD(_invoice!['total']);

    final lineTotals = _selectedProduct == null
        ? _LineTotals(ht: 0, tva: 0, ttc: 0)
        : _computeLineTotals(
            qty: _qty(),
            price: _productPrice(),
            discountPct: _discountPct().clamp(0, 100),
            tvaRate: _productTvaRate(),
          );

    return Scaffold(
      appBar: AppBar(
        title: Text("Fill • $invNum"),
        actions: [
          IconButton(
            onPressed: _previewPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: "Preview PDF",
          ),
          IconButton(
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            clientName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text("Status: ${status.toUpperCase()}"),
                          const SizedBox(height: 4),
                          Text(
                            "Issue: ${(_invoice!['issueDate'] ?? '')}  •  Due: ${(_invoice!['dueDate'] ?? '')}",
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "HT ${_money.format(subtotal)}",
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                        Text(
                          "TVA ${_money.format(tva)}",
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${_money.format(total)} TND",
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Add item",
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: DropdownButtonFormField<int>(
                            value: _selectedProductId,
                            items: _products.map((p) {
                              final id = _toInt(p['id']);
                              return DropdownMenuItem<int>(
                                value: id,
                                child: Text(
                                  "${(p['name'] ?? '')} • ${_money.format(_toD(p['price']))}",
                                ),
                              );
                            }).toList(),
                            onChanged: (id) {
                              setState(() {
                                _selectedProductId = id;
                                if (id == null) {
                                  _selectedProduct = null;
                                } else {
                                  _selectedProduct = _products.firstWhere(
                                    (p) => _toInt(p['id']) == id,
                                  );
                                }
                              });
                            },
                            decoration: const InputDecoration(
                              labelText: "Product",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _qtyCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: "Qty",
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _discountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: "Discount (%)",
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _customPriceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: "Price override",
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          Text(
                            "TVA ${_productTvaRate().toStringAsFixed(0)}%",
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text("HT ${_money.format(lineTotals.ht)}"),
                          Text("TVA ${_money.format(lineTotals.tva)}"),
                          Text(
                            "TTC ${_money.format(lineTotals.ttc)}",
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton.icon(
                        onPressed: _products.isEmpty ? null : _addItem,
                        icon: const Icon(Icons.add),
                        label: const Text("Add to invoice"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Card(
                child: _items.isEmpty
                    ? Center(
                        child: Text(
                          "No items yet.",
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final it = _items[i];
                          final itemId = _toInt(it['id']);

                          final name = (it['product'] ?? '').toString();
                          final qty = _toD(it['qty']);
                          final price = _toD(it['price']);
                          final ht = _toD(it['subtotal']);
                          final ttc = _toD(it['subtotalTTC']);

                          return ListTile(
                            title: Text(
                              name,
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            subtitle: Text(
                              "${qty.toStringAsFixed(2)} × ${_money.format(price)}",
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("HT ${_money.format(ht)}"),
                                Text(
                                  "TTC ${_money.format(ttc)}",
                                  style: const TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                            onLongPress: () => _deleteItem(itemId),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineTotals {
  final double ht;
  final double tva;
  final double ttc;

  _LineTotals({
    required this.ht,
    required this.tva,
    required this.ttc,
  });
}
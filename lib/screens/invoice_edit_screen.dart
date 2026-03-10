import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/services/invoice_pdf_service.dart';
import 'package:my_app/services/pdf_preview.dart';
import 'package:my_app/storage/clients_repo.dart';
import 'package:my_app/storage/invoice_items_repo.dart';
import 'package:my_app/storage/invoices_repo.dart';
import 'package:my_app/storage/products_repo.dart';

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

  final _clientsRepo = ClientsRepo();
  final _productsRepo = ProductsRepo();
  final _invoiceItemsRepo = InvoiceItemsRepo();
  final _invoicesRepo = InvoicesRepo();
final _authService = AuthService();

  Map<String, dynamic>? _invoice;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _products = [];

  Map<String, dynamic>? _selectedProduct;
  int? _selectedProductId;

  final TextEditingController _qtyCtrl = TextEditingController(text: '1');
  final TextEditingController _discountCtrl = TextEditingController(text: '0');
  final TextEditingController _customPriceCtrl = TextEditingController();

  final _money = NumberFormat('#,##0.000', 'en_US');

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
    return double.tryParse(v.toString().replaceAll(',', '.')) ?? fallback;
  }

  double _qty() =>
      double.tryParse(_qtyCtrl.text.trim().replaceAll(',', '.')) ?? 1.0;

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
      final currentUser = await _authService.me();
      final rawClientId = remoteInv['custom_code'];
      final clientId = rawClientId is int
          ? rawClientId
          : int.tryParse(rawClientId.toString());

      Map<String, dynamic>? client;

      if (clientId != null && clientId > 0) {
        client = await _clientsRepo.getClientById(clientId);
      }

      final inv = {
        'id': remoteInv['id'],
        'invoiceNumber': remoteInv['invoice'],
        'issueDate': remoteInv['invoice_date'],
        'dueDate': remoteInv['invoice_due_date'],
        'subtotal': remoteInv['subtotal'],
        'totalVat': remoteInv['montant_tva'],
        'total': remoteInv['total'],
        'status': remoteInv['status'],
        'clientName': client?['name'] ?? 'Client',
        'clientEmail': client?['email'] ?? '',
        'clientPhone': client?['phone'] ?? '',
        'clientAddress': client?['address'] ?? '',
        'clientType': client?['type'] ?? 'individual',
        'clientFiscalId': client?['fiscalId'] ?? client?['fiscal_id'] ?? '',
        'clientCin': client?['cin'] ?? '',
        'userFirstName': currentUser['first_name'] ?? '',
        'userLastName': currentUser['last_name'] ?? '',
         'userFiscalId': currentUser['fiscal_id'] ?? '',
      };

      if (!mounted) return;

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
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
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

    return _toD(_selectedProduct?['price'], 0.0);
  }

  double _productTvaRate() {
    if (_selectedProduct == null) return 0.0;
    return _toD(_selectedProduct?['tva_rate'], 0.0);
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
    await _invoicesRepo.recomputeInvoiceTotals(widget.invoiceId);
    await _loadAll();
  }

  Future<void> _addItem() async {
    if (_invoice == null || _selectedProduct == null) return;

    final qty = _qty();

    if (qty <= 0) {
      _toast('Qty must be > 0');
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

    _qtyCtrl.text = '1';
    _discountCtrl.text = '0';
    _customPriceCtrl.clear();

    await _recomputeAndUpdateInvoiceTotals();
    _toast('Item added');
  }

  Future<void> _deleteItem(int itemId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete item'),
        content: const Text('Remove this item from the invoice?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _invoiceItemsRepo.deleteInvoiceItem(itemId);
    await _recomputeAndUpdateInvoiceTotals();
    _toast('Item deleted');
  }

  Future<void> _editItem(Map<String, dynamic> item) async {
    final qtyCtrl = TextEditingController(text: _toD(item['qty']).toString());
    final discountCtrl =
        TextEditingController(text: _toD(item['discount']).toString());
    final priceCtrl =
        TextEditingController(text: _toD(item['price']).toString());

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text((item['product'] ?? 'Edit item').toString()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qtyCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Qty',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Price',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: discountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Discount (%)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true) {
      final qty = _toD(qtyCtrl.text, 1.0);
      final price = _toD(priceCtrl.text, 0.0);
      final discount = _toD(discountCtrl.text, 0.0);
      final tvaRate = _toD(item['tva_rate'], 0.0);

      final totals = _computeLineTotals(
        qty: qty,
        price: price,
        discountPct: discount,
        tvaRate: tvaRate,
      );

      await _invoiceItemsRepo.updateInvoiceItem(
        id: _toInt(item['id']),
        invoiceId: _toInt(item['invoice_id']),
        invoice: (item['invoice'] ?? '').toString(),
        productCode: (item['product_code'] ?? '').toString(),
        product: (item['product'] ?? '').toString(),
        qty: qty,
        tvaRate: tvaRate,
        montantTva: totals.tva,
        price: price,
        discount: discount,
        subtotal: totals.ht,
        subtotalTTC: totals.ttc,
        invoiceDate: (item['invoice_date'] ?? '').toString(),
      );

      await _recomputeAndUpdateInvoiceTotals();
      _toast('Item updated');
    }

    qtyCtrl.dispose();
    discountCtrl.dispose();
    priceCtrl.dispose();
  }

  Future<void> _previewPdf() async {
    if (_invoice == null) {
      _toast('Invoice not found.');
      return;
    }

    if (_items.isEmpty) {
      _toast('Add at least one item before previewing the PDF.');
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

  Widget _buildSummaryCard(ColorScheme cs) {
    final invNum = (_invoice!['invoiceNumber'] ?? '').toString();
    final status = (_invoice!['status'] ?? 'UNPAID').toString();
    final clientName = (_invoice!['clientName'] ?? 'Client').toString();

    final subtotal = _toD(_invoice!['subtotal']);
    final tva = _toD(_invoice!['totalVat']);
    final total = _toD(_invoice!['total']);

    return Card(
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
                  Text('Invoice: $invNum'),
                  const SizedBox(height: 4),
                  Text('Status: ${status.toUpperCase()}'),
                  const SizedBox(height: 4),
                  Text(
                    'Issue: ${(_invoice!['issueDate'] ?? '')}  •  Due: ${(_invoice!['dueDate'] ?? '')}',
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'HT ${_money.format(subtotal)}',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                Text(
                  'TVA ${_money.format(tva)}',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_money.format(total)} TND',
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
    );
  }

  Widget _buildAddItemCard(ColorScheme cs) {
    final lineTotals = _selectedProduct == null
        ? _LineTotals(ht: 0, tva: 0, ttc: 0)
        : _computeLineTotals(
            qty: _qty(),
            price: _productPrice(),
            discountPct: _discountPct().clamp(0, 100),
            tvaRate: _productTvaRate(),
          );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add item',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: DropdownButtonFormField<int>(
                    value: _products.isEmpty ? null : _selectedProductId,
                    items: _products.map((p) {
                      final id = _toInt(p['id']);
                      return DropdownMenuItem<int>(
                        value: id,
                        child: Text(
                          '${(p['name'] ?? '')} • ${_money.format(_toD(p['price']))}',
                          overflow: TextOverflow.ellipsis,
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
                      labelText: 'Product',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _qtyCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Qty',
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
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Discount (%)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _customPriceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Price override',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
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
                    'TVA ${_productTvaRate().toStringAsFixed(0)}%',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text('HT ${_money.format(lineTotals.ht)}'),
                  Text('TVA ${_money.format(lineTotals.tva)}'),
                  Text(
                    'TTC ${_money.format(lineTotals.ttc)}',
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
                label: const Text('Add to invoice'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsCard(ColorScheme cs) {
    return Card(
      child: _items.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No items yet.',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
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

                return Dismissible(
                  key: ValueKey('invoice_item_$itemId'),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) async {
                    await _deleteItem(itemId);
                    return false;
                  },
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    color: cs.errorContainer,
                    child: Icon(
                      Icons.delete_outline,
                      color: cs.onErrorContainer,
                    ),
                  ),
                  child: ListTile(
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      '${qty.toStringAsFixed(2)} × ${_money.format(price)}',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('HT ${_money.format(ht)}'),
                        Text(
                          'TTC ${_money.format(ttc)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _editItem(it),
                    onLongPress: itemId > 0 ? () => _deleteItem(itemId) : null,
                  ),
                );
              },
            ),
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
        appBar: AppBar(title: const Text('Invoice')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Error', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: cs.error)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadAll,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_invoice == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Invoice')),
        body: const Center(child: Text('Invoice not found')),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text('Fill • ${(_invoice!['invoiceNumber'] ?? '')}'),
        actions: [
          IconButton(
            onPressed: _previewPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Preview PDF',
          ),
          IconButton(
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSummaryCard(cs),
                const SizedBox(height: 12),
                _buildAddItemCard(cs),
                const SizedBox(height: 12),
                _buildItemsCard(cs),
                const SizedBox(height: 20),
              ],
            ),
          ),
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
import 'package:flutter/material.dart';
import '../storage/clients_repo.dart';
import '../storage/products_repo.dart';
import '../storage/invoices_repo.dart';
import 'add_client_screen.dart';
import 'add_product_screen.dart';

class CreateInvoiceScreen extends StatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  final _clientsRepo = ClientsRepo();
  final _productsRepo = ProductsRepo();
  final _invoicesRepo = InvoicesRepo();

  Map<String, dynamic>? _selectedClient;

  DateTime _issueDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));

  final List<_InvoiceItem> _items = [];
  bool _saving = false;

  double get subtotal => _items.fold(0, (sum, it) => sum + (it.qty * it.unitPrice));
  double get totalVat => _items.fold(0, (sum, it) => sum + (it.qty * it.unitPrice * it.vat / 100));
  double get total => subtotal + totalVat;

  String _fmtDate(DateTime d) => d.toLocal().toString().split(" ")[0];

  double _toDouble(dynamic value, [double fallback = 0.0]) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  String _clientLabel(Map<String, dynamic> c) {
    final type = c['type']?.toString() ?? 'individual';
    if (type == 'company') return "${c['name']} • MF: ${c['fiscalId'] ?? '-'}";
    return "${c['name']} • CIN: ${c['cin'] ?? '-'}";
  }

  Future<void> _pickDate(bool isDue) async {
    final initial = isDue ? _dueDate : _issueDate;
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDate: initial,
    );
    if (picked == null) return;

    setState(() {
      if (isDue) {
        _dueDate = picked;
      } else {
        _issueDate = picked;
      }
    });
  }

  Future<void> _chooseClient() async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ClientPickerSheet(
        clientsRepo: _clientsRepo,
        clientLabel: _clientLabel,
      ),
    );

    if (selected != null) {
      setState(() => _selectedClient = selected);
    }
  }

  Future<void> _addItemFromProducts() async {
    final product = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProductPickerSheet(productsRepo: _productsRepo),
    );

    if (product == null) return;

    final qty = await _askNumber(
      title: "Quantity",
      hint: "e.g. 1",
      initial: "1",
    );
    if (qty == null) return;

    setState(() {
      _items.add(
        _InvoiceItem(
          productId: (product['id'] as int?) ?? 0,
          name: (product['name'] ?? '').toString(),
          qty: qty,
          unitPrice: _toDouble(product['price']),
          vat: _toDouble(product['tva_rate']), // ✅ FIX
          unit: (product['unit'] ?? '').toString(),
        ),
      );
    });
  }

  Future<double?> _askNumber({
    required String title,
    required String hint,
    String? initial,
  }) async {
    final ctrl = TextEditingController(text: initial ?? "");

    final value = await showDialog<double?>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
              Navigator.pop(context, v);
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );

    return value;
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  Future<void> _saveInvoice() async {
    if (_selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please choose a client.")),
      );
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add at least one item.")),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final invoiceId = await _invoicesRepo.createInvoice(
        clientId: _selectedClient!['id'] as int,
        issueDate: _issueDate,
        dueDate: _dueDate,
        status: "UNPAID",
        subtotal: subtotal,
        totalVat: totalVat,
        total: total,
        items: _items
            .map(
              (it) => InvoiceItemInput(
                description: it.name,
                quantity: it.qty,
                unitPrice: it.unitPrice,
                vat: it.vat,
              ),
            )
            .toList(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Invoice saved ✅ (id = $invoiceId)")),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Save failed: $e")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("New Invoice")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Card(
              child: ListTile(
                title: const Text("Client"),
                subtitle: Text(
                  _selectedClient == null
                      ? "Choose client or add new"
                      : _clientLabel(_selectedClient!),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _chooseClient,
              ),
            ),
            const SizedBox(height: 10),

            Card(
              child: ListTile(
                title: const Text("Issue date"),
                subtitle: Text(_fmtDate(_issueDate)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _issueDate = DateTime.now()),
                      child: const Text("Today"),
                    ),
                    const Icon(Icons.date_range),
                  ],
                ),
                onTap: () => _pickDate(false),
              ),
            ),

            const SizedBox(height: 10),

            Card(
              child: ListTile(
                title: const Text("Due date"),
                subtitle: Text(_fmtDate(_dueDate)),
                trailing: const Icon(Icons.event),
                onTap: () => _pickDate(true),
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                const Expanded(
                  child: Text(
                    "Items",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton.icon(
                  onPressed: _addItemFromProducts,
                  icon: const Icon(Icons.add),
                  label: const Text("Add item"),
                ),
              ],
            ),

            const SizedBox(height: 8),

            if (_items.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text("No items yet. Tap 'Add item' to choose products."),
                ),
              ),

            ..._items.asMap().entries.map((e) {
              final i = e.key;
              final it = e.value;

              final lineHt = it.qty * it.unitPrice;
              final lineVat = lineHt * it.vat / 100;
              final lineTtc = lineHt + lineVat;

              return Card(
                child: ListTile(
                  title: Text("${it.name} ${it.unit.isEmpty ? "" : "• ${it.unit}"}"),
                  subtitle: Text(
                    "Qty ${it.qty} × ${it.unitPrice.toStringAsFixed(2)} | TVA ${it.vat.toStringAsFixed(0)}%",
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        lineTtc.toStringAsFixed(2),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.delete_outline),
                        tooltip: "Remove",
                        onPressed: () => _removeItem(i),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _totalRow("Subtotal (HT)", subtotal),
                    const SizedBox(height: 6),
                    _totalRow("VAT", totalVat),
                    const Divider(height: 22),
                    _totalRow("Total (TTC)", total, bold: true),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: cs.primary),
                onPressed: _saving ? null : _saveInvoice,
                child: Text(
                  _saving ? "Saving..." : "Save Invoice",
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _totalRow(String label, double value, {bool bold = false}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
      fontSize: bold ? 16 : 14,
    );
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value.toStringAsFixed(2), style: style),
      ],
    );
  }
}

class _InvoiceItem {
  final int productId;
  final String name;
  final double qty;
  final double unitPrice;
  final double vat;
  final String unit;

  _InvoiceItem({
    required this.productId,
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.vat,
    required this.unit,
  });
}

class _ClientPickerSheet extends StatefulWidget {
  final ClientsRepo clientsRepo;
  final String Function(Map<String, dynamic>) clientLabel;

  const _ClientPickerSheet({
    required this.clientsRepo,
    required this.clientLabel,
  });

  @override
  State<_ClientPickerSheet> createState() => _ClientPickerSheetState();
}

class _ClientPickerSheetState extends State<_ClientPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();

    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.trim().toLowerCase();
      setState(() {
        _filtered = q.isEmpty
            ? _clients
            : _clients.where((c) {
                final name = (c['name'] ?? '').toString().toLowerCase();
                final mf = (c['fiscalId'] ?? '').toString().toLowerCase();
                final cin = (c['cin'] ?? '').toString().toLowerCase();
                return name.contains(q) || mf.contains(q) || cin.contains(q);
              }).toList();
      });
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await widget.clientsRepo.getAllClients();
    setState(() {
      _clients = data;
      _filtered = data;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .75,
          child: Column(
            children: [
              const SizedBox(height: 10),
              const Text(
                "Choose Client",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: "Search (name / MF / CIN)...",
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final saved = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddClientScreen()),
                      );
                      if (saved == true) await _load();
                    },
                    icon: const Icon(Icons.person_add),
                    label: const Text("Add new client"),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final c = _filtered[i];
                          return ListTile(
                            title: Text((c['name'] ?? '').toString()),
                            subtitle: Text(widget.clientLabel(c)),
                            onTap: () => Navigator.pop(context, c),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductPickerSheet extends StatefulWidget {
  final ProductsRepo productsRepo;
  const _ProductPickerSheet({required this.productsRepo});

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;

  double _toDouble(dynamic value, [double fallback = 0.0]) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  @override
  void initState() {
    super.initState();
    _load();

    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.trim().toLowerCase();
      setState(() {
        _filtered = q.isEmpty
            ? _products
            : _products.where((p) {
                final name = (p['name'] ?? '').toString().toLowerCase();
                final code = (p['code'] ?? '').toString().toLowerCase();
                final unit = (p['unit'] ?? '').toString().toLowerCase();
                return name.contains(q) || code.contains(q) || unit.contains(q);
              }).toList();
      });
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await widget.productsRepo.getAllProducts();
    setState(() {
      _products = data;
      _filtered = data;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .75,
          child: Column(
            children: [
              const SizedBox(height: 10),
              const Text(
                "Choose Product",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: "Search product...",
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final saved = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddProductScreen()),
                      );
                      if (saved == true) await _load();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text("Add new product"),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _filtered.isEmpty
                        ? const Center(child: Text("No products found"))
                        : ListView.builder(
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) {
                              final p = _filtered[i];

                              final name = (p['name'] ?? '').toString();
                              final price = _toDouble(p['price']);
                              final tvaRate = _toDouble(p['tva_rate']);
                              final unit = (p['unit'] ?? '-').toString();

                              return ListTile(
                                title: Text(name),
                                subtitle: Text(
                                  "Price ${price.toStringAsFixed(2)} • TVA ${tvaRate.toStringAsFixed(0)}% • Unit $unit",
                                ),
                                onTap: () => Navigator.pop(context, p),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
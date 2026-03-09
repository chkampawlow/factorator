import 'package:flutter/material.dart';
import 'package:my_app/storage/invoices_repo.dart';
import 'create_invoice_screen.dart';
import 'invoice_edit_screen.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final _repo = InvoicesRepo();

  bool _loading = true;
  List<Map<String, dynamic>> _invoices = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      final data = await _repo.getAllInvoices();
      setState(() {
        _invoices = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _invoices = [];
        _loading = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Load failed: $e")),
      );
    }
  }

  int _toInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? fallback;
  }

  double _toDouble(dynamic value, [double fallback = 0.0]) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  DateTime _parseDate(String s) {
    return DateTime.tryParse(s) ?? DateTime.now();
  }

  String _daysLeftText(DateTime due) {
    final now = DateTime.now();
    final d0 = DateTime(now.year, now.month, now.day);
    final d1 = DateTime(due.year, due.month, due.day);
    final diff = d1.difference(d0).inDays;

    if (diff > 0) return "Due in $diff day${diff == 1 ? "" : "s"}";
    if (diff == 0) return "Due today";
    final late = diff.abs();
    return "Overdue by $late day${late == 1 ? "" : "s"}";
  }

  Color _statusBg(String status, bool isOverdue, ColorScheme cs) {
    final s = status.toUpperCase();
    if (s == "PAID") return cs.primaryContainer;
    if (isOverdue) return cs.errorContainer;
    return cs.tertiaryContainer;
  }

  Color _statusFg(String status, bool isOverdue, ColorScheme cs) {
    final s = status.toUpperCase();
    if (s == "PAID") return cs.onPrimaryContainer;
    if (isOverdue) return cs.onErrorContainer;
    return cs.onTertiaryContainer;
  }

  String _money(dynamic value) {
    final n = _toDouble(value);
    return n.toStringAsFixed(3);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Invoices"),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh",
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateInvoiceScreen()),
          );
          await _load();
        },
        icon: const Icon(Icons.add),
        label: const Text("New Invoice"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _invoices.isEmpty
                ? _EmptyInvoices(
                    onCreate: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CreateInvoiceScreen()),
                      );
                      await _load();
                    },
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _invoices.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final inv = _invoices[i];

                        final invoiceId = _toInt(inv['id']);
                        final invNumber = (inv['invoice'] ?? '').toString();
                        final status = (inv['status'] ?? 'open').toString();
                        final total = _money(inv['total']);
                        final subtotal = _money(inv['subtotal']);
                        final vatAmount = _money(inv['montant_tva']);
                        final email = (inv['custom_email'] ?? '').toString();
                        final code = (inv['custom_code'] ?? '').toString();
                        final invoiceType = (inv['invoice_type'] ?? '').toString();
                        final typeDoc = (inv['type_doc'] ?? '').toString();

                        final due = _parseDate((inv['invoice_due_date'] ?? '').toString());
                        final issue = _parseDate((inv['invoice_date'] ?? '').toString());

                        final now = DateTime.now();
                        final overdue = status.toUpperCase() != "PAID" &&
                            DateTime(due.year, due.month, due.day)
                                .isBefore(DateTime(now.year, now.month, now.day));

                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    invNumber,
                                    style: const TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                ),
                                _StatusPill(
                                  text: overdue ? "OVERDUE" : status.toUpperCase(),
                                  bg: _statusBg(status, overdue, cs),
                                  fg: _statusFg(status, overdue, cs),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (email.isNotEmpty)
                                    Text(
                                      email,
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                  if (code.isNotEmpty ||
                                      invoiceType.isNotEmpty ||
                                      typeDoc.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        [
                                          if (code.isNotEmpty) "Code: $code",
                                          if (invoiceType.isNotEmpty) "Type: $invoiceType",
                                          if (typeDoc.isNotEmpty) "Doc: $typeDoc",
                                        ].join(" • "),
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${_daysLeftText(due)} • Issued ${issue.toLocal().toString().split(" ")[0]}",
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "HT $subtotal • TVA $vatAmount",
                                    style: TextStyle(color: cs.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "$total TND",
                                  style: const TextStyle(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 4),
                                Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                              ],
                            ),
                            onTap: () async {
                              if (invoiceId <= 0) return;

                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => InvoiceEditScreen(invoiceId: invoiceId),
                                ),
                              );
                              await _load();
                            },
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;

  const _StatusPill({
    required this.text,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: fg,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _EmptyInvoices extends StatelessWidget {
  final Future<void> Function() onCreate;

  const _EmptyInvoices({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Icon(
          Icons.receipt_long,
          size: 70,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 14),
        const Center(
          child: Text(
            "No invoices yet",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            "Create your first invoice to see it here.",
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text("Create Invoice"),
            ),
          ),
        ),
      ],
    );
  }
}
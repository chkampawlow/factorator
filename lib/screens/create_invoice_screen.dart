import 'package:flutter/material.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/widgets/app_alerts.dart';
import '../storage/clients_repo.dart';
import '../storage/invoices_repo.dart';
import 'add_client_screen.dart';
import 'invoice_edit_screen.dart';

class CreateInvoiceScreen extends StatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  final _clientsRepo = ClientsRepo();
  final _invoicesRepo = InvoicesRepo();

  Map<String, dynamic>? _selectedClient;

  final DateTime _issueDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));

  bool _saving = false;

  String _fmtDate(DateTime d) => d.toLocal().toString().split(' ')[0];

  int _toInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? fallback;
  }

  String _clientLabel(BuildContext context, Map<String, dynamic> c) {
    final l10n = AppLocalizations.of(context)!;
    final type = (c['type'] ?? 'individual').toString();

    if (type == 'company') {
      final mf = (c['fiscalId'] ?? c['fiscal_id'] ?? '-').toString();
      return '${c['name']} • ${l10n.mfLabel}: $mf';
    }

    return '${c['name']} • ${l10n.cin}: ${c['cin'] ?? '-'}';
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDate: _dueDate,
    );

    if (picked == null) return;

    setState(() {
      _dueDate = picked;
    });
  }

  Future<void> _chooseClient() async {
    final l10n = AppLocalizations.of(context)!;

    try {
      final selected = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _ClientPickerSheet(
          clientsRepo: _clientsRepo,
          clientLabel: (c) => _clientLabel(context, c),
        ),
      );

      if (selected != null && mounted) {
        setState(() => _selectedClient = selected);
      }
    } catch (e) {
      if (!mounted) return;
      AppAlerts.error(
        context,
        '${l10n.clientSelectionFailed}: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  Future<void> _saveInvoice() async {
    final l10n = AppLocalizations.of(context)!;

    if (_selectedClient == null) {
      AppAlerts.warning(context, l10n.pleaseChooseClient);
      return;
    }

    if (_saving) return;

    setState(() => _saving = true);

    try {
      final clientId = _toInt(_selectedClient!['id']);

      final invoiceId = await _invoicesRepo.createInvoiceHeader(
        clientId: clientId,
        issueDate: _issueDate,
        dueDate: _dueDate,
        status: 'open',
        subtotal: 0,
        totalVat: 0,
        total: 0,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => InvoiceEditScreen(invoiceId: invoiceId),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      AppAlerts.error(
        context,
        '${l10n.saveFailed}: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.newInvoice)),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: SizedBox(
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
              ),
              onPressed: _saving ? null : _saveInvoice,
              child: Text(
                _saving ? l10n.saving : l10n.createInvoice,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 90),
          children: [
            Card(
              child: ListTile(
                title: Text(l10n.client),
                subtitle: Text(
                  _selectedClient == null
                      ? l10n.chooseClientOrAddNew
                      : _clientLabel(context, _selectedClient!),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _chooseClient,
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                title: Text(l10n.dueDate),
                subtitle: Text(_fmtDate(_dueDate)),
                trailing: const Icon(Icons.event),
                onTap: _pickDueDate,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
  String? _error;

  bool _clientExists(String value) {
    final v = value.toLowerCase();

    return _clients.any((c) {
      final mf =
          (c['fiscalId'] ?? c['fiscal_id'] ?? '').toString().toLowerCase();
      final cin = (c['cin'] ?? '').toString().toLowerCase();
      return mf == v || cin == v;
    });
  }

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
                final mf = (c['fiscalId'] ?? c['fiscal_id'] ?? '')
                    .toString()
                    .toLowerCase();
                final cin = (c['cin'] ?? '').toString().toLowerCase();

                return name.contains(q) ||
                    mf.contains(q) ||
                    cin.contains(q);
              }).toList();
      });
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await widget.clientsRepo.getAllClientsarchived();

      if (!mounted) return;

      setState(() {
        _clients = data;
        _filtered = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final l10n = AppLocalizations.of(context)!;

    final searchValue = _searchCtrl.text.trim();

    final showAddButton =
        searchValue.isNotEmpty &&
        !_clientExists(searchValue) &&
        _filtered.isEmpty;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .75,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Text(
                l10n.chooseClient,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: l10n.searchNameMfCin,
                    prefixIcon: const Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (showAddButton)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.person_add),
                      label: Text('${l10n.addNewClient}: $searchValue'),
                      onPressed: () async {
                        final saved = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddClientScreen(
                              prefilledId: searchValue,
                            ),
                          ),
                        );

                        if (saved == true) {
                          await _load();
                        }
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.55),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.error.withOpacity(0.25),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.error_rounded,
                                    color: Theme.of(context).colorScheme.onErrorContainer,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      '${l10n.loadFailed}: ${_error ?? ''}',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onErrorContainer,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
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
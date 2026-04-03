import 'package:flutter/material.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/screens/create_expense_note_screen.dart';
import 'package:my_app/screens/edit_expense_note_screen.dart';
import 'package:my_app/services/currency_service.dart';
import 'package:my_app/services/settings_service.dart';
import 'package:my_app/storage/expense_notes_repo.dart';
import 'package:my_app/widgets/app_alerts.dart';

class ExpenseNotesScreen extends StatefulWidget {
  const ExpenseNotesScreen({super.key});

  @override
  State<ExpenseNotesScreen> createState() => _ExpenseNotesScreenState();
}

class _ExpenseNotesScreenState extends State<ExpenseNotesScreen> {
  final ExpenseNotesRepo _repo = ExpenseNotesRepo();
  final SettingsService _settingsService = SettingsService();
  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = true;
  bool _didLoadOnce = false;
  bool _updatingStatus = false;

  String _currency = '';
  String _statusFilter = 'all';

  List<Map<String, dynamic>> _notes = [];

  List<Map<String, dynamic>> get _filteredNotes {
    final query = _searchCtrl.text.trim().toLowerCase();

    final filtered = _notes.where((note) {
      final title = (note['title'] ?? '').toString().toLowerCase();
      final category = (note['category'] ?? '').toString().toLowerCase();
      final description = (note['description'] ?? '').toString().toLowerCase();
      final status =
          _normalizedStatus((note['status'] ?? 'unpaid').toString()).toLowerCase();

      final matchesStatus =
          _statusFilter == 'all' ? true : status == _statusFilter;

      final matchesQuery = query.isEmpty ||
          title.contains(query) ||
          category.contains(query) ||
          description.contains(query);

      return matchesStatus && matchesQuery;
    }).toList();

    filtered.sort((a, b) {
      final aStatus = _normalizedStatus((a['status'] ?? 'unpaid').toString());
      final bStatus = _normalizedStatus((b['status'] ?? 'unpaid').toString());

      if (aStatus == 'unpaid' && bStatus != 'unpaid') return -1;
      if (aStatus != 'unpaid' && bStatus == 'unpaid') return 1;

      final aDate = _parseDate(a['date']);
      final bDate = _parseDate(b['date']);
      return bDate.compareTo(aDate);
    });

    return filtered;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoadOnce) {
      _didLoadOnce = true;
      _load();
    }
  }

  Future<void> _openCreate() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateExpenseNoteScreen(),
      ),
    );

    if (!mounted) return;
    await _load();
  }

  Future<void> _openEdit(Map<String, dynamic> note) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditExpenseNoteScreen(expenseNote: note),
      ),
    );

    if (!mounted) return;
    await _load();
  }

  Future<void> _load() async {
    final l10n = AppLocalizations.of(context)!;

    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      final data = await _repo.listExpenseNotes();
      final currency = await _settingsService.getCurrency();

      if (!mounted) return;

      setState(() {
        _notes = List<Map<String, dynamic>>.from(data);
        _currency = currency;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _notes = [];
        _loading = false;
      });
      AppAlerts.error(
        context,
        '${l10n.loadFailed}: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  int _toInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? fallback;
  }

  double _toDouble(dynamic value, [double fallback = 0.0]) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }

  String _normalizedStatus(String status) {
    final s = status.trim().toLowerCase();
    if (s == 'paid') return 'paid';
    if (s == 'cancelled' || s == 'canceled') return 'cancelled';
    return 'unpaid';
  }

  String _statusLabel(String status, AppLocalizations l10n) {
    final normalized = _normalizedStatus(status);
    if (normalized == 'paid') return l10n.statusPaid.toUpperCase();
    if (normalized == 'cancelled') return l10n.statusCancelled.toUpperCase();
    return l10n.statusUnpaid.toUpperCase();
  }

  Color _statusBg(String status, ColorScheme cs) {
    final normalized = _normalizedStatus(status);
    if (normalized == 'paid') return cs.primaryContainer;
    if (normalized == 'cancelled') return cs.errorContainer;
    return cs.tertiaryContainer;
  }

  Color _statusFg(String status, ColorScheme cs) {
    final normalized = _normalizedStatus(status);
    if (normalized == 'paid') return cs.onPrimaryContainer;
    if (normalized == 'cancelled') return cs.onErrorContainer;
    return cs.onTertiaryContainer;
  }

  Future<void> _deleteExpenseNote(int id) async {
    final l10n = AppLocalizations.of(context)!;

    try {
      await _repo.deleteExpenseNote(id);

      if (!mounted) return;

      setState(() {
        _notes.removeWhere((e) => _toInt(e['id']) == id);
      });
      AppAlerts.success(context, l10n.expenseNoteDeletedSuccess);
    } catch (e) {
      if (!mounted) return;
      AppAlerts.error(
        context,
        '${l10n.deleteFailed}: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  Future<void> _updateExpenseStatus(int id, String status) async {
    final l10n = AppLocalizations.of(context)!;

    if (_updatingStatus) return;

    setState(() {
      _updatingStatus = true;
    });

    try {
      await _repo.updateExpenseNoteStatus(id: id, status: status);

      if (!mounted) return;

      setState(() {
        final index = _notes.indexWhere((e) => _toInt(e['id']) == id);
        if (index != -1) {
          _notes[index]['status'] = status;
        }
      });
      AppAlerts.success(context, l10n.expenseStatusUpdated);
    } catch (e) {
      if (!mounted) return;
      AppAlerts.error(
        context,
        '${l10n.updateFailed}: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingStatus = false;
        });
      }
    }
  }

  Future<void> _showDeleteDialog(int id) async {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(l10n.confirmDeleteTitle),
          content: Text(l10n.confirmDeleteExpenseMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancelButton),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.deleteButton),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteExpenseNote(id);
    }
  }

  Future<void> _showStatusSheet(int noteId, String currentStatus) async {
    final l10n = AppLocalizations.of(context)!;
    final normalized = _normalizedStatus(currentStatus);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.changeStatus,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 14),
                _StatusActionTile(
                  icon: Icons.check_circle_outline,
                  title: l10n.markAsPaid,
                  selected: normalized == 'paid',
                  onTap: () async {
                    Navigator.pop(context);
                    await _updateExpenseStatus(noteId, 'paid');
                  },
                ),
                const SizedBox(height: 8),
                _StatusActionTile(
                  icon: Icons.schedule_outlined,
                  title: l10n.markAsUnpaid,
                  selected: normalized == 'unpaid',
                  onTap: () async {
                    Navigator.pop(context);
                    await _updateExpenseStatus(noteId, 'unpaid');
                  },
                ),
                const SizedBox(height: 8),
                _StatusActionTile(
                  icon: Icons.cancel_outlined,
                  title: l10n.markAsCancelled,
                  selected: normalized == 'cancelled',
                  onTap: () async {
                    Navigator.pop(context);
                    await _updateExpenseStatus(noteId, 'cancelled');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final filteredNotes = _filteredNotes;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.expenseNotesTitle),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: l10n.refresh,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: Text(l10n.createExpenseNoteTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: l10n.searchExpenseHint,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchCtrl.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close),
                            ),
                      filled: true,
                      fillColor: cs.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: cs.outlineVariant.withOpacity(0.35),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: cs.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: l10n.all,
                          selected: _statusFilter == 'all',
                          onTap: () => setState(() => _statusFilter = 'all'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: l10n.statusUnpaid,
                          selected: _statusFilter == 'unpaid',
                          onTap: () => setState(() => _statusFilter = 'unpaid'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: l10n.statusPaid,
                          selected: _statusFilter == 'paid',
                          onTap: () => setState(() => _statusFilter = 'paid'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: l10n.statusCancelled,
                          selected: _statusFilter == 'cancelled',
                          onTap: () => setState(() => _statusFilter = 'cancelled'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: _notes.isEmpty
                        ? _EmptyExpenseNotes(onCreate: _openCreate)
                        : filteredNotes.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  const SizedBox(height: 80),
                                  Center(
                                    child: Text(l10n.noExpenseNotesMatchSearch),
                                  ),
                                ],
                              )
                            : RefreshIndicator(
                                onRefresh: _load,
                                child: ListView.separated(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  itemCount: filteredNotes.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, i) {
                                    final note = filteredNotes[i];

                                    final noteId = _toInt(note['id']);
                                    final title = (note['title'] ?? '').toString();
                                    final category = (note['category'] ?? '').toString();
                                    final description =
                                        (note['description'] ?? '').toString();
                                    final status = _normalizedStatus(
                                      (note['status'] ?? 'unpaid').toString(),
                                    );
                                    final date = _parseDate(note['date']);
                                    final amountValue = _toDouble(note['amount']);

                                    final formattedAmount = CurrencyService.format(
                                      amountValue,
                                      _currency.isEmpty ? 'TND' : _currency,
                                    );

                                    return InkWell(
                                      borderRadius: BorderRadius.circular(22),
                                      onTap: () => _openEdit(note),
                                      onLongPress: () => _showStatusSheet(
                                        noteId,
                                        status,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: cs.surface,
                                          borderRadius: BorderRadius.circular(22),
                                          border: Border.all(
                                            color:
                                                cs.outlineVariant.withOpacity(0.28),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  theme.shadowColor.withOpacity(0.08),
                                              blurRadius: 14,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        title.isEmpty
                                                            ? l10n
                                                                .expenseNotePreviewTitleFallback
                                                            : title,
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow.ellipsis,
                                                        style: theme
                                                            .textTheme.titleMedium
                                                            ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w900,
                                                        ),
                                                      ),
                                                      if (category.isNotEmpty)
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.only(
                                                            top: 6,
                                                          ),
                                                          child: Text(
                                                            category,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow.ellipsis,
                                                            style: theme
                                                                .textTheme.bodyLarge
                                                                ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight.w800,
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    _StatusPill(
                                                      text: _statusLabel(
                                                        status,
                                                        l10n,
                                                      ),
                                                      bg: _statusBg(status, cs),
                                                      fg: _statusFg(status, cs),
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Text(
                                                      formattedAmount,
                                                      style: theme
                                                          .textTheme.titleMedium
                                                          ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w900,
                                                      ),
                                                    ),
                                                    Text(
                                                      _currency.isEmpty
                                                          ? 'TND'
                                                          : _currency,
                                                      style: theme
                                                          .textTheme.bodySmall
                                                          ?.copyWith(
                                                        color:
                                                            cs.onSurfaceVariant,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 14),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                _MetaChip(
                                                  text:
                                                      '${l10n.dateLabel}: ${date.toLocal().toString().split(' ')[0]}',
                                                ),
                                                if (category.isNotEmpty)
                                                  _MetaChip(
                                                    text:
                                                        '${l10n.categoryLabel}: $category',
                                                  ),
                                              ],
                                            ),
                                            if (description.isNotEmpty) ...[
                                              const SizedBox(height: 12),
                                              Container(
                                                width: double.infinity,
                                                padding:
                                                    const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: cs
                                                      .surfaceContainerHighest
                                                      .withOpacity(0.45),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                child: Text(
                                                  description,
                                                  maxLines: 3,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: theme
                                                      .textTheme.bodyMedium
                                                      ?.copyWith(
                                                    color: cs.onSurfaceVariant,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 12),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: OutlinedButton.icon(
                                                    onPressed: () => _openEdit(note),
                                                    icon: const Icon(
                                                      Icons.edit_outlined,
                                                    ),
                                                    label: Text(l10n.edit),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: FilledButton.icon(
                                                    onPressed: _updatingStatus
                                                        ? null
                                                        : () => _showStatusSheet(
                                                              noteId,
                                                              status,
                                                            ),
                                                    icon: const Icon(
                                                      Icons.autorenew_rounded,
                                                    ),
                                                    label:
                                                        Text(l10n.changeStatus),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                IconButton.filledTonal(
                                                  onPressed: () =>
                                                      _showDeleteDialog(noteId),
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                  ),
                                                  tooltip: l10n.deleteButton,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String text;

  const _MetaChip({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _StatusActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _StatusActionTile({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer.withOpacity(0.65) : cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? cs.primary.withOpacity(0.4)
                : cs.outlineVariant.withOpacity(0.25),
          ),
        ),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            if (selected) const Icon(Icons.check_circle_rounded),
          ],
        ),
      ),
    );
  }
}

class _EmptyExpenseNotes extends StatelessWidget {
  final Future<void> Function() onCreate;

  const _EmptyExpenseNotes({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
        Center(
          child: Text(
            l10n.noExpenseNotes,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            l10n.createYourFirstExpenseNoteToSeeItHere,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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
              label: Text(l10n.createExpenseNoteTitle),
            ),
          ),
        ),
      ],
    );
  }
}
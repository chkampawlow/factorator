import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_app/core/access_scope.dart';
import 'package:my_app/core/accounting_review.dart';
import 'package:my_app/core/api_exception.dart';
import 'package:my_app/core/document_center_models.dart';
import 'package:my_app/core/permission_service.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/l10n/mobile_labels.dart';
import 'package:my_app/screens/document_center_screen.dart';
import 'package:my_app/screens/expense_notes_screen.dart';
import 'package:my_app/screens/invoices_screen.dart';
import 'package:my_app/storage/accounting_review_repo.dart';
import 'package:my_app/widgets/app_alerts.dart';
import 'package:my_app/widgets/app_top_bar.dart';

enum _FinanceView { overview, receivables, payables, expenses, activity }

class AccountingReviewScreen extends StatefulWidget {
  const AccountingReviewScreen({
    super.key,
    required this.onToggleTheme,
    required this.onChangePrimaryColor,
    required this.onChangeLanguage,
    required this.currentPrimaryColor,
  });

  final VoidCallback onToggleTheme;
  final void Function(Color color) onChangePrimaryColor;
  final void Function(String code) onChangeLanguage;
  final Color currentPrimaryColor;

  @override
  State<AccountingReviewScreen> createState() => _AccountingReviewScreenState();
}

class _AccountingReviewScreenState extends State<AccountingReviewScreen> {
  final _repo = AccountingReviewRepo();
  final _search = TextEditingController();
  AccountingReviewSnapshot? _snapshot;
  _FinanceView _view = _FinanceView.overview;
  String? _error;
  bool _loading = true;

  PermissionService get _permissions => AccessScope.of(context).permissions;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final snapshot = await _repo.load();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      final message =
          error is ApiException && error.code == 'ENDPOINT_NOT_FOUND'
              ? AppLocalizations.of(context)!.accountingServerUpdateRequired
              : error.toString().replaceFirst('Exception: ', '');
      setState(() {
        _loading = false;
        _error = message;
      });
    }
  }

  Future<void> _openEntry(AccountingReviewEntry entry) async {
    final kind = switch (entry.entityType) {
      'INVOICE' => DocumentKind.invoice,
      'CREDIT_NOTE' => DocumentKind.creditNote,
      'SUPPLIER_INVOICE' => DocumentKind.supplierInvoice,
      'SUPPLIER_RECEPTION' => DocumentKind.supplierReception,
      'EXPENSE' => DocumentKind.expense,
      _ => null,
    };
    if (kind == null || entry.entityId <= 0) {
      AppAlerts.info(
        context,
        AppLocalizations.of(context)!.noMobileDocumentLinked,
      );
      return;
    }
    if (!canViewDocumentKind(_permissions, kind)) {
      AppAlerts.error(
        context,
        AppLocalizations.of(context)!.cannotViewDocument,
      );
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentDetailScreen(
          permissions: _permissions,
          document: MobileDocument(
            id: entry.entityId,
            kind: kind,
            number: entry.documentNumber,
            party: entry.party,
            status: entry.status,
            date: entry.date,
            dueDate: entry.dueDate,
            total: entry.amountTnd,
            currency: 'TND',
            raw: const {},
          ),
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _openInvoices() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => AccessScope(
          permissions: _permissions,
          child: InvoicesScreen(
            onToggleTheme: widget.onToggleTheme,
            onChangePrimaryColor: widget.onChangePrimaryColor,
            onChangeLanguage: widget.onChangeLanguage,
            currentPrimaryColor: widget.currentPrimaryColor,
            initialStatus: 'overdue',
          ),
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _openExpenses() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => AccessScope(
          permissions: _permissions,
          child: ExpenseNotesScreen(
            onToggleTheme: widget.onToggleTheme,
            onChangePrimaryColor: widget.onChangePrimaryColor,
            onChangeLanguage: widget.onChangeLanguage,
            currentPrimaryColor: widget.currentPrimaryColor,
          ),
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _openDocuments() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => AccessScope(
          permissions: _permissions,
          child: DocumentCenterScreen(
            onToggleTheme: widget.onToggleTheme,
            onChangePrimaryColor: widget.onChangePrimaryColor,
            onChangeLanguage: widget.onChangeLanguage,
            currentPrimaryColor: widget.currentPrimaryColor,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppTopBar(
        title: l10n.financeReview,
        actions: [
          IconButton(
            tooltip: l10n.refreshBalances,
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        onToggleTheme: widget.onToggleTheme,
        onChangePrimaryColor: widget.onChangePrimaryColor,
        onChangeLanguage: widget.onChangeLanguage,
        currentPrimaryColor: widget.currentPrimaryColor,
      ),
      body: _body(),
    );
  }

  Widget _body() {
    final l10n = AppLocalizations.of(context)!;
    if (_loading && _snapshot == null) {
      return const _FinanceLoadingState();
    }
    if (_error != null && _snapshot == null) {
      return RefreshIndicator(
        onRefresh: _load,
        child: _FinanceErrorState(
          message: _error!,
          retryLabel: l10n.retry,
          onRetry: _load,
        ),
      );
    }

    final snapshot = _snapshot!;
    return RefreshIndicator(
      onRefresh: _load,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
            children: [
              _ReviewHeader(snapshot: snapshot, refreshing: _loading),
              const SizedBox(height: 12),
              _SummaryGrid(summary: snapshot.summary),
              const SizedBox(height: 16),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _visibleViews(snapshot)
                      .map((view) => Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: _FinanceViewChip(
                              label: _financeViewLabel(view, l10n),
                              selected: _view == view,
                              onTap: () => setState(() => _view = view),
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: l10n.searchPartyDocument,
                  prefixIcon: const Icon(Icons.search_rounded, size: 21),
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _search.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
              const SizedBox(height: 14),
              if (_view == _FinanceView.overview) ...[
                _QuickLinks(
                  snapshot: snapshot,
                  onInvoices: _openInvoices,
                  onExpenses: _openExpenses,
                  onDocuments: _openDocuments,
                ),
                const SizedBox(height: 20),
                _SectionTitle(title: l10n.needsAttention),
                const SizedBox(height: 10),
              ],
              ..._entryWidgets(snapshot),
              if (_view == _FinanceView.overview) ...[
                const SizedBox(height: 18),
                _CapabilitiesCard(capabilities: snapshot.capabilities),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<_FinanceView> _visibleViews(AccountingReviewSnapshot snapshot) => [
        _FinanceView.overview,
        if (snapshot.capabilities.receivables) _FinanceView.receivables,
        if (snapshot.capabilities.payables) _FinanceView.payables,
        if (snapshot.capabilities.expenses) _FinanceView.expenses,
        _FinanceView.activity,
      ];

  List<Widget> _entryWidgets(AccountingReviewSnapshot snapshot) {
    final l10n = AppLocalizations.of(context)!;
    var entries = switch (_view) {
      _FinanceView.receivables => snapshot.receivables,
      _FinanceView.payables => snapshot.payables,
      _FinanceView.expenses => snapshot.expenses,
      _FinanceView.activity => snapshot.activity,
      _FinanceView.overview => [
          ...snapshot.receivables.where((entry) => entry.isOverdue),
          ...snapshot.payables
              .where((entry) => entry.isOverdue || entry.hasMatchingIssue),
          ...snapshot.expenses,
          ...snapshot.activity
              .where((entry) => entry.kind == AccountingEntryKind.withholding),
        ],
    };
    final query = _search.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      entries = entries
          .where((entry) =>
              '${entry.title} ${entry.party} ${entry.documentNumber} ${entry.status} ${entry.matchStatus}'
                  .toLowerCase()
                  .contains(query))
          .toList();
    }
    if (entries.isEmpty) {
      return [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Icon(Icons.task_alt_rounded,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(l10n.nothingReviewQueue),
                ),
              ],
            ),
          ),
        ),
      ];
    }
    return entries
        .map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AccountingEntryCard(
                entry: entry,
                onTap: () => _openEntry(entry),
              ),
            ))
        .toList();
  }
}

class _FinanceLoadingState extends StatelessWidget {
  const _FinanceLoadingState();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final placeholder = colors.surfaceContainerHighest.withValues(alpha: .65);

    Widget block(double height, {double? width, double radius = 16}) =>
        Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            color: placeholder,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: .55),
            ),
          ),
        );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          children: [
            block(76, radius: 19),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 760
                    ? 4
                    : constraints.maxWidth >= 340
                        ? 2
                        : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 4,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    mainAxisExtent: 126,
                  ),
                  itemBuilder: (_, __) => block(126, radius: 18),
                );
              },
            ),
            const SizedBox(height: 16),
            block(40, width: 300, radius: 20),
            const SizedBox(height: 12),
            block(50, radius: 15),
            const SizedBox(height: 20),
            block(76, radius: 17),
            const SizedBox(height: 10),
            block(76, radius: 17),
            const SizedBox(height: 20),
            const Center(
              child: SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinanceErrorState extends StatelessWidget {
  const _FinanceErrorState({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 72),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: .7),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: colors.error.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      Icons.cloud_off_outlined,
                      color: colors.error,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(retryLabel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FinanceViewChip extends StatelessWidget {
  const _FinanceViewChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? colors.primary.withValues(alpha: .16)
          : colors.surfaceContainerHigh,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected
              ? colors.primary.withValues(alpha: .5)
              : colors.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 4,
          height: 19,
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 9),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}

class _ReviewHeader extends StatelessWidget {
  const _ReviewHeader({required this.snapshot, required this.refreshing});

  final AccountingReviewSnapshot snapshot;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final generated = DateTime.tryParse(snapshot.generatedAt)?.toLocal();
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            colors.primary.withValues(alpha: .16),
            colors.surfaceContainerHigh.withValues(alpha: .95),
          ],
        ),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: colors.primary.withValues(alpha: .25)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              color: colors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.accountingAttentionQueue,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                Text(
                  generated == null
                      ? l10n.authoritativeBalances
                      : '${l10n.updated} ${DateFormat('dd MMM, HH:mm', l10n.localeName).format(generated)}',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (refreshing)
            SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.primary,
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});

  final AccountingReviewSummary summary;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final l10n = AppLocalizations.of(context)!;
          final colors = Theme.of(context).colorScheme;
          final width = constraints.maxWidth >= 760
              ? (constraints.maxWidth - 30) / 4
              : constraints.maxWidth >= 340
                  ? (constraints.maxWidth - 10) / 2
                  : constraints.maxWidth;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SummaryCard(
                width: width,
                label: l10n.receivables,
                value: _money(summary.receivableBalanceTnd),
                detail:
                    '${summary.overdueReceivableCount} ${l10n.overdue} · ${_money(summary.overdueReceivableTnd)}',
                icon: Icons.south_west_rounded,
                tone: summary.overdueReceivableCount > 0
                    ? colors.error
                    : colors.primary,
              ),
              _SummaryCard(
                width: width,
                label: l10n.payables,
                value: _money(summary.payableBalanceTnd),
                detail:
                    '${summary.overduePayableCount} ${l10n.overdue} · ${_money(summary.overduePayableTnd)}',
                icon: Icons.north_east_rounded,
                tone: colors.secondary,
              ),
              _SummaryCard(
                width: width,
                label: l10n.expenseReview,
                value: _money(summary.pendingExpenseTnd),
                detail: '${summary.pendingExpenseCount} ${l10n.pending}',
                icon: Icons.receipt_long_outlined,
                tone: colors.tertiary,
              ),
              _SummaryCard(
                width: width,
                label: l10n.matchingIssues,
                value: '${summary.matchingIssueCount}',
                detail:
                    '${summary.pendingWithholdingCount} ${l10n.certificatesPending}',
                icon: Icons.rule_folder_outlined,
                tone: summary.matchingIssueCount > 0 ||
                        summary.pendingWithholdingCount > 0
                    ? colors.error
                    : colors.primary,
              ),
            ],
          );
        },
      );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.width,
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.tone,
  });

  final double width;
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: '$label, $value, $detail',
      child: SizedBox(
        width: width,
        child: Container(
          constraints: const BoxConstraints(minHeight: 126),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: .55),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: .72),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: tone.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, size: 19, color: tone),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.2,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickLinks extends StatelessWidget {
  const _QuickLinks({
    required this.snapshot,
    required this.onInvoices,
    required this.onExpenses,
    required this.onDocuments,
  });

  final AccountingReviewSnapshot snapshot;
  final VoidCallback onInvoices;
  final VoidCallback onExpenses;
  final VoidCallback onDocuments;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .7)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (snapshot.capabilities.receivables)
            FilledButton.tonalIcon(
              onPressed: onInvoices,
              icon: const Icon(Icons.request_quote_outlined),
              label: Text('${l10n.overdue} ${l10n.kindInvoice}'),
            ),
          if (snapshot.capabilities.expenses)
            FilledButton.tonalIcon(
              onPressed: onExpenses,
              icon: const Icon(Icons.payments_outlined),
              label: Text(snapshot.capabilities.expenseApproval
                  ? l10n.approveExpenses
                  : l10n.viewExpenses),
            ),
          OutlinedButton.icon(
            onPressed: onDocuments,
            icon: const Icon(Icons.folder_copy_outlined),
            label: Text(l10n.allDocuments),
          ),
        ],
      ),
    );
  }
}

class _AccountingEntryCard extends StatelessWidget {
  const _AccountingEntryCard({required this.entry, required this.onTap});

  final AccountingReviewEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final warning = entry.isOverdue || entry.hasMatchingIssue;
    return Container(
      decoration: BoxDecoration(
        color: warning
            ? Color.alphaBlend(
                colors.error.withValues(alpha: .07),
                colors.surfaceContainerHigh,
              )
            : colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: (warning ? colors.error : colors.outlineVariant)
              .withValues(alpha: warning ? .24 : .68),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsetsDirectional.fromSTEB(12, 5, 10, 5),
        onTap: onTap,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: (warning ? colors.error : colors.primary)
                .withValues(alpha: .12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            _entryIcon(entry.kind),
            color: warning ? colors.error : colors.primary,
            size: 21,
          ),
        ),
        title: Text(
          _accountingEntryTitle(entry, l10n),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [
            if (entry.party.isNotEmpty) entry.party,
            if (entry.documentNumber.isNotEmpty) entry.documentNumber,
            if (entry.dueDate.isNotEmpty)
              '${l10n.due} ${_date(entry.dueDate, l10n)}',
            if (entry.date.isNotEmpty && entry.dueDate.isEmpty)
              _date(entry.date, l10n),
            if (entry.matchStatus.isNotEmpty)
              entry.matchStatus.replaceAll('_', ' '),
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 118),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _money(entry.amountTnd),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: (warning ? colors.error : colors.primary)
                      .withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  localizedWorkflowStatus(l10n, entry.status),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: warning ? colors.error : colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CapabilitiesCard extends StatelessWidget {
  const _CapabilitiesCard({required this.capabilities});

  final AccountingCapabilities capabilities;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final actions = [
      if (capabilities.customerPayments) l10n.customerPaymentLedger,
      if (capabilities.withholding) l10n.withholdingCertificates,
      if (capabilities.supplierPayments) l10n.supplierPaymentRecording,
      if (capabilities.supplierCredits) l10n.supplierCredits,
      if (capabilities.supplierReturns) l10n.supplierReturns,
      if (capabilities.reports) l10n.accountingReports,
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.yourFinanceAccess,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: actions
                  .map((action) => Chip(
                        avatar:
                            const Icon(Icons.check_circle_outline, size: 17),
                        label: Text(action),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.backendAmountsNotice,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

IconData _entryIcon(AccountingEntryKind kind) => switch (kind) {
      AccountingEntryKind.receivable => Icons.south_west_rounded,
      AccountingEntryKind.payable => Icons.north_east_rounded,
      AccountingEntryKind.expense => Icons.receipt_long_outlined,
      AccountingEntryKind.customerPayment => Icons.account_balance_wallet,
      AccountingEntryKind.supplierPayment => Icons.payments_outlined,
      AccountingEntryKind.customerCredit => Icons.assignment_return_outlined,
      AccountingEntryKind.supplierCredit => Icons.currency_exchange_outlined,
      AccountingEntryKind.supplierReturn => Icons.keyboard_return_rounded,
      AccountingEntryKind.withholding => Icons.workspace_premium_outlined,
      AccountingEntryKind.unknown => Icons.history_rounded,
    };

String _money(double value) =>
    '${NumberFormat('#,##0.000', 'en').format(value)} TND';

String _date(String value, AppLocalizations l10n) {
  final date = DateTime.tryParse(value);
  return date == null
      ? value
      : DateFormat('dd MMM yyyy', l10n.localeName).format(date);
}

String _financeViewLabel(_FinanceView view, AppLocalizations l10n) =>
    switch (view) {
      _FinanceView.overview => l10n.reviewTab,
      _FinanceView.receivables => l10n.receivables,
      _FinanceView.payables => l10n.payables,
      _FinanceView.expenses => l10n.expensesTab,
      _FinanceView.activity => l10n.activityTab,
    };

String _accountingEntryTitle(
  AccountingReviewEntry entry,
  AppLocalizations l10n,
) =>
    switch (entry.kind) {
      AccountingEntryKind.receivable => entry.isOverdue
          ? '${l10n.kindInvoice} · ${l10n.overdue}'
          : '${l10n.kindInvoice} · ${l10n.due}',
      AccountingEntryKind.payable => entry.hasMatchingIssue
          ? '${l10n.kindSupplierInvoice} · ${l10n.matchingIssues}'
          : entry.isOverdue
              ? '${l10n.kindSupplierInvoice} · ${l10n.overdue}'
              : '${l10n.kindSupplierInvoice} · ${l10n.due}',
      AccountingEntryKind.expense => entry.title,
      AccountingEntryKind.customerPayment => l10n.customerPaymentLedger,
      AccountingEntryKind.supplierPayment => l10n.supplierPaymentRecording,
      AccountingEntryKind.customerCredit => l10n.kindCreditNote,
      AccountingEntryKind.supplierCredit => l10n.supplierCredits,
      AccountingEntryKind.supplierReturn => l10n.supplierReturns,
      AccountingEntryKind.withholding => l10n.withholdingCertificates,
      AccountingEntryKind.unknown => l10n.activityTab,
    };

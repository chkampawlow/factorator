enum AccountingEntryKind {
  receivable,
  payable,
  expense,
  customerPayment,
  supplierPayment,
  customerCredit,
  supplierCredit,
  supplierReturn,
  withholding,
  unknown,
}

extension AccountingEntryKindDetails on AccountingEntryKind {
  String get label => switch (this) {
        AccountingEntryKind.receivable => 'Receivable',
        AccountingEntryKind.payable => 'Payable',
        AccountingEntryKind.expense => 'Expense',
        AccountingEntryKind.customerPayment => 'Customer payment',
        AccountingEntryKind.supplierPayment => 'Supplier payment',
        AccountingEntryKind.customerCredit => 'Customer credit',
        AccountingEntryKind.supplierCredit => 'Supplier credit',
        AccountingEntryKind.supplierReturn => 'Supplier return',
        AccountingEntryKind.withholding => 'Withholding',
        AccountingEntryKind.unknown => 'Activity',
      };
}

class AccountingReviewEntry {
  const AccountingReviewEntry({
    required this.kind,
    required this.id,
    required this.title,
    required this.party,
    required this.documentNumber,
    required this.date,
    required this.dueDate,
    required this.status,
    required this.amountTnd,
    required this.entityType,
    required this.entityId,
    required this.matchStatus,
  });

  final AccountingEntryKind kind;
  final int id;
  final String title;
  final String party;
  final String documentNumber;
  final String date;
  final String dueDate;
  final String status;
  final double amountTnd;
  final String entityType;
  final int entityId;
  final String matchStatus;

  bool get isOverdue => status.toUpperCase() == 'OVERDUE';
  bool get hasMatchingIssue =>
      matchStatus.isNotEmpty && matchStatus.toUpperCase() != 'MATCHED';

  factory AccountingReviewEntry.fromJson(Map<String, dynamic> json) =>
      AccountingReviewEntry(
        kind: _entryKind('${json['kind'] ?? ''}'),
        id: _integer(json['id']),
        title: '${json['title'] ?? ''}',
        party: '${json['party'] ?? ''}',
        documentNumber: '${json['documentNumber'] ?? ''}',
        date: '${json['date'] ?? ''}',
        dueDate: '${json['dueDate'] ?? ''}',
        status: '${json['status'] ?? ''}'.toUpperCase(),
        amountTnd: _number(json['amountTnd']),
        entityType: '${json['entityType'] ?? ''}'.toUpperCase(),
        entityId: _integer(json['entityId']),
        matchStatus: '${json['matchStatus'] ?? ''}'.toUpperCase(),
      );
}

class AccountingReviewSummary {
  const AccountingReviewSummary({
    required this.receivableCount,
    required this.receivableBalanceTnd,
    required this.overdueReceivableCount,
    required this.overdueReceivableTnd,
    required this.payableCount,
    required this.payableBalanceTnd,
    required this.overduePayableCount,
    required this.overduePayableTnd,
    required this.matchingIssueCount,
    required this.pendingExpenseCount,
    required this.pendingExpenseTnd,
    required this.pendingWithholdingCount,
    required this.pendingWithholdingTnd,
    required this.customerPaymentCount30d,
    required this.customerPaymentTnd30d,
    required this.supplierPaymentCount30d,
    required this.supplierPaymentTnd30d,
    required this.customerCreditCount30d,
    required this.supplierCreditCount30d,
    required this.supplierReturnCount30d,
  });

  final int receivableCount;
  final double receivableBalanceTnd;
  final int overdueReceivableCount;
  final double overdueReceivableTnd;
  final int payableCount;
  final double payableBalanceTnd;
  final int overduePayableCount;
  final double overduePayableTnd;
  final int matchingIssueCount;
  final int pendingExpenseCount;
  final double pendingExpenseTnd;
  final int pendingWithholdingCount;
  final double pendingWithholdingTnd;
  final int customerPaymentCount30d;
  final double customerPaymentTnd30d;
  final int supplierPaymentCount30d;
  final double supplierPaymentTnd30d;
  final int customerCreditCount30d;
  final int supplierCreditCount30d;
  final int supplierReturnCount30d;

  factory AccountingReviewSummary.fromJson(Map<String, dynamic> json) =>
      AccountingReviewSummary(
        receivableCount: _integer(json['receivableCount']),
        receivableBalanceTnd: _number(json['receivableBalanceTnd']),
        overdueReceivableCount: _integer(json['overdueReceivableCount']),
        overdueReceivableTnd: _number(json['overdueReceivableTnd']),
        payableCount: _integer(json['payableCount']),
        payableBalanceTnd: _number(json['payableBalanceTnd']),
        overduePayableCount: _integer(json['overduePayableCount']),
        overduePayableTnd: _number(json['overduePayableTnd']),
        matchingIssueCount: _integer(json['matchingIssueCount']),
        pendingExpenseCount: _integer(json['pendingExpenseCount']),
        pendingExpenseTnd: _number(json['pendingExpenseTnd']),
        pendingWithholdingCount: _integer(json['pendingWithholdingCount']),
        pendingWithholdingTnd: _number(json['pendingWithholdingTnd']),
        customerPaymentCount30d: _integer(json['customerPaymentCount30d']),
        customerPaymentTnd30d: _number(json['customerPaymentTnd30d']),
        supplierPaymentCount30d: _integer(json['supplierPaymentCount30d']),
        supplierPaymentTnd30d: _number(json['supplierPaymentTnd30d']),
        customerCreditCount30d: _integer(json['customerCreditCount30d']),
        supplierCreditCount30d: _integer(json['supplierCreditCount30d']),
        supplierReturnCount30d: _integer(json['supplierReturnCount30d']),
      );
}

class AccountingCapabilities {
  const AccountingCapabilities({
    required this.receivables,
    required this.customerPayments,
    required this.withholding,
    required this.payables,
    required this.expenses,
    required this.expenseApproval,
    required this.supplierPayments,
    required this.supplierCredits,
    required this.supplierReturns,
    required this.reports,
  });

  final bool receivables;
  final bool customerPayments;
  final bool withholding;
  final bool payables;
  final bool expenses;
  final bool expenseApproval;
  final bool supplierPayments;
  final bool supplierCredits;
  final bool supplierReturns;
  final bool reports;

  factory AccountingCapabilities.fromJson(Map<String, dynamic> json) =>
      AccountingCapabilities(
        receivables: _truthy(json['receivables']),
        customerPayments: _truthy(json['customerPayments']),
        withholding: _truthy(json['withholding']),
        payables: _truthy(json['payables']),
        expenses: _truthy(json['expenses']),
        expenseApproval: _truthy(json['expenseApproval']),
        supplierPayments: _truthy(json['supplierPayments']),
        supplierCredits: _truthy(json['supplierCredits']),
        supplierReturns: _truthy(json['supplierReturns']),
        reports: _truthy(json['reports']),
      );
}

class AccountingReviewSnapshot {
  const AccountingReviewSnapshot({
    required this.generatedAt,
    required this.currency,
    required this.capabilities,
    required this.summary,
    required this.receivables,
    required this.payables,
    required this.expenses,
    required this.activity,
  });

  final String generatedAt;
  final String currency;
  final AccountingCapabilities capabilities;
  final AccountingReviewSummary summary;
  final List<AccountingReviewEntry> receivables;
  final List<AccountingReviewEntry> payables;
  final List<AccountingReviewEntry> expenses;
  final List<AccountingReviewEntry> activity;

  factory AccountingReviewSnapshot.fromJson(Map<String, dynamic> json) =>
      AccountingReviewSnapshot(
        generatedAt: '${json['generatedAt'] ?? ''}',
        currency: '${json['currency'] ?? 'TND'}',
        capabilities: AccountingCapabilities.fromJson(
          _map(json['capabilities']),
        ),
        summary: AccountingReviewSummary.fromJson(_map(json['summary'])),
        receivables: _entries(json['receivables']),
        payables: _entries(json['payables']),
        expenses: _entries(json['expenses']),
        activity: _entries(json['activity']),
      );
}

AccountingEntryKind _entryKind(String value) => switch (value.toUpperCase()) {
      'RECEIVABLE' => AccountingEntryKind.receivable,
      'PAYABLE' => AccountingEntryKind.payable,
      'EXPENSE' => AccountingEntryKind.expense,
      'CUSTOMER_PAYMENT' => AccountingEntryKind.customerPayment,
      'SUPPLIER_PAYMENT' => AccountingEntryKind.supplierPayment,
      'CUSTOMER_CREDIT' => AccountingEntryKind.customerCredit,
      'SUPPLIER_CREDIT' => AccountingEntryKind.supplierCredit,
      'SUPPLIER_RETURN' => AccountingEntryKind.supplierReturn,
      'WITHHOLDING' => AccountingEntryKind.withholding,
      _ => AccountingEntryKind.unknown,
    };

List<AccountingReviewEntry> _entries(dynamic value) => value is List
    ? value
        .whereType<Map>()
        .map((row) => AccountingReviewEntry.fromJson(
              Map<String, dynamic>.from(row),
            ))
        .where((entry) => entry.id > 0)
        .toList()
    : const [];

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

int _integer(dynamic value) =>
    value is int ? value : int.tryParse('$value') ?? 0;

double _number(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

bool _truthy(dynamic value) =>
    value == true || value == 1 || '$value'.toLowerCase() == 'true';

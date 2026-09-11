import 'user_session.dart';

enum AppRole {
  administrator,
  commercial,
  stock,
  logistics,
  accounting,
  unknown
}

enum AppFeature {
  dashboard,
  clients,
  products,
  inventory,
  invoices,
  finance,
  expenses,
  deliveries,
  receptions,
  documents,
  scan,
  assistant,
}

enum AppPermission {
  clientsView(AppFeature.clients, 'view'),
  clientsCreate(AppFeature.clients, 'create'),
  clientsUpdate(AppFeature.clients, 'update'),
  clientsDelete(AppFeature.clients, 'delete'),
  productsView(AppFeature.products, 'view'),
  productsCreate(AppFeature.products, 'create'),
  productsUpdate(AppFeature.products, 'update'),
  productsDelete(AppFeature.products, 'delete'),
  stockView(AppFeature.inventory, 'view', resource: 'stock'),
  stockAdjust(AppFeature.inventory, 'adjust', resource: 'stock'),
  supplierReceptionsView(
    AppFeature.receptions,
    'view',
    resource: 'supplierReceptions',
  ),
  supplierReceptionsCreate(
    AppFeature.receptions,
    'create',
    resource: 'supplierReceptions',
  ),
  supplierReceptionsUpdate(
    AppFeature.receptions,
    'update',
    resource: 'supplierReceptions',
  ),
  supplierReceptionsConfirm(
    AppFeature.receptions,
    'confirm',
    resource: 'supplierReceptions',
  ),
  invoicesView(AppFeature.invoices, 'view'),
  invoicesCreate(AppFeature.invoices, 'create'),
  invoicesUpdate(AppFeature.invoices, 'update'),
  invoicesDelete(AppFeature.invoices, 'delete'),
  devisView(AppFeature.documents, 'view', resource: 'devis'),
  devisUpdate(AppFeature.documents, 'update', resource: 'devis'),
  devisDelete(AppFeature.documents, 'delete', resource: 'devis'),
  creditNotesView(AppFeature.documents, 'view', resource: 'avoirs'),
  creditNotesUpdate(AppFeature.documents, 'update', resource: 'avoirs'),
  creditNotesDelete(AppFeature.documents, 'delete', resource: 'avoirs'),
  supplierInvoicesView(
    AppFeature.finance,
    'view',
    resource: 'supplierInvoices',
  ),
  supplierPaymentsRecord(
    AppFeature.finance,
    'record',
    resource: 'supplierPayments',
  ),
  paymentsView(AppFeature.finance, 'view', resource: 'payments'),
  paymentsRecord(AppFeature.finance, 'record', resource: 'payments'),
  paymentsVoid(AppFeature.finance, 'void', resource: 'payments'),
  withholdingView(AppFeature.finance, 'view', resource: 'withholding'),
  withholdingRecord(AppFeature.finance, 'record', resource: 'withholding'),
  withholdingUpdate(AppFeature.finance, 'update', resource: 'withholding'),
  reportsView(AppFeature.finance, 'view', resource: 'reports'),
  expensesView(AppFeature.expenses, 'view'),
  expensesCreate(AppFeature.expenses, 'create'),
  expensesUpdate(AppFeature.expenses, 'update'),
  expensesDelete(AppFeature.expenses, 'delete'),
  expensesApprove(AppFeature.finance, 'approve', resource: 'expenses'),
  extractorUse(AppFeature.scan, 'use', resource: 'extractor'),
  assistantUse(AppFeature.assistant, 'use');

  const AppPermission(this.feature, this.action, {this.resource});

  final AppFeature feature;
  final String action;
  final String? resource;

  Iterable<String> get backendNames sync* {
    final name = resource ?? feature.name;
    yield '$name.$action';
    yield '${name}_$action';
    yield '${action}_$name';
    if (action == 'view') {
      yield '$name.read';
      yield '${name}_read';
      yield 'read_$name';
    }
    if (action == 'update') {
      yield '$name.edit';
      yield '${name}_edit';
      yield 'edit_$name';
    }
  }
}

class PermissionService {
  final UserSession session;

  const PermissionService(this.session);

  AppRole get role => parseRole(session.role);
  bool get isActive => _normalize(session.membershipStatus) == 'active';
  bool get hasWildcard => session.permissions.map(_normalize).contains('*');

  bool allows(String permission) {
    if (!isActive) return false;
    final permissions = session.permissions.map(_normalize).toSet();
    return permissions.contains('*') ||
        permissions.contains(_normalize(permission));
  }

  bool allowsAny(Iterable<String> permissions) => permissions.any(allows);

  bool can(AppPermission permission) =>
      isActive && (hasWildcard || allowsAny(permission.backendNames));

  bool canViewFeature(AppFeature feature) {
    if (!isActive) return false;
    if (feature == AppFeature.scan && can(AppPermission.extractorUse)) {
      return true;
    }
    if (hasWildcard || _hasExplicitFeatureAccess(feature)) return true;
    return _roleFeatures[role]?.contains(feature) ?? false;
  }

  bool canView(String feature) {
    for (final candidate in AppFeature.values) {
      if (candidate.name == _normalize(feature)) {
        return canViewFeature(candidate);
      }
    }
    return false;
  }

  bool _hasExplicitFeatureAccess(AppFeature feature) {
    final resources = switch (feature) {
      AppFeature.receptions => const ['receptions', 'supplierReceptions'],
      AppFeature.documents => const [
          'documents',
          'invoices',
          'devis',
          'avoirs',
          'orders',
          'deliveries',
          'supplierOrders',
          'supplierReceptions',
          'supplierInvoices',
          'expenses',
        ],
      AppFeature.finance => const [
          'reports',
          'payments',
          'withholding',
          'supplierInvoices',
          'supplierPayments',
          'expenses',
        ],
      AppFeature.scan => const ['scan', 'extractor'],
      _ => [feature.name],
    };
    return resources.any(
      (resource) => allowsAny([
        '$resource.view',
        '${resource}_view',
        'view_$resource',
        '$resource.read',
        '${resource}_read',
        'read_$resource',
      ]),
    );
  }

  static AppRole parseRole(String value) {
    switch (_normalize(value)) {
      case 'administrator':
      case 'admin':
        return AppRole.administrator;
      case 'commercial':
      case 'sales':
        return AppRole.commercial;
      case 'stock':
      case 'inventory':
      case 'warehouse':
        return AppRole.stock;
      case 'logistics':
      case 'logistic':
        return AppRole.logistics;
      case 'accounting':
      case 'accountant':
      case 'finance':
        return AppRole.accounting;
      default:
        return AppRole.unknown;
    }
  }

  static const Map<AppRole, Set<AppFeature>> _roleFeatures = {
    AppRole.administrator: {
      AppFeature.dashboard,
      AppFeature.clients,
      AppFeature.products,
      AppFeature.inventory,
      AppFeature.invoices,
      AppFeature.finance,
      AppFeature.expenses,
      AppFeature.deliveries,
      AppFeature.receptions,
      AppFeature.documents,
      AppFeature.scan,
      AppFeature.assistant,
    },
    AppRole.commercial: {
      AppFeature.dashboard,
      AppFeature.clients,
      AppFeature.products,
      AppFeature.invoices,
      AppFeature.deliveries,
      AppFeature.documents,
      AppFeature.scan,
      AppFeature.assistant,
    },
    AppRole.stock: {
      AppFeature.dashboard,
      AppFeature.products,
      AppFeature.inventory,
      AppFeature.deliveries,
      AppFeature.receptions,
      AppFeature.assistant,
    },
    AppRole.logistics: {
      AppFeature.dashboard,
      AppFeature.deliveries,
      AppFeature.receptions,
      AppFeature.scan,
      AppFeature.assistant,
    },
    AppRole.accounting: {
      AppFeature.dashboard,
      AppFeature.invoices,
      AppFeature.finance,
      AppFeature.expenses,
      AppFeature.receptions,
      AppFeature.documents,
      AppFeature.assistant,
    },
    AppRole.unknown: {},
  };

  static String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
}

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/auth_cookie_parser.dart';
import 'package:my_app/core/permission_service.dart';
import 'package:my_app/core/user_session.dart';

void main() {
  group('AuthCookieParser', () {
    test('extracts production access and refresh cookies', () {
      final tokens = AuthCookieParser.parse(
        'ef_access=access.jwt; Path=/; HttpOnly, '
        'ef_refresh=refresh.jwt; Path=/; HttpOnly',
      );

      expect(tokens['access_token'], 'access.jwt');
      expect(tokens['refresh_token'], 'refresh.jwt');
    });

    test('ignores unrelated and cleared cookies', () {
      final tokens = AuthCookieParser.parse(
        'session=abc; Path=/, ef_access=; Max-Age=0',
      );

      expect(tokens, isEmpty);
    });

    test('handles an Expires attribute containing a comma', () {
      final tokens = AuthCookieParser.parse(
        'ef_access=access.jwt; Expires=Thu, 03 Sep 2026 18:00:00 GMT; '
        'Path=/, ef_refresh=refresh.jwt; Path=/',
      );

      expect(tokens, {
        'access_token': 'access.jwt',
        'refresh_token': 'refresh.jwt',
      });
    });
  });

  group('UserSession', () {
    test('parses tenant, company, membership, role, and permissions', () {
      final session = UserSession.fromAuthResponse({
        'user': {
          'id': 32,
          'tenant_id': 32,
          'company_id': 32,
          'role': 'COMMERCIAL',
        },
        'membership': {
          'id': 2,
          'tenant_id': 32,
          'company_id': 32,
          'role': 'ADMINISTRATOR',
          'status': 'ACTIVE',
        },
        'company': {'id': 32, 'organization_name': 'El Fatoura'},
        'permissions': ['clients.view', 'Invoices-Read'],
      });

      expect(session.userId, 32);
      expect(session.tenantId, 32);
      expect(session.companyId, 32);
      expect(session.membershipId, 2);
      expect(session.role, 'ADMINISTRATOR');
      expect(session.permissions, {'clients.view', 'invoices-read'});
    });

    test('round trips through JSON without losing context', () {
      final original = _session(role: 'STOCK', permissions: {'products.view'});
      final restored = UserSession.fromJson(original.toJson());

      expect(restored.userId, original.userId);
      expect(restored.tenantId, original.tenantId);
      expect(restored.companyId, original.companyId);
      expect(restored.role, original.role);
      expect(restored.permissions, original.permissions);
    });
  });

  group('PermissionService', () {
    test('wildcard grants all mobile features to an active member', () {
      final permissions = PermissionService(
        _session(role: 'ADMINISTRATOR', permissions: {'*'}),
      );

      expect(permissions.canView('clients'), isTrue);
      expect(permissions.canView('expenses'), isTrue);
    });

    test('commercial role receives only its safe default features', () {
      final permissions = PermissionService(
        _session(role: 'COMMERCIAL', permissions: {}),
      );

      expect(permissions.canView('clients'), isTrue);
      expect(permissions.canView('products'), isTrue);
      expect(permissions.canView('expenses'), isFalse);
    });

    test('explicit permission supports normalized backend names', () {
      final permissions = PermissionService(
        _session(role: 'UNKNOWN', permissions: {'expenses-view'}),
      );

      expect(permissions.canView('expenses'), isTrue);
    });

    test('extractor use permission exposes capture navigation', () {
      final permissions = PermissionService(
        _session(role: 'UNKNOWN', permissions: {'extractor.use'}),
      );

      expect(permissions.can(AppPermission.extractorUse), isTrue);
      expect(permissions.canViewFeature(AppFeature.scan), isTrue);
      expect(permissions.can(AppPermission.expensesCreate), isFalse);
    });

    test('inactive membership denies all features including wildcard', () {
      final permissions = PermissionService(
        _session(
          role: 'ADMINISTRATOR',
          permissions: {'*'},
          membershipStatus: 'SUSPENDED',
        ),
      );

      expect(permissions.canView('dashboard'), isFalse);
    });

    test('role aliases map to canonical roles', () {
      expect(PermissionService.parseRole('ADMIN'), AppRole.administrator);
      expect(PermissionService.parseRole('sales'), AppRole.commercial);
      expect(PermissionService.parseRole('warehouse'), AppRole.stock);
      expect(PermissionService.parseRole('finance'), AppRole.accounting);
      expect(PermissionService.parseRole('logistic'), AppRole.logistics);
    });

    test('role visibility does not grant mutation permissions', () {
      final permissions = PermissionService(
        _session(role: 'COMMERCIAL', permissions: {}),
      );

      expect(permissions.canViewFeature(AppFeature.clients), isTrue);
      expect(permissions.can(AppPermission.clientsCreate), isFalse);
      expect(permissions.can(AppPermission.clientsDelete), isFalse);
    });

    test('accepts common backend action permission formats', () {
      final permissions = PermissionService(
        _session(
          role: 'COMMERCIAL',
          permissions: {'clients_create', 'edit-products', 'delete_invoices'},
        ),
      );

      expect(permissions.can(AppPermission.clientsCreate), isTrue);
      expect(permissions.can(AppPermission.productsUpdate), isTrue);
      expect(permissions.can(AppPermission.invoicesDelete), isTrue);
      expect(permissions.can(AppPermission.expensesDelete), isFalse);
    });

    test('stock history and stock adjustment use distinct permissions', () {
      final permissions = PermissionService(
        _session(role: 'STOCK', permissions: {'stock.view'}),
      );

      expect(permissions.can(AppPermission.stockView), isTrue);
      expect(permissions.can(AppPermission.stockAdjust), isFalse);
    });

    test('supplier reception actions use backend capability names', () {
      final permissions = PermissionService(
        _session(
          role: 'STOCK',
          permissions: {
            'supplierReceptions.view',
            'supplierReceptions.confirm',
          },
        ),
      );

      expect(
        permissions.can(AppPermission.supplierReceptionsView),
        isTrue,
      );
      expect(
        permissions.can(AppPermission.supplierReceptionsConfirm),
        isTrue,
      );
      expect(
        permissions.can(AppPermission.supplierReceptionsUpdate),
        isFalse,
      );
    });

    test('supplier reception view permission exposes reception navigation', () {
      final permissions = PermissionService(
        _session(
          role: 'UNKNOWN',
          permissions: {'supplierReceptions.view'},
        ),
      );

      expect(permissions.canViewFeature(AppFeature.receptions), isTrue);
    });

    test('each operational role receives its intended navigation baseline', () {
      final commercial =
          PermissionService(_session(role: 'COMMERCIAL', permissions: {}));
      final stock = PermissionService(_session(role: 'STOCK', permissions: {}));
      final logistics =
          PermissionService(_session(role: 'LOGISTICS', permissions: {}));
      final accounting =
          PermissionService(_session(role: 'ACCOUNTING', permissions: {}));

      expect(commercial.canViewFeature(AppFeature.clients), isTrue);
      expect(commercial.canViewFeature(AppFeature.invoices), isTrue);
      expect(commercial.canViewFeature(AppFeature.deliveries), isTrue);
      expect(commercial.canViewFeature(AppFeature.scan), isTrue);
      expect(commercial.canViewFeature(AppFeature.products), isTrue);
      expect(stock.canViewFeature(AppFeature.inventory), isTrue);
      expect(stock.canViewFeature(AppFeature.deliveries), isTrue);
      expect(stock.canViewFeature(AppFeature.receptions), isTrue);
      expect(stock.canViewFeature(AppFeature.scan), isFalse);
      expect(stock.canViewFeature(AppFeature.clients), isFalse);
      expect(logistics.canViewFeature(AppFeature.deliveries), isTrue);
      expect(logistics.canViewFeature(AppFeature.expenses), isFalse);
      expect(accounting.canViewFeature(AppFeature.expenses), isTrue);
      expect(accounting.canViewFeature(AppFeature.finance), isTrue);
      expect(accounting.canViewFeature(AppFeature.invoices), isTrue);
      expect(accounting.canViewFeature(AppFeature.products), isFalse);
    });

    test('finance actions use granular backend permissions', () {
      final permissions = PermissionService(
        _session(
          role: 'UNKNOWN',
          permissions: {
            'supplierInvoices.view',
            'supplierPayments.record',
            'expenses.approve',
          },
        ),
      );

      expect(permissions.canViewFeature(AppFeature.finance), isTrue);
      expect(permissions.can(AppPermission.supplierInvoicesView), isTrue);
      expect(permissions.can(AppPermission.supplierPaymentsRecord), isTrue);
      expect(permissions.can(AppPermission.expensesApprove), isTrue);
      expect(permissions.can(AppPermission.paymentsVoid), isFalse);
    });
  });
}

UserSession _session({
  required String role,
  required Set<String> permissions,
  String membershipStatus = 'ACTIVE',
}) =>
    UserSession(
      userId: 7,
      tenantId: 11,
      companyId: 13,
      membershipId: 17,
      membershipStatus: membershipStatus,
      role: role,
      permissions: permissions,
      user: const {'id': 7},
      company: const {'id': 13},
    );

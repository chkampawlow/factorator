<?php

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/company_context.php';

function availableUserRoles(): array
{
    return ['ADMINISTRATOR', 'COMMERCIAL', 'STOCK', 'ACCOUNTING'];
}

function rolePermissions(): array
{
    return [
        'ADMINISTRATOR' => ['*'],
        'COMMERCIAL' => [
            'dashboard.view',
            'assistant.use',
            'extractor.use',
            'profile.manage',
            'clients.view',
            'clients.create',
            'clients.edit',
            'clients.delete',
            'services.view',
            'services.create',
            'services.edit',
            'services.delete',
            'devis.manage',
            'orders.view',
            'orders.create',
            'orders.edit',
            'orders.delete',
            'orders.confirm',
            'orders.cancel',
            'orders.send',
            'deliveries.view',
            'deliveries.create',
            'deliveries.edit',
            'deliveries.delete',
            'deliveries.confirm',
            'deliveries.cancel',
            'deliveries.deliver',
            'deliveries.send',
            'invoices.manage',
            // Action-level sales document permissions. The broad *.manage
            // permissions remain temporarily for endpoints that have not yet
            // been migrated; converted endpoints must use these capabilities.
            'invoices.view',
            'invoices.create',
            'invoices.edit',
            'invoices.delete',
            'devis.view',
            'devis.create',
            'devis.edit',
            'devis.delete',
            'devis.validate',
            'devis.send',
            'avoirs.view',
        ],
        'STOCK' => [
            'dashboard.view',
            'assistant.use',
            'profile.manage',
            'suppliers.view',
            'suppliers.create',
            'suppliers.edit',
            'suppliers.delete',
            'supplierOrders.view',
            'supplierOrders.create',
            'supplierOrders.edit',
            'supplierOrders.delete',
            'supplierOrders.send',
            'supplierReceptions.view',
            'supplierReceptions.create',
            'supplierReceptions.edit',
            'supplierReceptions.delete',
            'supplierReceptions.confirm',
            'supplierReturns.confirm',
            'products.view',
            'products.create',
            'products.edit',
            'products.delete',
            'stock.view',
            'stock.adjust',
            'orders.view',
            'deliveries.view',
            'deliveries.create',
            'deliveries.edit',
            'deliveries.delete',
            'deliveries.confirm',
            'deliveries.cancel',
            'deliveries.deliver',
            'deliveries.send',
        ],
        'ACCOUNTING' => [
            'dashboard.view',
            'assistant.use',
            'extractor.use',
            'profile.manage',
            'suppliers.view',
            'suppliers.create',
            'suppliers.edit',
            'suppliers.delete',
            'supplierOrders.view',
            'supplierReceptions.view',
            'supplierReceptions.create',
            'supplierReceptions.edit',
            'supplierReceptions.delete',
            'supplierReceptions.confirm',
            'supplierInvoices.view',
            'supplierInvoices.create',
            'supplierInvoices.validate',
            'supplierInvoices.credit',
            'supplierPayments.record',
            'supplierReturns.confirm',
            'invoices.manage',
            'avoirs.manage',
            'expenses.view',
            'expenses.create',
            'expenses.edit',
            'expenses.delete',
            'expenses.approve',
            'invoices.backdate',
            'accounting.periods.manage',
            'payments.manage',
            'withholding.manage',
            'reports.view',
            'invoices.view',
            'invoices.create',
            'invoices.edit',
            'invoices.delete',
            'invoices.validate',
            'invoices.send',
            'invoices.credit',
            'avoirs.view',
            'avoirs.create',
            'avoirs.edit',
            'avoirs.delete',
            'avoirs.validate',
            'avoirs.send',
            'payments.view',
            'payments.record',
            'payments.void',
            'withholding.view',
            'withholding.record',
            'withholding.edit',
        ],
        'UNAUTHORIZED' => [],
    ];
}

function normalizeUserRole($value): string
{
    $role = strtoupper(trim((string)$value));
    return in_array($role, availableUserRoles(), true) ? $role : 'UNAUTHORIZED';
}

function ensureUserRoleColumn(mysqli $conn): void
{
    static $ensured = false;

    if ($ensured) {
        return;
    }

    $conn->query("SELECT role FROM users LIMIT 0");

    $ensured = true;
}

function currentUserRole(mysqli $conn, int $userId): string
{
    $principal = activeAuthPrincipal();
    if ($principal !== null) {
        $actorId = authActorId($principal);
        $tenantId = authTenantId($principal);
        if ($userId === $actorId || $userId === $tenantId) {
            return normalizeUserRole($principal->role ?? null);
        }
    }

    $membership = companyMembershipForUser($conn, $userId);
    if ($membership !== null) {
        return normalizeUserRole($membership['role'] ?? null);
    }

    // Temporary compatibility for migration/diagnostic contexts that create a
    // user before its owner membership. Normal authenticated requests always
    // use the active company membership above.
    ensureUserRoleColumn($conn);

    $stmt = $conn->prepare('SELECT role FROM users WHERE id = ? LIMIT 1');
    if (!$stmt) {
        throw new Exception('Unable to verify user role.');
    }

    $stmt->bind_param('i', $userId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$row) {
        throw new Exception('User not found.');
    }

    return normalizeUserRole($row['role'] ?? null);
}

function permissionsForRole($role): array
{
    $normalized = normalizeUserRole($role);
    return rolePermissions()[$normalized] ?? [];
}

function permissionsForMembership(array $membership): array
{
    $permissions = permissionsForRole($membership['role'] ?? null);
    if ((int)($membership['is_owner'] ?? 0) === 1
        && !in_array('*', $permissions, true)
        && !in_array('users.manage', $permissions, true)) {
        $permissions[] = 'users.manage';
    }
    return $permissions;
}

function userHasPermission(mysqli $conn, int $userId, string $permission): bool
{
    $role = currentUserRole($conn, $userId);
    $permissions = rolePermissions()[$role] ?? [];

    return in_array('*', $permissions, true) || in_array($permission, $permissions, true);
}

function requirePermission(mysqli $conn, int $userId, string $permission): void
{
    if (!userHasPermission($conn, $userId, $permission)) {
        jsonResponse([
            'success' => false,
            'message' => 'You are not allowed to perform this action.',
            'code' => 'FORBIDDEN',
        ], 403);
    }
}

function requireAnyPermission(mysqli $conn, int $userId, array $permissions): void
{
    foreach ($permissions as $permission) {
        if (userHasPermission($conn, $userId, (string) $permission)) return;
    }
    jsonResponse([
        'success' => false,
        'message' => 'You are not allowed to perform this action.',
        'code' => 'FORBIDDEN',
    ], 403);
}

function requireAdministratorRole(mysqli $conn, int $userId): void
{
    $principal = activeAuthPrincipal();
    if ($principal !== null && authTenantId($principal) === $userId && !empty($principal->is_owner)) {
        return;
    }
    requirePermission($conn, $userId, 'users.manage');
}

/**
 * Maps the shared invoice table's discriminator to its authorization prefix.
 * FACTURE and DRAFT are both invoice workflow records.
 */
function invoiceDocumentPermissionPrefix($invoiceType): string
{
    return match (strtoupper(trim((string)$invoiceType))) {
        'DEVIS' => 'devis',
        'AVOIR' => 'avoirs',
        '', 'FACTURE', 'DRAFT' => 'invoices',
        default => throw new InvalidArgumentException('Unsupported document type.'),
    };
}

function invoiceDocumentPermission($invoiceType, string $action): string
{
    $normalizedAction = strtolower(trim($action));
    if (!in_array($normalizedAction, ['view', 'create', 'edit', 'delete', 'validate', 'send'], true)) {
        throw new InvalidArgumentException('Unsupported document permission action.');
    }

    return invoiceDocumentPermissionPrefix($invoiceType) . '.' . $normalizedAction;
}

function userCanAccessInvoiceDocument(mysqli $conn, int $userId, $invoiceType, string $action): bool
{
    return userHasPermission($conn, $userId, invoiceDocumentPermission($invoiceType, $action));
}

function requireInvoiceDocumentPermission(mysqli $conn, int $userId, $invoiceType, string $action): void
{
    requirePermission($conn, $userId, invoiceDocumentPermission($invoiceType, $action));
}

/** @return string[] Database discriminator values visible to the current role. */
function readableInvoiceDocumentTypes(mysqli $conn, int $userId): array
{
    $types = [];
    if (userHasPermission($conn, $userId, 'invoices.view')) {
        $types[] = 'FACTURE';
        $types[] = 'DRAFT';
    }
    if (userHasPermission($conn, $userId, 'devis.view')) {
        $types[] = 'DEVIS';
    }
    if (userHasPermission($conn, $userId, 'avoirs.view')) {
        $types[] = 'AVOIR';
    }
    return $types;
}

function requireAnyInvoiceDocumentView(mysqli $conn, int $userId): array
{
    $types = readableInvoiceDocumentTypes($conn, $userId);
    if (!$types) {
        requireAnyPermission($conn, $userId, ['invoices.view', 'devis.view', 'avoirs.view']);
    }
    return $types;
}

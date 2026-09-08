<?php

declare(strict_types=1);

function projectAllowedFields(array $row, array $allowed): array
{
    return array_intersect_key($row, array_fill_keys($allowed, true));
}

function projectRows(array $rows, callable $projector): array
{
    return array_map(static fn(array $row): array => $projector($row), $rows);
}

function roleCanViewFullClientIdentity(string $role): bool
{
    return in_array(normalizeUserRole($role), ['ADMINISTRATOR', 'COMMERCIAL', 'ACCOUNTING'], true);
}

function roleCanViewInventoryCosts(string $role): bool
{
    return in_array(normalizeUserRole($role), ['ADMINISTRATOR', 'STOCK', 'ACCOUNTING'], true);
}

function roleCanViewSettlementFields(string $role): bool
{
    return in_array(normalizeUserRole($role), ['ADMINISTRATOR', 'ACCOUNTING'], true);
}

function projectClientFields(array $row, string $role): array
{
    $allowed = ['id', 'reference', 'type', 'name', 'email', 'phone', 'address'];
    if (roleCanViewFullClientIdentity($role)) {
        $allowed = [...$allowed, 'fiscalId', 'cin', 'payment_terms_days', 'is_archived', 'archived_at', 'date_creation'];
    }
    return projectAllowedFields($row, $allowed);
}

function projectProductFields(array $row, string $role): array
{
    $allowed = [
        'id', 'code', 'barcode', 'name', 'category', 'item_type', 'price', 'selling_price_required', 'tva_rate',
        'unit', 'stock_quantity',
    ];
    if (roleCanViewInventoryCosts($role)) {
        $allowed = [
            ...$allowed, 'last_purchase_price', 'average_cost', 'reorder_point',
            'inventory_value', 'stock_value',
        ];
    }
    return projectAllowedFields($row, $allowed);
}

function projectProductAggregates(array $aggregates, string $role): array
{
    $allowed = ['stock_units'];
    if (roleCanViewInventoryCosts($role)) $allowed[] = 'stock_value';
    return projectAllowedFields($aggregates, $allowed);
}

function projectInvoiceFields(array $row, string $role): array
{
    $alwaysHidden = [
        'user_id', 'idempotency_key', 'id_extract', 'id_lettrage',
        'json_finsys', 'json_return', 'json_return2',
    ];
    foreach ($alwaysHidden as $field) unset($row[$field]);
    if (!roleCanViewSettlementFields($role)) {
        unset($row['payment_method'], $row['tx_retenue'], $row['retenue'], $row['net_retenue']);
    }
    return $row;
}

function projectOperationalDocumentFields(array $row): array
{
    foreach (['user_id', 'idempotency_key', 'created_by', 'updated_by'] as $field) unset($row[$field]);
    return $row;
}

function projectDashboardFields(array $payload, string $role): array
{
    $role = normalizeUserRole($role);
    if ($role === 'ADMINISTRATOR') return $payload;

    unset($payload['administration']);
    if ($role !== 'STOCK') {
        unset($payload['inventory'], $payload['low_stock_count'], $payload['low_stock'], $payload['top_products']);
    }
    if (!in_array($role, ['COMMERCIAL', 'ACCOUNTING'], true)) {
        unset(
            $payload['invoice'],
            $payload['sales'],
            $payload['top_clients'],
            $payload['recent_invoices'],
            $payload['monthly_series']
        );
    }
    if ($role !== 'ACCOUNTING') {
        unset($payload['accounting'], $payload['monthly_expenses']);
    }
    return $payload;
}

function projectNotificationCounts(array $counts, string $role): array
{
    $role = normalizeUserRole($role);
    $allowed = match ($role) {
        'ADMINISTRATOR' => ['unpaid_count', 'low_stock_count', 'client_count', 'product_count', 'pricing_required_count'],
        'COMMERCIAL' => ['unpaid_count', 'client_count', 'product_count'],
        'STOCK' => ['low_stock_count', 'product_count'],
        'ACCOUNTING' => ['unpaid_count'],
        default => [],
    };
    return projectAllowedFields($counts, $allowed);
}

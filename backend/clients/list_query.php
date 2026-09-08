<?php

declare(strict_types=1);

/**
 * Return the columns visible to the application user without mutating schema.
 * This lets read-only client lists remain available while a deployment's
 * migrations are being completed.
 *
 * @return array<string, true>
 */
function clientListAvailableColumns(mysqli $conn): array
{
    $columns = [];
    $result = $conn->query('SHOW COLUMNS FROM clients');
    while ($row = $result->fetch_assoc()) {
        $field = (string)($row['Field'] ?? '');
        if ($field !== '') {
            $columns[$field] = true;
        }
    }
    $result->close();

    return $columns;
}

/** @param array<string, true> $columns */
function clientListSelectSql(array $columns): string
{
    $reference = isset($columns['reference'])
        ? 'reference'
        : 'CAST(NULL AS CHAR) AS reference';
    $paymentTerms = isset($columns['payment_terms_days'])
        ? 'payment_terms_days'
        : '30 AS payment_terms_days';

    return implode(',', [
        'id',
        $reference,
        "CASE WHEN type='person' THEN 'individual' ELSE type END AS type",
        'name',
        'email',
        'phone',
        'address',
        'fiscalId',
        'cin',
        $paymentTerms,
    ]);
}

/** @param array<string, true> $columns */
function clientListSearchSql(array $columns): string
{
    $searchable = ['name', 'email', 'phone', 'fiscalId', 'cin'];
    if (isset($columns['reference'])) {
        array_unshift($searchable, 'reference');
    }

    return "CONCAT_WS(' '," . implode(',', $searchable) . ') LIKE ?';
}

/**
 * @param array<string, true> $columns
 * @return string[]
 */
function clientListMissingMigrationColumns(array $columns): array
{
    return array_values(array_filter(
        ['reference', 'payment_terms_days'],
        static fn(string $column): bool => !isset($columns[$column])
    ));
}

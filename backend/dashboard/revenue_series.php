<?php

declare(strict_types=1);

/**
 * Fill a monthly revenue result with zero-value months so chart clients always
 * receive a continuous, oldest-to-newest series.
 *
 * @param array<int,array<string,mixed>> $rows
 * @return array<int,array{month:string,revenue:float}>
 */
function dashboardMonthlyRevenueSeries(
    array $rows,
    string $endMonth,
    int $monthCount = 8
): array {
    if ($monthCount < 1 || $monthCount > 24) {
        throw new InvalidArgumentException('Dashboard revenue month count must be between 1 and 24.');
    }

    $end = DateTimeImmutable::createFromFormat('!Y-m-d', $endMonth);
    if (!$end || $end->format('Y-m-d') !== $endMonth || $end->format('d') !== '01') {
        throw new InvalidArgumentException('Dashboard revenue end month must use YYYY-MM-01.');
    }

    $valuesByMonth = [];
    foreach ($rows as $row) {
        $key = (string)($row['month'] ?? $row['month_key'] ?? '');
        if (!preg_match('/^\d{4}-\d{2}$/', $key)) continue;
        $valuesByMonth[$key] = round((float)($row['revenue'] ?? 0), 3);
    }

    $series = [];
    $first = $end->modify('-' . ($monthCount - 1) . ' months');
    for ($index = 0; $index < $monthCount; $index++) {
        $key = $first->modify('+' . $index . ' months')->format('Y-m');
        $series[] = [
            'month' => $key,
            'revenue' => $valuesByMonth[$key] ?? 0.0,
        ];
    }

    return $series;
}

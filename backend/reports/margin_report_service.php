<?php

declare(strict_types=1);

function validateMarginReportPeriod(string $from, string $to): void
{
    if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $from) || !preg_match('/^\d{4}-\d{2}-\d{2}$/', $to) || $to < $from) {
        throw new InvalidArgumentException('Invalid margin report period.');
    }
}

function marginReportQuery(mysqli $conn, string $sql, string $types, array $args): array
{
    $stmt = $conn->prepare($sql);
    $stmt->bind_param($types, ...$args);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    return $rows;
}

function marginReportAmount(float $amount): string
{
    return number_format(round($amount, 3), 3, '.', '');
}

function marginReportFactsSql(): string
{
    return "SELECT
        i.id invoice_id,i.invoice,i.invoice_date,UPPER(i.invoice_type) invoice_type,
        COALESCE(c.id,0) customer_id,COALESCE(NULLIF(c.name,''),'Client non lié') customer_name,
        COALESCE(NULLIF(TRIM(i.salesperson_name),''),'Non affecté') salesperson_name,
        COALESCE(p.id,0) product_id,COALESCE(NULLIF(ii.product_code,''),p.code,'') product_code,
        COALESCE(NULLIF(p.name,''),NULLIF(ii.product,''),'Article non lié') product_name,
        COALESCE(NULLIF(TRIM(p.category),''),'Non classé') category,
        COALESCE(p.item_type,'UNKNOWN') item_type,
        ROUND(SUM(CASE WHEN UPPER(i.invoice_type)='AVOIR' THEN -ABS(ii.subtotal_tnd) ELSE ii.subtotal_tnd END),3) revenue_tnd,
        ROUND(COALESCE(MAX(mc.cost_tnd),0),3) cost_tnd,
        ROUND(SUM(CASE WHEN UPPER(i.invoice_type)='AVOIR' THEN -ABS(ii.qty) ELSE ii.qty END),3) quantity,
        MAX(p.item_type='PRODUCT' AND (UPPER(i.invoice_type)='FACTURE' OR (UPPER(i.invoice_type)='AVOIR' AND i.return_to_stock=1))) cost_required,
        MAX(COALESCE(mc.movement_count,0)>0) cost_recorded
      FROM erp_invoice_items ii
      JOIN erp_invoices i ON i.id=ii.invoice_id
      LEFT JOIN clients c ON c.id=CAST(i.custom_code AS UNSIGNED) AND c.user_id=i.user_id
      LEFT JOIN products p ON p.id=ii.product_id AND p.user_id=i.user_id
      LEFT JOIN(
        SELECT i2.id invoice_id,m.product_id,
          ROUND(SUM(CASE WHEN UPPER(i2.invoice_type)='AVOIR' THEN -ABS(m.movement_value) ELSE ABS(m.cogs_value) END),3) cost_tnd,
          COUNT(*) movement_count
        FROM erp_invoices i2
        JOIN product_stock_movements m ON m.user_id=i2.user_id AND(
          (UPPER(i2.invoice_type)='AVOIR' AND m.reference_type='INVOICE' AND m.reference_id=i2.id)
          OR (UPPER(i2.invoice_type)='FACTURE' AND i2.source_flow='DELIVERY' AND m.reference_type='DELIVERY_NOTE' AND m.reference_id=i2.delivery_note_id)
          OR (UPPER(i2.invoice_type)='FACTURE' AND i2.source_flow<>'DELIVERY' AND m.reference_type='INVOICE' AND m.reference_id=i2.id)
        )
        WHERE i2.user_id=? AND i2.invoice_date BETWEEN ? AND ?
          AND UPPER(i2.invoice_type) IN('FACTURE','AVOIR') AND i2.is_validated=1
        GROUP BY i2.id,m.product_id
      )mc ON mc.invoice_id=i.id AND mc.product_id=ii.product_id
      WHERE i.user_id=? AND i.invoice_date BETWEEN ? AND ?
        AND UPPER(i.invoice_type) IN('FACTURE','AVOIR') AND i.is_validated=1
      GROUP BY i.id,i.invoice,i.invoice_date,i.invoice_type,c.id,c.name,i.salesperson_name,
        p.id,ii.product_code,p.code,p.name,ii.product,p.category,p.item_type";
}

function normalizeMarginAggregate(array $row): array
{
    $moneyKeys = ['revenue_tnd','cost_tnd','gross_margin_tnd','missing_cost_revenue_tnd','service_revenue_tnd','uncategorized_revenue_tnd','unassigned_salesperson_revenue_tnd'];
    foreach ($moneyKeys as $key) $row[$key] = marginReportAmount((float)($row[$key] ?? 0));
    $row['documents'] = (int)($row['documents'] ?? 0);
    $row['quantity'] = marginReportAmount((float)($row['quantity'] ?? 0));
    $row['margin_rate_percent'] = marginReportAmount((float)($row['margin_rate_percent'] ?? 0));
    $row['cost_coverage_percent'] = marginReportAmount((float)($row['cost_coverage_percent'] ?? 0));
    if (array_key_exists('total_groups', $row)) $row['total_groups'] = (int)$row['total_groups'];
    return $row;
}

function marginAggregateProjection(): string
{
    return "COUNT(DISTINCT invoice_id) documents,ROUND(SUM(quantity),3) quantity,
      ROUND(COALESCE(SUM(revenue_tnd),0),3) revenue_tnd,
      ROUND(COALESCE(SUM(cost_tnd),0),3) cost_tnd,
      ROUND(COALESCE(SUM(revenue_tnd-cost_tnd),0),3) gross_margin_tnd,
      ROUND(CASE WHEN ABS(SUM(revenue_tnd))<0.0005 THEN 0 ELSE SUM(revenue_tnd-cost_tnd)/ABS(SUM(revenue_tnd))*100 END,3) margin_rate_percent,
      ROUND(COALESCE(SUM(CASE WHEN (cost_required=1 AND cost_recorded=0) OR item_type IN('SERVICE','UNKNOWN') THEN ABS(revenue_tnd) ELSE 0 END),0),3) missing_cost_revenue_tnd,
      ROUND(COALESCE(SUM(CASE WHEN item_type='SERVICE' THEN ABS(revenue_tnd) ELSE 0 END),0),3) service_revenue_tnd,
      ROUND(COALESCE(SUM(CASE WHEN category='Non classé' THEN ABS(revenue_tnd) ELSE 0 END),0),3) uncategorized_revenue_tnd,
      ROUND(COALESCE(SUM(CASE WHEN salesperson_name='Non affecté' THEN ABS(revenue_tnd) ELSE 0 END),0),3) unassigned_salesperson_revenue_tnd,
      ROUND(CASE WHEN COALESCE(SUM(ABS(revenue_tnd)),0)<0.0005 THEN 100 ELSE
        SUM(CASE WHEN item_type='PRODUCT' AND (cost_required=0 OR cost_recorded=1) THEN ABS(revenue_tnd) ELSE 0 END)/SUM(ABS(revenue_tnd))*100 END,3) cost_coverage_percent";
}

function buildTenantMarginReport(mysqli $conn, int $userId, string $from, string $to, int $limit = 25): array
{
    if ($userId <= 0) throw new InvalidArgumentException('Invalid margin report tenant.');
    validateMarginReportPeriod($from, $to);
    $limit = min(100, max(1, $limit));
    $facts = marginReportFactsSql();
    $args = [$userId, $from, $to, $userId, $from, $to];
    $summaryRows = marginReportQuery($conn, 'SELECT '.marginAggregateProjection()." FROM($facts) facts", 'ississ', $args);
    $summary = normalizeMarginAggregate($summaryRows[0] ?? []);

    $dimensions = [
        'customers' => ['CAST(customer_id AS CHAR)', 'customer_name', "''"],
        'products' => ["CASE WHEN product_id>0 THEN CAST(product_id AS CHAR) ELSE CONCAT('LINE:',product_code,':',product_name) END", 'product_name', 'MAX(product_code)'],
        'categories' => ['category', 'category', "''"],
        'salespersons' => ['salesperson_name', 'salesperson_name', "''"],
    ];
    $result = [];
    $counts = [];
    foreach ($dimensions as $name => [$key, $label, $secondary]) {
        $sql = "SELECT $key entity_key,$label label,$secondary secondary_label,".marginAggregateProjection().",
          COUNT(*) OVER() total_groups FROM($facts) facts GROUP BY $key,$label ORDER BY ABS(SUM(revenue_tnd)) DESC,$label LIMIT ?";
        $rows = marginReportQuery($conn, $sql, 'ississi', [...$args, $limit]);
        $result[$name] = array_map('normalizeMarginAggregate', $rows);
        $counts[$name] = (int)($rows[0]['total_groups'] ?? 0);
    }

    return [
        'period' => ['from' => $from, 'to' => $to],
        'valuation_method' => 'WEIGHTED_AVERAGE_STOCK_LEDGER',
        'summary' => $summary,
        'dimensions' => $result,
        'dimension_counts' => $counts,
        'row_limit' => $limit,
        'cost_model_complete' => (float)$summary['missing_cost_revenue_tnd'] < 0.0005,
    ];
}

<?php

declare(strict_types=1);

/**
 * Joins that derive invoice readiness from delivered and invoiced quantities.
 * A linked, non-cancelled invoice draft deliberately blocks a second draft.
 */
function deliveryWorkflowReadinessJoins(): string
{
    $deliveryKey = "(CASE
        WHEN di.product_id IS NOT NULL AND di.product_id>0 THEN CONCAT('id:',di.product_id)
        WHEN TRIM(COALESCE(di.product_code,''))<>'' THEN CONCAT('code:',UPPER(TRIM(di.product_code)))
        ELSE CONCAT('label:',UPPER(TRIM(di.product))) END) COLLATE utf8mb4_unicode_ci";
    $invoiceKey = "(CASE
        WHEN ii.product_id IS NOT NULL AND ii.product_id>0 THEN CONCAT('id:',ii.product_id)
        WHEN TRIM(COALESCE(ii.product_code,''))<>'' THEN CONCAT('code:',UPPER(TRIM(ii.product_code)))
        ELSE CONCAT('label:',UPPER(TRIM(ii.product))) END) COLLATE utf8mb4_unicode_ci";

    return "
        LEFT JOIN (
            SELECT delivered.delivery_note_id,
                   MAX(delivered.delivered_qty>COALESCE(invoiced.invoiced_qty,0)+0.0001) has_remaining
            FROM (
                SELECT di.delivery_note_id,$deliveryKey item_key,SUM(di.qty) delivered_qty
                FROM erp_delivery_note_items di
                GROUP BY di.delivery_note_id,item_key
            ) delivered
            LEFT JOIN (
                SELECT i.delivery_note_id,$invoiceKey item_key,SUM(ii.qty) invoiced_qty
                FROM erp_invoices i
                JOIN erp_invoice_items ii ON ii.invoice_id=i.id
                WHERE i.delivery_note_id IS NOT NULL
                  AND i.invoice_type='FACTURE'
                  AND i.is_validated=1
                  AND i.status<>'CANCELLED'
                GROUP BY i.delivery_note_id,item_key
            ) invoiced ON invoiced.delivery_note_id=delivered.delivery_note_id
                      AND invoiced.item_key=delivered.item_key
            GROUP BY delivered.delivery_note_id
        ) readiness ON readiness.delivery_note_id=dn.id
        LEFT JOIN (
            SELECT delivery_note_id,COUNT(*) draft_invoice_count,MAX(id) draft_invoice_id
            FROM erp_invoices
            WHERE delivery_note_id IS NOT NULL
              AND invoice_type='FACTURE'
              AND is_validated=0
              AND status<>'CANCELLED'
            GROUP BY delivery_note_id
        ) invoice_drafts ON invoice_drafts.delivery_note_id=dn.id
        LEFT JOIN (
            SELECT delivery_note_id,COUNT(*) validated_invoice_count
            FROM erp_invoices
            WHERE delivery_note_id IS NOT NULL
              AND invoice_type='FACTURE'
              AND is_validated=1
              AND status<>'CANCELLED'
            GROUP BY delivery_note_id
        ) validated_invoices ON validated_invoices.delivery_note_id=dn.id";
}

function deliveryWorkflowSummary(mysqli $conn, int $userId): array
{
    $joins = deliveryWorkflowReadinessJoins();
    $sql = "SELECT
        COALESCE(SUM(dn.status='DRAFT'),0) drafts,
        COALESCE(SUM(dn.status='CONFIRMED'),0) confirmed,
        COALESCE(SUM(
            dn.status='DELIVERED'
            AND dn.document_type='DELIVERY'
            AND COALESCE(readiness.has_remaining,0)=1
            AND COALESCE(invoice_drafts.draft_invoice_count,0)=0
        ),0) ready_to_invoice,
        COALESCE(SUM(
            dn.status='DELIVERED'
            AND dn.document_type='DELIVERY'
            AND COALESCE(invoice_drafts.draft_invoice_count,0)>0
        ),0) invoice_drafts,
        COALESCE(SUM(
            dn.status='DELIVERED'
            AND dn.document_type='DELIVERY'
            AND COALESCE(readiness.has_remaining,0)=0
            AND COALESCE(validated_invoices.validated_invoice_count,0)>0
        ),0) fully_invoiced
        FROM erp_delivery_notes dn
        $joins
        WHERE dn.user_id=?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param('i', $userId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc() ?: [];
    $stmt->close();

    return [
        'drafts' => (int)($row['drafts'] ?? 0),
        'confirmed' => (int)($row['confirmed'] ?? 0),
        'ready_to_invoice' => (int)($row['ready_to_invoice'] ?? 0),
        'invoice_drafts' => (int)($row['invoice_drafts'] ?? 0),
        'fully_invoiced' => (int)($row['fully_invoiced'] ?? 0),
    ];
}

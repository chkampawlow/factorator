-- Recalculate legacy test line amounts with the documented millime policy.
UPDATE erp_invoice_items ii
JOIN erp_invoices i ON i.id = ii.invoice_id
SET
    ii.subtotal = ROUND(ii.qty * ii.price * (1 - ii.discount / 100), 3),
    ii.fodec_amount = ROUND((ii.qty * ii.price * (1 - ii.discount / 100)) * ii.fodec_rate / 100, 3),
    ii.montant_tva = ROUND(
        ((ii.qty * ii.price * (1 - ii.discount / 100))
          + ((ii.qty * ii.price * (1 - ii.discount / 100)) * ii.fodec_rate / 100))
        * CASE WHEN ii.tax_regime = 'STANDARD' THEN ii.tva_rate ELSE 0 END / 100,
        3
    ),
    ii.subtotalTTC = ROUND(
        (ii.qty * ii.price * (1 - ii.discount / 100))
        + ((ii.qty * ii.price * (1 - ii.discount / 100)) * ii.fodec_rate / 100)
        + (
            ((ii.qty * ii.price * (1 - ii.discount / 100))
              + ((ii.qty * ii.price * (1 - ii.discount / 100)) * ii.fodec_rate / 100))
            * CASE WHEN ii.tax_regime = 'STANDARD' THEN ii.tva_rate ELSE 0 END / 100
        ),
        3
    ),
    ii.subtotal_tnd = ROUND((ii.qty * ii.price * (1 - ii.discount / 100)) * i.exchange_rate, 3),
    ii.tax_tnd = ROUND(
        (
            ((ii.qty * ii.price * (1 - ii.discount / 100)) * ii.fodec_rate / 100)
            + (
                ((ii.qty * ii.price * (1 - ii.discount / 100))
                  + ((ii.qty * ii.price * (1 - ii.discount / 100)) * ii.fodec_rate / 100))
                * CASE WHEN ii.tax_regime = 'STANDARD' THEN ii.tva_rate ELSE 0 END / 100
            )
        ) * i.exchange_rate,
        3
    ),
    ii.total_tnd = ROUND(
        (
            (ii.qty * ii.price * (1 - ii.discount / 100))
            + ((ii.qty * ii.price * (1 - ii.discount / 100)) * ii.fodec_rate / 100)
            + (
                ((ii.qty * ii.price * (1 - ii.discount / 100))
                  + ((ii.qty * ii.price * (1 - ii.discount / 100)) * ii.fodec_rate / 100))
                * CASE WHEN ii.tax_regime = 'STANDARD' THEN ii.tva_rate ELSE 0 END / 100
            )
        ) * i.exchange_rate,
        3
    );

UPDATE erp_invoices i
LEFT JOIN (
    SELECT
        invoice_id,
        ROUND(COALESCE(SUM(subtotal), 0), 3) subtotal,
        ROUND(COALESCE(SUM(fodec_amount), 0), 3) fodec,
        ROUND(COALESCE(SUM(montant_tva), 0), 3) vat,
        ROUND(COALESCE(SUM(subtotalTTC), 0), 3) ttc,
        ROUND(COALESCE(SUM(subtotal_tnd), 0), 3) subtotal_tnd,
        ROUND(COALESCE(SUM(tax_tnd), 0), 3) tax_tnd,
        ROUND(COALESCE(SUM(total_tnd), 0), 3) total_tnd
    FROM erp_invoice_items
    GROUP BY invoice_id
) x ON x.invoice_id = i.id
SET
    i.subtotal = COALESCE(x.subtotal, 0),
    i.subtotal_tnd = COALESCE(x.subtotal_tnd, 0),
    i.base_tva = ROUND(COALESCE(x.subtotal, 0) + COALESCE(x.fodec, 0), 3),
    i.montant_tva = COALESCE(x.vat, 0),
    i.tax_total_tnd = COALESCE(x.tax_tnd, 0),
    i.subtotal_ttc = COALESCE(x.ttc, 0),
    i.total = ROUND(
        COALESCE(x.ttc, 0) + i.shipping - i.discount
        + CASE WHEN i.invoice_type = 'AVOIR' THEN -COALESCE(i.timbre, 0) ELSE COALESCE(i.timbre, 0) END,
        3
    ),
    i.total_tnd = ROUND(
        COALESCE(x.total_tnd, 0)
        + (
            i.shipping - i.discount
            + CASE WHEN i.invoice_type = 'AVOIR' THEN -COALESCE(i.timbre, 0) ELSE COALESCE(i.timbre, 0) END
        ) * i.exchange_rate,
        3
    );

UPDATE erp_sales_orders o
LEFT JOIN (
    SELECT sales_order_id, ROUND(SUM(subtotal),3) subtotal, ROUND(SUM(montant_tva),3) vat, ROUND(SUM(total),3) total
    FROM erp_sales_order_items GROUP BY sales_order_id
) x ON x.sales_order_id = o.id
SET o.subtotal=COALESCE(x.subtotal,0), o.montant_tva=COALESCE(x.vat,0), o.total=COALESCE(x.total,0);

UPDATE erp_supplier_orders o
LEFT JOIN (
    SELECT
        supplier_order_id,
        ROUND(SUM(ROUND(qty * price, 3)), 3) subtotal,
        ROUND(SUM(ROUND(ROUND(qty * price, 3) * tva_rate / 100, 3)), 3) vat,
        ROUND(SUM(line_total), 3) total
    FROM erp_supplier_order_items
    GROUP BY supplier_order_id
) x ON x.supplier_order_id = o.id
SET o.subtotal=COALESCE(x.subtotal,0), o.total_vat=COALESCE(x.vat,0), o.total=COALESCE(x.total,0);

UPDATE erp_supplier_receptions r
LEFT JOIN (
    SELECT
        supplier_reception_id,
        ROUND(SUM(subtotal),3) ht,
        ROUND(SUM(ROUND(subtotal * tva_rate / 100,3)),3) vat,
        ROUND(SUM(subtotal + ROUND(subtotal * tva_rate / 100,3)),3) ttc
    FROM erp_supplier_reception_items
    GROUP BY supplier_reception_id
) x ON x.supplier_reception_id = r.id
SET r.total_ht=COALESCE(x.ht,0), r.total_vat=COALESCE(x.vat,0), r.total_ttc=COALESCE(x.ttc,0);

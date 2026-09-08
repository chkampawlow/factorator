-- Services never carry inventory. Preserve their legacy movement history and
-- balance it with an explicit adjustment instead of deleting audit evidence.
INSERT INTO product_stock_movements (
    user_id, product_id, movement_type, quantity, unit_cost,
    movement_value, cogs_value, reference_type, reference_id,
    reason_code, idempotency_key, note
)
SELECT
    p.user_id,
    p.id,
    'ADJUSTMENT',
    -ROUND(SUM(m.quantity), 3),
    0,
    0,
    0,
    'PRODUCT',
    p.id,
    'SERVICE_ZERO_STOCK',
    CONCAT('reconcile-service-stock:', p.id),
    'Legacy cleanup: service items cannot carry stock'
FROM products p
JOIN product_stock_movements m
  ON m.product_id = p.id AND m.user_id = p.user_id
WHERE p.item_type = 'SERVICE'
GROUP BY p.user_id, p.id
HAVING ABS(ROUND(SUM(m.quantity), 3)) >= 0.0005
   AND NOT EXISTS (
       SELECT 1
       FROM product_stock_movements existing
       WHERE existing.user_id = p.user_id
         AND existing.idempotency_key = CONCAT('reconcile-service-stock:', p.id)
   );

-- The movement ledger is authoritative; stock_quantity is a query cache.
UPDATE products p
LEFT JOIN (
    SELECT user_id, product_id, ROUND(COALESCE(SUM(quantity), 0), 3) quantity
    FROM product_stock_movements
    GROUP BY user_id, product_id
) ledger ON ledger.user_id = p.user_id AND ledger.product_id = p.id
SET
    p.stock_quantity = CASE
        WHEN p.item_type = 'PRODUCT' THEN COALESCE(ledger.quantity, 0)
        ELSE 0
    END,
    p.average_cost = CASE WHEN p.item_type = 'SERVICE' THEN 0 ELSE p.average_cost END,
    p.last_purchase_price = CASE WHEN p.item_type = 'SERVICE' THEN 0 ELSE p.last_purchase_price END;

ALTER TABLE products
    ADD CONSTRAINT chk_service_zero_stock
    CHECK (item_type = 'PRODUCT' OR stock_quantity = 0);

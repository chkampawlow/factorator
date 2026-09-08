ALTER TABLE products
    ADD COLUMN IF NOT EXISTS selling_price_required TINYINT(1) NOT NULL DEFAULT 0 AFTER price;

UPDATE products
SET selling_price_required = 1
WHERE item_type = 'PRODUCT'
  AND price <= 0;

CREATE INDEX IF NOT EXISTS idx_products_company_pricing_required
    ON products (user_id, item_type, selling_price_required, id);

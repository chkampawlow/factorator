ALTER TABLE products
    ADD COLUMN IF NOT EXISTS reorder_point DECIMAL(15,3) NOT NULL DEFAULT 3.000 AFTER stock_quantity;

CREATE INDEX IF NOT EXISTS idx_products_company_reorder ON products(user_id, item_type, reorder_point, stock_quantity, id);

ALTER TABLE products
    ADD CONSTRAINT chk_product_reorder_point CHECK (reorder_point >= 0);

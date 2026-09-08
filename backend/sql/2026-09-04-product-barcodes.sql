ALTER TABLE products ADD COLUMN IF NOT EXISTS barcode VARCHAR(64) NULL AFTER code;

UPDATE products
SET barcode = CONCAT('EF-P-', LPAD(id, 8, '0'))
WHERE item_type = 'PRODUCT' AND (barcode IS NULL OR barcode = '');

CREATE UNIQUE INDEX IF NOT EXISTS uq_products_company_barcode
ON products(user_id, barcode);

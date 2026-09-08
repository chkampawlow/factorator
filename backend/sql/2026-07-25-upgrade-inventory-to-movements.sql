CREATE TABLE IF NOT EXISTS product_stock_movements (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED NOT NULL,
    product_id INT UNSIGNED NOT NULL,
    movement_type ENUM('INITIAL', 'ADJUSTMENT', 'DELIVERY', 'EXIT', 'RETURN', 'MANUAL') NOT NULL,
    quantity DECIMAL(15,3) NOT NULL,
    reference_type VARCHAR(32) NULL,
    reference_id INT UNSIGNED NULL,
    note VARCHAR(255) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_stock_movements_product_user (product_id, user_id),
    INDEX idx_stock_movements_reference (reference_type, reference_id),
    CONSTRAINT fk_stock_movements_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE products
    MODIFY COLUMN stock_quantity DECIMAL(15,3) NOT NULL DEFAULT 0;

INSERT INTO product_stock_movements (
    user_id,
    product_id,
    movement_type,
    quantity,
    reference_type,
    reference_id,
    note
)
SELECT
    p.user_id,
    p.id,
    'INITIAL',
    p.stock_quantity,
    'PRODUCT',
    p.id,
    'Legacy stock bootstrap'
FROM products p
LEFT JOIN (
    SELECT product_id, user_id, COUNT(*) AS movement_count
    FROM product_stock_movements
    GROUP BY product_id, user_id
) sm ON sm.product_id = p.id AND sm.user_id = p.user_id
WHERE IFNULL(sm.movement_count, 0) = 0
  AND ABS(COALESCE(p.stock_quantity, 0)) > 0.0001;

UPDATE products p
LEFT JOIN (
    SELECT product_id, user_id, ROUND(COALESCE(SUM(quantity), 0), 3) AS stock_quantity
    FROM product_stock_movements
    GROUP BY product_id, user_id
) sm ON sm.product_id = p.id AND sm.user_id = p.user_id
SET p.stock_quantity = COALESCE(sm.stock_quantity, 0);

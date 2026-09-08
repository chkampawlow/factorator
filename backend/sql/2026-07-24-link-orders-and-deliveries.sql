ALTER TABLE erp_sales_orders
MODIFY COLUMN status ENUM('DRAFT', 'CONFIRMED', 'PARTIALLY_DELIVERED', 'DELIVERED', 'CANCELLED', 'INVOICED')
NOT NULL DEFAULT 'DRAFT';

ALTER TABLE erp_delivery_notes
ADD COLUMN document_type ENUM('DELIVERY', 'EXIT') NOT NULL DEFAULT 'DELIVERY' AFTER delivery_number,
ADD COLUMN sales_order_id INT UNSIGNED NULL AFTER client_id,
ADD COLUMN vehicle_registration VARCHAR(32) NULL AFTER delivery_address,
ADD COLUMN movement_reason VARCHAR(120) NULL AFTER customer_reference,
ADD COLUMN stock_applied TINYINT(1) NOT NULL DEFAULT 0 AFTER item_count,
ADD KEY idx_delivery_notes_order (sales_order_id),
ADD CONSTRAINT fk_delivery_notes_order FOREIGN KEY (sales_order_id) REFERENCES erp_sales_orders(id) ON DELETE SET NULL;

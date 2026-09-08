CREATE TABLE IF NOT EXISTS erp_delivery_notes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    delivery_number VARCHAR(40) NOT NULL UNIQUE,
    document_type ENUM('DELIVERY', 'EXIT') NOT NULL DEFAULT 'DELIVERY',
    client_id INT NOT NULL,
    sales_order_id INT UNSIGNED NULL,
    delivery_date DATE NOT NULL,
    expected_delivery_date DATE NULL,
    delivery_address VARCHAR(255) NULL,
    vehicle_registration VARCHAR(32) NULL,
    customer_reference VARCHAR(120) NULL,
    movement_reason VARCHAR(120) NULL,
    notes TEXT NULL,
    status ENUM('DRAFT', 'CONFIRMED', 'CANCELLED', 'DELIVERED') NOT NULL DEFAULT 'DRAFT',
    item_count INT NOT NULL DEFAULT 0,
    stock_applied TINYINT(1) NOT NULL DEFAULT 0,
    user_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    KEY idx_delivery_notes_user (user_id),
    KEY idx_delivery_notes_client (client_id),
    KEY idx_delivery_notes_order (sales_order_id),
    CONSTRAINT fk_delivery_notes_client FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE RESTRICT,
    CONSTRAINT fk_delivery_notes_order FOREIGN KEY (sales_order_id) REFERENCES erp_sales_orders(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS erp_delivery_note_items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    delivery_note_id INT NOT NULL,
    product_id INT NULL,
    product_code VARCHAR(60) NULL,
    product VARCHAR(255) NOT NULL,
    qty DECIMAL(12,3) NOT NULL DEFAULT 0,
    unit VARCHAR(40) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY idx_delivery_items_note (delivery_note_id),
    CONSTRAINT fk_delivery_items_note FOREIGN KEY (delivery_note_id) REFERENCES erp_delivery_notes(id) ON DELETE CASCADE
);

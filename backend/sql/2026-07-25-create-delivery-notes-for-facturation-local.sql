CREATE TABLE IF NOT EXISTS erp_delivery_notes (
    id INT(11) NOT NULL AUTO_INCREMENT,
    delivery_number VARCHAR(64) NOT NULL,
    document_type ENUM('DELIVERY', 'EXIT') NOT NULL DEFAULT 'DELIVERY',
    client_id INT(11) NOT NULL,
    sales_order_id INT(11) NULL,
    delivery_date DATE NOT NULL,
    expected_delivery_date DATE NULL,
    delivery_address VARCHAR(255) NULL,
    vehicle_registration VARCHAR(32) NULL,
    customer_reference VARCHAR(120) NULL,
    movement_reason VARCHAR(120) NULL,
    notes TEXT NULL,
    status ENUM('DRAFT', 'CONFIRMED', 'DELIVERED', 'CANCELLED') NOT NULL DEFAULT 'DRAFT',
    item_count INT(11) NOT NULL DEFAULT 0,
    stock_applied TINYINT(1) NOT NULL DEFAULT 0,
    user_id INT(11) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_delivery_number_user (user_id, delivery_number),
    KEY idx_delivery_notes_user (user_id),
    KEY idx_delivery_notes_client (client_id),
    KEY idx_delivery_notes_order (sales_order_id),
    CONSTRAINT fk_delivery_notes_user
        FOREIGN KEY (user_id) REFERENCES users(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_delivery_notes_client
        FOREIGN KEY (client_id) REFERENCES clients(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_delivery_notes_order
        FOREIGN KEY (sales_order_id) REFERENCES erp_sales_orders(id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS erp_delivery_note_items (
    id INT(11) NOT NULL AUTO_INCREMENT,
    delivery_note_id INT(11) NOT NULL,
    product_id INT(11) NULL,
    product_code VARCHAR(100) NULL,
    product VARCHAR(255) NOT NULL,
    qty DECIMAL(15,3) NOT NULL DEFAULT 0.000,
    price DECIMAL(20,3) NOT NULL DEFAULT 0.000,
    discount DECIMAL(20,3) NOT NULL DEFAULT 0.000,
    tva_rate DECIMAL(10,3) NOT NULL DEFAULT 0.000,
    subtotal DECIMAL(20,3) NOT NULL DEFAULT 0.000,
    montant_tva DECIMAL(20,3) NOT NULL DEFAULT 0.000,
    total DECIMAL(20,3) NOT NULL DEFAULT 0.000,
    unit VARCHAR(50) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_delivery_items_note (delivery_note_id),
    KEY idx_delivery_items_product (product_id),
    CONSTRAINT fk_delivery_items_note
        FOREIGN KEY (delivery_note_id) REFERENCES erp_delivery_notes(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_delivery_items_product
        FOREIGN KEY (product_id) REFERENCES products(id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

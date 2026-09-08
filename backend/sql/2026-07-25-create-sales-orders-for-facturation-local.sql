CREATE TABLE IF NOT EXISTS erp_sales_orders (
    id INT(11) NOT NULL AUTO_INCREMENT,
    order_number VARCHAR(64) NOT NULL,
    client_id INT(11) NOT NULL,
    order_date DATE NOT NULL,
    expected_delivery_date DATE NULL,
    delivery_address VARCHAR(255) NULL,
    customer_reference VARCHAR(120) NULL,
    notes TEXT NULL,
    status ENUM('DRAFT', 'CONFIRMED', 'PARTIALLY_DELIVERED', 'DELIVERED', 'CANCELLED', 'INVOICED') NOT NULL DEFAULT 'DRAFT',
    subtotal DECIMAL(15,3) NOT NULL DEFAULT 0.000,
    montant_tva DECIMAL(15,3) NOT NULL DEFAULT 0.000,
    total DECIMAL(15,3) NOT NULL DEFAULT 0.000,
    invoice_id INT(11) NULL,
    user_id INT(11) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_sales_order_user_number (user_id, order_number),
    KEY idx_sales_order_user_status (user_id, status),
    KEY idx_sales_order_client (client_id),
    KEY idx_sales_order_invoice (invoice_id),
    CONSTRAINT fk_sales_orders_user
        FOREIGN KEY (user_id) REFERENCES users(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_sales_orders_client
        FOREIGN KEY (client_id) REFERENCES clients(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_sales_orders_invoice
        FOREIGN KEY (invoice_id) REFERENCES erp_invoices(id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS erp_sales_order_items (
    id INT(11) NOT NULL AUTO_INCREMENT,
    sales_order_id INT(11) NOT NULL,
    product_id INT(11) NULL,
    product_code VARCHAR(100) NULL,
    product VARCHAR(255) NOT NULL,
    qty DECIMAL(15,3) NOT NULL DEFAULT 1.000,
    price DECIMAL(15,3) NOT NULL DEFAULT 0.000,
    discount DECIMAL(7,3) NOT NULL DEFAULT 0.000,
    tva_rate DECIMAL(7,3) NOT NULL DEFAULT 0.000,
    subtotal DECIMAL(15,3) NOT NULL DEFAULT 0.000,
    montant_tva DECIMAL(15,3) NOT NULL DEFAULT 0.000,
    total DECIMAL(15,3) NOT NULL DEFAULT 0.000,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_sales_order_item_order (sales_order_id),
    KEY idx_sales_order_item_product (product_id),
    CONSTRAINT fk_sales_order_items_order
        FOREIGN KEY (sales_order_id) REFERENCES erp_sales_orders(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_sales_order_items_product
        FOREIGN KEY (product_id) REFERENCES products(id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

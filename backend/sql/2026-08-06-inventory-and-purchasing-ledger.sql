-- Accounting-quality inventory and separated purchasing documents.
ALTER TABLE products ADD COLUMN IF NOT EXISTS average_cost DECIMAL(20,6) NOT NULL DEFAULT 0.000000 AFTER last_purchase_price;
ALTER TABLE product_stock_movements
  ADD COLUMN IF NOT EXISTS unit_cost DECIMAL(20,6) NOT NULL DEFAULT 0.000000 AFTER quantity,
  ADD COLUMN IF NOT EXISTS movement_value DECIMAL(20,6) NOT NULL DEFAULT 0.000000 AFTER unit_cost,
  ADD COLUMN IF NOT EXISTS cogs_value DECIMAL(20,6) NOT NULL DEFAULT 0.000000 AFTER movement_value,
  ADD COLUMN IF NOT EXISTS reason_code VARCHAR(40) NULL AFTER reference_id,
  ADD COLUMN IF NOT EXISTS lot_number VARCHAR(100) NULL AFTER reason_code,
  ADD COLUMN IF NOT EXISTS serial_number VARCHAR(150) NULL AFTER lot_number,
  ADD COLUMN IF NOT EXISTS idempotency_key VARCHAR(190) NULL AFTER serial_number;
CREATE UNIQUE INDEX IF NOT EXISTS uq_stock_movement_idempotency ON product_stock_movements(user_id,idempotency_key);

ALTER TABLE erp_invoices ADD COLUMN IF NOT EXISTS return_to_stock TINYINT(1) NOT NULL DEFAULT 0 AFTER invoice_type;
UPDATE products SET average_cost = last_purchase_price WHERE average_cost = 0 AND last_purchase_price > 0;

CREATE TABLE IF NOT EXISTS erp_supplier_invoices (
  id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL, supplier_id INT NOT NULL, supplier_order_id INT NULL,
  invoice_number VARCHAR(100) NOT NULL, invoice_date DATE NOT NULL, due_date DATE NOT NULL,
  status ENUM('DRAFT','VALIDATED','PARTIALLY_PAID','PAID','CANCELLED') NOT NULL DEFAULT 'DRAFT',
  currency CHAR(3) NOT NULL DEFAULT 'TND', total_ht DECIMAL(20,3) NOT NULL DEFAULT 0,
  total_vat DECIMAL(20,3) NOT NULL DEFAULT 0, total_ttc DECIMAL(20,3) NOT NULL DEFAULT 0,
  credited_amount DECIMAL(20,3) NOT NULL DEFAULT 0, notes TEXT NULL,
  created_by INT NOT NULL, validated_at DATETIME NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_supplier_invoice_number (user_id,supplier_id,invoice_number),
  KEY idx_supplier_invoice_due (user_id,status,due_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS erp_supplier_invoice_items (
  id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, supplier_invoice_id INT NOT NULL,
  supplier_reception_item_id INT NULL, product_id INT NULL, description VARCHAR(255) NOT NULL,
  quantity DECIMAL(20,3) NOT NULL, unit_price DECIMAL(20,3) NOT NULL,
  vat_rate DECIMAL(10,3) NOT NULL DEFAULT 0, total_ht DECIMAL(20,3) NOT NULL,
  total_vat DECIMAL(20,3) NOT NULL, total_ttc DECIMAL(20,3) NOT NULL,
  CONSTRAINT fk_supplier_invoice_item FOREIGN KEY (supplier_invoice_id) REFERENCES erp_supplier_invoices(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS erp_supplier_payments (
  id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, user_id INT NOT NULL, supplier_invoice_id INT NOT NULL,
  amount DECIMAL(20,3) NOT NULL, payment_date DATE NOT NULL,
  method ENUM('CASH','CHEQUE','BANK_TRANSFER','CARD','DRAFT','OTHER') NOT NULL,
  account VARCHAR(160) NOT NULL, reference_number VARCHAR(160) NULL, proof_path VARCHAR(500) NULL,
  recorded_by INT NOT NULL, voided_at DATETIME NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_supplier_payment_invoice (supplier_invoice_id),
  CONSTRAINT fk_supplier_payment_invoice FOREIGN KEY (supplier_invoice_id) REFERENCES erp_supplier_invoices(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS erp_supplier_returns (
  id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, user_id INT NOT NULL, supplier_id INT NOT NULL,
  supplier_reception_id INT NOT NULL, return_date DATE NOT NULL,
  status ENUM('DRAFT','CONFIRMED','CANCELLED') NOT NULL DEFAULT 'DRAFT', reason VARCHAR(255) NOT NULL,
  stock_applied TINYINT(1) NOT NULL DEFAULT 0, confirmed_at DATETIME NULL,
  created_by INT NOT NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS erp_supplier_return_items (
  id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, supplier_return_id INT NOT NULL,
  supplier_reception_item_id INT NOT NULL, product_id INT NOT NULL, quantity DECIMAL(20,3) NOT NULL,
  unit_cost DECIMAL(20,6) NOT NULL DEFAULT 0, lot_number VARCHAR(100) NULL, serial_number VARCHAR(150) NULL,
  CONSTRAINT fk_supplier_return_item FOREIGN KEY (supplier_return_id) REFERENCES erp_supplier_returns(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS erp_supplier_credit_notes (
  id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, user_id INT NOT NULL, supplier_invoice_id INT NOT NULL,
  supplier_return_id INT NULL, credit_number VARCHAR(100) NOT NULL, credit_date DATE NOT NULL,
  amount DECIMAL(20,3) NOT NULL, status ENUM('DRAFT','VALIDATED','CANCELLED') NOT NULL DEFAULT 'DRAFT',
  notes TEXT NULL, created_by INT NOT NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_supplier_credit_number (user_id,credit_number)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS erp_inventory_adjustments (
  id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, user_id INT NOT NULL, product_id INT NOT NULL,
  quantity_delta DECIMAL(15,3) NOT NULL, reason_code VARCHAR(40) NOT NULL, reason_detail VARCHAR(255) NOT NULL,
  lot_number VARCHAR(100) NULL, serial_number VARCHAR(150) NULL,
  created_by INT NOT NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_inventory_adjustment_product (user_id,product_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

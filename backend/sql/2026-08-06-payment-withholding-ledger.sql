ALTER TABLE erp_invoices
    ADD COLUMN source_invoice_id INT NULL AFTER delivery_note_id,
    ADD KEY idx_invoice_source_invoice (source_invoice_id);

CREATE TABLE IF NOT EXISTS erp_invoice_payments (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    invoice_id INT NOT NULL,
    user_id INT NOT NULL,
    amount DECIMAL(15,3) NOT NULL,
    payment_date DATE NOT NULL,
    method VARCHAR(24) NOT NULL,
    account_name VARCHAR(120) NOT NULL DEFAULT '',
    reference_number VARCHAR(120) NOT NULL DEFAULT '',
    proof_path VARCHAR(500) NULL,
    proof_name VARCHAR(255) NULL,
    proof_mime VARCHAR(120) NULL,
    status ENUM('POSTED','VOID') NOT NULL DEFAULT 'POSTED',
    recorded_by INT NOT NULL,
    voided_by INT NULL,
    voided_at DATETIME NULL,
    void_reason VARCHAR(255) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_payment_invoice_status (invoice_id,status,payment_date),
    KEY idx_payment_company (user_id,payment_date),
    CONSTRAINT fk_payment_invoice FOREIGN KEY (invoice_id) REFERENCES erp_invoices(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS erp_invoice_withholdings (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    invoice_id INT NOT NULL,
    user_id INT NOT NULL,
    withholding_type VARCHAR(40) NOT NULL,
    rate DECIMAL(8,4) NOT NULL,
    calculation_base DECIMAL(15,3) NOT NULL,
    withheld_amount DECIMAL(15,3) NOT NULL,
    certificate_number VARCHAR(120) NOT NULL DEFAULT '',
    certificate_date DATE NULL,
    certificate_status ENUM('PENDING','RECEIVED','VALIDATED','CANCELLED') NOT NULL DEFAULT 'PENDING',
    attachment_path VARCHAR(500) NULL,
    attachment_name VARCHAR(255) NULL,
    attachment_mime VARCHAR(120) NULL,
    recorded_by INT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_withholding_invoice_status (invoice_id,certificate_status),
    KEY idx_withholding_company (user_id,certificate_date),
    CONSTRAINT fk_withholding_invoice FOREIGN KEY (invoice_id) REFERENCES erp_invoices(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

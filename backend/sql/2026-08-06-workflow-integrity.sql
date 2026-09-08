UPDATE erp_invoices SET transformation_status='PARTIALLY_ORDERED' WHERE transformation_status='PARTIALLY_INVOICED';
UPDATE erp_invoices SET transformation_status='FULLY_ORDERED' WHERE transformation_status='FULLY_INVOICED';
ALTER TABLE erp_invoices ADD COLUMN idempotency_key VARCHAR(64) NULL, ADD UNIQUE KEY uq_invoice_idempotency(user_id,idempotency_key);
ALTER TABLE erp_sales_orders ADD COLUMN idempotency_key VARCHAR(64) NULL, ADD UNIQUE KEY uq_order_idempotency(user_id,idempotency_key);
ALTER TABLE erp_delivery_notes ADD COLUMN idempotency_key VARCHAR(64) NULL, ADD UNIQUE KEY uq_delivery_idempotency(user_id,idempotency_key);

CREATE TABLE IF NOT EXISTS erp_einvoice_outbox (
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, invoice_id INT NOT NULL, user_id INT NOT NULL,
 format_version VARCHAR(40) NOT NULL, payload_json LONGTEXT NOT NULL, payload_sha256 CHAR(64) NOT NULL,
 signature_value LONGTEXT NULL, certificate_thumbprint VARCHAR(128) NULL,
 status ENUM('SIGNATURE_REQUIRED','SIGNED','QUEUED','SUBMITTED','ACCEPTED','REJECTED','RETRY_PENDING') NOT NULL DEFAULT 'SIGNATURE_REQUIRED',
 provider_identifier VARCHAR(190) NULL, attempt_count INT UNSIGNED NOT NULL DEFAULT 0,
 last_attempt_at DATETIME NULL, last_error_code VARCHAR(80) NULL, last_error_message TEXT NULL,
 created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 PRIMARY KEY(id), UNIQUE KEY uq_einvoice_invoice(invoice_id), UNIQUE KEY uq_einvoice_hash(user_id,payload_sha256), KEY idx_einvoice_outbox(user_id,status,updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

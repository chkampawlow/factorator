-- Tenant-scoped, stable references for customers and suppliers.
-- Existing rows are numbered by creation id within each tenant.

CREATE TABLE IF NOT EXISTS erp_entity_reference_sequences (
    user_id INT NOT NULL,
    entity_type ENUM('CLIENT', 'SUPPLIER') NOT NULL,
    next_number INT UNSIGNED NOT NULL DEFAULT 1,
    PRIMARY KEY (user_id, entity_type),
    CONSTRAINT fk_entity_reference_sequence_user
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE clients ADD COLUMN reference VARCHAR(7) NULL AFTER id;

CREATE TEMPORARY TABLE tmp_client_references AS
SELECT id, CONCAT('C', LPAD(ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY id), 6, '0')) reference
FROM clients;

UPDATE clients c
JOIN tmp_client_references generated ON generated.id = c.id
SET c.reference = generated.reference
WHERE c.reference IS NULL OR c.reference = '';

DROP TEMPORARY TABLE tmp_client_references;

ALTER TABLE clients MODIFY reference VARCHAR(7) NOT NULL;
ALTER TABLE clients ADD UNIQUE KEY uq_clients_user_reference (user_id, reference);

-- The old supplier index made references global. References now belong to a tenant.
ALTER TABLE suppliers DROP INDEX uq_suppliers_reference;
ALTER TABLE suppliers MODIFY reference VARCHAR(7) NULL;

CREATE TEMPORARY TABLE tmp_supplier_references AS
SELECT id, CONCAT('F', LPAD(ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY id), 6, '0')) reference
FROM suppliers;

UPDATE suppliers s
JOIN tmp_supplier_references generated ON generated.id = s.id
SET s.reference = generated.reference;

DROP TEMPORARY TABLE tmp_supplier_references;

ALTER TABLE suppliers MODIFY reference VARCHAR(7) NOT NULL;
ALTER TABLE suppliers ADD UNIQUE KEY uq_suppliers_user_reference (user_id, reference);

INSERT INTO erp_entity_reference_sequences (user_id, entity_type, next_number)
SELECT user_id, 'CLIENT', COUNT(*) + 1 FROM clients GROUP BY user_id
ON DUPLICATE KEY UPDATE next_number = VALUES(next_number);

INSERT INTO erp_entity_reference_sequences (user_id, entity_type, next_number)
SELECT user_id, 'SUPPLIER', COUNT(*) + 1 FROM suppliers GROUP BY user_id
ON DUPLICATE KEY UPDATE next_number = VALUES(next_number);

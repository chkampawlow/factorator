ALTER TABLE erp_invoices
ADD COLUMN is_validated TINYINT(1) NOT NULL DEFAULT 0 AFTER status;

UPDATE erp_invoices
SET is_validated = 1,
    status = 'UNPAID'
WHERE status = 'VALIDATED';

ALTER TABLE erp_invoices
MODIFY COLUMN status ENUM('DRAFT', 'UNPAID', 'PAID', 'CANCELLED')
NOT NULL DEFAULT 'UNPAID';

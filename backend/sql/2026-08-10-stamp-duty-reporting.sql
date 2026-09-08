ALTER TABLE erp_supplier_invoices
    ADD COLUMN stamp_duty DECIMAL(20,3) NOT NULL DEFAULT 0 AFTER total_tax_tnd,
    ADD COLUMN stamp_duty_tnd DECIMAL(20,3) NOT NULL DEFAULT 0 AFTER stamp_duty,
    ADD CONSTRAINT chk_supplier_invoice_stamp_duty CHECK(stamp_duty>=0 AND stamp_duty_tnd>=0);

UPDATE erp_supplier_invoices SET stamp_duty_tnd=ROUND(stamp_duty*exchange_rate,3);

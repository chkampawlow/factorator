-- Replace the legacy global invoice-number constraint with a company-scoped one.
ALTER TABLE erp_invoices
    DROP INDEX uq_invoice,
    ADD UNIQUE KEY uq_invoice_user_number (user_id, invoice);

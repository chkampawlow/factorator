ALTER TABLE products
    ADD COLUMN IF NOT EXISTS category VARCHAR(120) NULL AFTER name;

ALTER TABLE erp_invoices
    ADD COLUMN IF NOT EXISTS salesperson_name VARCHAR(191) NULL AFTER custom_code;

CREATE INDEX IF NOT EXISTS idx_products_company_category ON products(user_id, category, id);
CREATE INDEX IF NOT EXISTS idx_invoice_company_salesperson_date ON erp_invoices(user_id, salesperson_name, invoice_date, id);

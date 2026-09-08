-- Composite indexes for tenant-scoped document lists and workflow joins.
CREATE INDEX IF NOT EXISTS idx_invoice_company_status_date ON erp_invoices(user_id,status,invoice_date,id);
CREATE INDEX IF NOT EXISTS idx_invoice_company_type_date ON erp_invoices(user_id,invoice_type,invoice_date,id);
CREATE INDEX IF NOT EXISTS idx_invoice_company_due ON erp_invoices(user_id,invoice_due_date,status);
CREATE INDEX IF NOT EXISTS idx_invoice_company_source_order ON erp_invoices(user_id,sales_order_id);
CREATE INDEX IF NOT EXISTS idx_invoice_company_source_delivery ON erp_invoices(user_id,delivery_note_id);
CREATE INDEX IF NOT EXISTS idx_invoice_company_source_invoice ON erp_invoices(user_id,source_invoice_id);
CREATE INDEX IF NOT EXISTS idx_invoice_item_invoice_product ON erp_invoice_items(invoice_id,product_id);

CREATE INDEX IF NOT EXISTS idx_order_company_status_date ON erp_sales_orders(user_id,status,order_date,id);
CREATE INDEX IF NOT EXISTS idx_order_company_number ON erp_sales_orders(user_id,order_number);
CREATE INDEX IF NOT EXISTS idx_order_company_devis ON erp_sales_orders(user_id,source_devis_id);
CREATE INDEX IF NOT EXISTS idx_order_item_order_product ON erp_sales_order_items(sales_order_id,product_id);

CREATE INDEX IF NOT EXISTS idx_delivery_company_status_date ON erp_delivery_notes(user_id,status,delivery_date,id);
CREATE INDEX IF NOT EXISTS idx_delivery_company_number ON erp_delivery_notes(user_id,delivery_number);
CREATE INDEX IF NOT EXISTS idx_delivery_company_order ON erp_delivery_notes(user_id,sales_order_id);
CREATE INDEX IF NOT EXISTS idx_delivery_item_delivery_product ON erp_delivery_note_items(delivery_note_id,product_id);

CREATE INDEX IF NOT EXISTS idx_supplier_order_company_status_date ON erp_supplier_orders(user_id,status,order_date,id);
CREATE INDEX IF NOT EXISTS idx_supplier_order_company_number ON erp_supplier_orders(user_id,order_number);
CREATE INDEX IF NOT EXISTS idx_supplier_order_company_supplier ON erp_supplier_orders(user_id,supplier_id);
CREATE INDEX IF NOT EXISTS idx_supplier_order_item_order_catalog ON erp_supplier_order_items(supplier_order_id,catalog_id);

CREATE INDEX IF NOT EXISTS idx_reception_company_status_date ON erp_supplier_receptions(user_id,status,received_date,id);
CREATE INDEX IF NOT EXISTS idx_reception_company_order ON erp_supplier_receptions(user_id,supplier_order_id);
CREATE INDEX IF NOT EXISTS idx_reception_company_supplier ON erp_supplier_receptions(user_id,supplier_id);
CREATE INDEX IF NOT EXISTS idx_reception_item_reception_catalog ON erp_supplier_reception_items(supplier_reception_id,catalog_id);

CREATE INDEX IF NOT EXISTS idx_supplier_invoice_company_status_date ON erp_supplier_invoices(user_id,status,invoice_date,id);
CREATE INDEX IF NOT EXISTS idx_supplier_invoice_company_due ON erp_supplier_invoices(user_id,due_date,status);
CREATE INDEX IF NOT EXISTS idx_supplier_invoice_company_order ON erp_supplier_invoices(user_id,supplier_order_id);
CREATE INDEX IF NOT EXISTS idx_supplier_invoice_item_invoice_product ON erp_supplier_invoice_items(supplier_invoice_id,product_id);

CREATE INDEX IF NOT EXISTS idx_product_company_code ON products(user_id,code);
CREATE INDEX IF NOT EXISTS idx_product_company_name ON products(user_id,name);
CREATE INDEX IF NOT EXISTS idx_client_company_name ON clients(user_id,name);
CREATE INDEX IF NOT EXISTS idx_supplier_company_name ON suppliers(user_id,name);
CREATE INDEX IF NOT EXISTS idx_stock_company_date ON product_stock_movements(user_id,created_at,id);
CREATE INDEX IF NOT EXISTS idx_stock_company_reference ON product_stock_movements(user_id,reference_type,reference_id);

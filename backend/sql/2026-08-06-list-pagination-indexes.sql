CREATE INDEX IF NOT EXISTS idx_clients_company_created ON clients(user_id,id);
CREATE INDEX IF NOT EXISTS idx_suppliers_company_created ON suppliers(user_id,id);
CREATE INDEX IF NOT EXISTS idx_products_company_type_created ON products(user_id,item_type,id);
CREATE INDEX IF NOT EXISTS idx_products_company_type_stock ON products(user_id,item_type,stock_quantity);
CREATE INDEX IF NOT EXISTS idx_expenses_company_date_created ON expense_notes(user_id,expense_date,id);
CREATE INDEX IF NOT EXISTS idx_supplier_orders_company_status_created ON erp_supplier_orders(user_id,status,id);
CREATE INDEX IF NOT EXISTS idx_supplier_receptions_company_status_created ON erp_supplier_receptions(user_id,status,id);
CREATE INDEX IF NOT EXISTS idx_stock_history_product_company_date ON product_stock_movements(product_id,user_id,created_at,id);

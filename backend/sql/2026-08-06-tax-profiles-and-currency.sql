CREATE TABLE IF NOT EXISTS erp_tax_profiles (
 id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,user_id INT NOT NULL,name VARCHAR(160) NOT NULL,
 vat_rate DECIMAL(10,6) NOT NULL DEFAULT 0,vat_exempt TINYINT(1) NOT NULL DEFAULT 0,
 fodec_applicable TINYINT(1) NOT NULL DEFAULT 0,fodec_rate DECIMAL(10,6) NOT NULL DEFAULT 0,
 tax_regime ENUM('STANDARD','SUSPENDED','EXEMPT') NOT NULL DEFAULT 'STANDARD',legal_basis VARCHAR(255) NULL,
 certificate_reference VARCHAR(160) NULL,effective_from DATE NOT NULL,effective_to DATE NULL,
 created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,UNIQUE KEY uq_tax_profile_name_period(user_id,name,effective_from)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
ALTER TABLE products ADD COLUMN IF NOT EXISTS tax_profile_id INT NULL AFTER item_type;
ALTER TABLE erp_invoices ADD COLUMN IF NOT EXISTS tax_profile_id INT NULL AFTER source_flow,
 ADD COLUMN IF NOT EXISTS currency CHAR(3) NOT NULL DEFAULT 'TND' AFTER invoice_due_date,
 ADD COLUMN IF NOT EXISTS exchange_rate DECIMAL(20,8) NOT NULL DEFAULT 1 AFTER currency,
 ADD COLUMN IF NOT EXISTS exchange_rate_date DATE NULL AFTER exchange_rate,
 ADD COLUMN IF NOT EXISTS subtotal_tnd DECIMAL(20,3) NOT NULL DEFAULT 0 AFTER subtotal,
 ADD COLUMN IF NOT EXISTS tax_total_tnd DECIMAL(20,3) NOT NULL DEFAULT 0 AFTER montant_tva,
 ADD COLUMN IF NOT EXISTS total_tnd DECIMAL(20,3) NOT NULL DEFAULT 0 AFTER total;
ALTER TABLE erp_invoice_items ADD COLUMN IF NOT EXISTS tax_profile_id INT NULL AFTER product_id,
 ADD COLUMN IF NOT EXISTS tax_regime VARCHAR(20) NOT NULL DEFAULT 'STANDARD' AFTER tva_rate,
 ADD COLUMN IF NOT EXISTS fodec_rate DECIMAL(10,6) NOT NULL DEFAULT 0 AFTER tax_regime,
 ADD COLUMN IF NOT EXISTS fodec_amount DECIMAL(20,3) NOT NULL DEFAULT 0 AFTER fodec_rate,
 ADD COLUMN IF NOT EXISTS legal_basis VARCHAR(255) NULL AFTER fodec_amount,
 ADD COLUMN IF NOT EXISTS certificate_reference VARCHAR(160) NULL AFTER legal_basis,
 ADD COLUMN IF NOT EXISTS subtotal_tnd DECIMAL(20,3) NOT NULL DEFAULT 0 AFTER subtotal,
 ADD COLUMN IF NOT EXISTS tax_tnd DECIMAL(20,3) NOT NULL DEFAULT 0 AFTER montant_tva,
 ADD COLUMN IF NOT EXISTS total_tnd DECIMAL(20,3) NOT NULL DEFAULT 0 AFTER subtotalTTC;

-- Convert legacy VAT rates into explicit dated product profiles. The old company FODEC switch is intentionally ignored.
INSERT IGNORE INTO erp_tax_profiles(user_id,name,vat_rate,vat_exempt,fodec_applicable,fodec_rate,tax_regime,effective_from)
SELECT DISTINCT user_id,CONCAT('TVA ',CAST(tva_rate AS CHAR),'%'),tva_rate,IF(tva_rate=0,1,0),0,0,IF(tva_rate=0,'EXEMPT','STANDARD'),'2000-01-01' FROM products;
UPDATE products p JOIN erp_tax_profiles tp ON tp.user_id=p.user_id AND tp.vat_rate=p.tva_rate AND tp.effective_from='2000-01-01'
SET p.tax_profile_id=tp.id WHERE p.tax_profile_id IS NULL;

ALTER TABLE erp_supplier_invoices ADD COLUMN IF NOT EXISTS tax_profile_id INT NULL AFTER supplier_order_id,
 ADD COLUMN IF NOT EXISTS exchange_rate DECIMAL(20,8) NOT NULL DEFAULT 1 AFTER currency,
 ADD COLUMN IF NOT EXISTS exchange_rate_date DATE NULL AFTER exchange_rate,
 ADD COLUMN IF NOT EXISTS total_ht_tnd DECIMAL(20,3) NOT NULL DEFAULT 0 AFTER total_ht,
 ADD COLUMN IF NOT EXISTS total_tax_tnd DECIMAL(20,3) NOT NULL DEFAULT 0 AFTER total_vat,
 ADD COLUMN IF NOT EXISTS total_ttc_tnd DECIMAL(20,3) NOT NULL DEFAULT 0 AFTER total_ttc;
ALTER TABLE erp_supplier_invoice_items ADD COLUMN IF NOT EXISTS tax_profile_id INT NULL AFTER product_id,
 ADD COLUMN IF NOT EXISTS fodec_rate DECIMAL(10,6) NOT NULL DEFAULT 0 AFTER vat_rate,
 ADD COLUMN IF NOT EXISTS fodec_amount DECIMAL(20,3) NOT NULL DEFAULT 0 AFTER fodec_rate,
 ADD COLUMN IF NOT EXISTS tax_regime VARCHAR(20) NOT NULL DEFAULT 'STANDARD' AFTER fodec_amount,
 ADD COLUMN IF NOT EXISTS legal_basis VARCHAR(255) NULL AFTER tax_regime,
 ADD COLUMN IF NOT EXISTS certificate_reference VARCHAR(160) NULL AFTER legal_basis,
 ADD COLUMN IF NOT EXISTS total_ht_tnd DECIMAL(20,3) NOT NULL DEFAULT 0 AFTER total_ht,
 ADD COLUMN IF NOT EXISTS total_tax_tnd DECIMAL(20,3) NOT NULL DEFAULT 0 AFTER total_vat,
 ADD COLUMN IF NOT EXISTS total_ttc_tnd DECIMAL(20,3) NOT NULL DEFAULT 0 AFTER total_ttc;

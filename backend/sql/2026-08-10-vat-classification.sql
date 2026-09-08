ALTER TABLE erp_tax_profiles
    MODIFY tax_regime ENUM('STANDARD','SUSPENDED','EXEMPT','OUT_OF_SCOPE') NOT NULL DEFAULT 'STANDARD',
    ADD COLUMN deductibility_rate DECIMAL(10,3) NOT NULL DEFAULT 100.000 AFTER tax_regime,
    ADD CONSTRAINT chk_tax_profile_deductibility CHECK(deductibility_rate BETWEEN 0 AND 100);

ALTER TABLE erp_supplier_invoice_items
    ADD COLUMN deductibility_rate DECIMAL(10,3) NOT NULL DEFAULT 100.000 AFTER tax_regime,
    ADD COLUMN deductible_vat_tnd DECIMAL(20,3) NOT NULL DEFAULT 0 AFTER total_vat,
    ADD COLUMN non_deductible_vat_tnd DECIMAL(20,3) NOT NULL DEFAULT 0 AFTER deductible_vat_tnd,
    ADD CONSTRAINT chk_supplier_item_deductibility CHECK(deductibility_rate BETWEEN 0 AND 100),
    ADD CONSTRAINT chk_supplier_item_vat_buckets CHECK(deductible_vat_tnd>=0 AND non_deductible_vat_tnd>=0);

UPDATE erp_tax_profiles SET deductibility_rate=0 WHERE tax_regime<>'STANDARD';

UPDATE erp_supplier_invoice_items sii
JOIN erp_supplier_invoices si ON si.id=sii.supplier_invoice_id
LEFT JOIN erp_tax_profiles tp ON tp.id=sii.tax_profile_id
SET sii.deductibility_rate=CASE WHEN sii.tax_regime='STANDARD' THEN COALESCE(tp.deductibility_rate,100) ELSE 0 END,
    sii.deductible_vat_tnd=ROUND(sii.total_vat*si.exchange_rate*(CASE WHEN sii.tax_regime='STANDARD' THEN COALESCE(tp.deductibility_rate,100) ELSE 0 END)/100,3),
    sii.non_deductible_vat_tnd=ROUND(sii.total_vat*si.exchange_rate,3)-ROUND(sii.total_vat*si.exchange_rate*(CASE WHEN sii.tax_regime='STANDARD' THEN COALESCE(tp.deductibility_rate,100) ELSE 0 END)/100,3);

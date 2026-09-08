ALTER TABLE erp_invoice_withholdings
    ADD COLUMN expected_certificate_date DATE NULL AFTER certificate_date,
    ADD COLUMN received_at DATETIME NULL AFTER certificate_status,
    ADD COLUMN validated_at DATETIME NULL AFTER received_at,
    ADD COLUMN cancelled_at DATETIME NULL AFTER validated_at,
    ADD COLUMN validation_notes VARCHAR(500) NULL AFTER cancelled_at,
    ADD KEY idx_withholding_expected(user_id,certificate_status,expected_certificate_date),
    ADD KEY idx_withholding_certificate_number(user_id,certificate_number);

UPDATE erp_invoice_withholdings
SET received_at=CASE WHEN certificate_status IN('RECEIVED','VALIDATED') THEN updated_at ELSE NULL END,
    validated_at=CASE WHEN certificate_status='VALIDATED' THEN updated_at ELSE NULL END,
    cancelled_at=CASE WHEN certificate_status='CANCELLED' THEN updated_at ELSE NULL END;

ALTER TABLE erp_invoice_payments
  ADD COLUMN IF NOT EXISTS exchange_rate DECIMAL(20,8) NULL AFTER amount,
  ADD COLUMN IF NOT EXISTS exchange_rate_date DATE NULL AFTER exchange_rate,
  ADD COLUMN IF NOT EXISTS amount_tnd DECIMAL(20,3) NULL AFTER exchange_rate_date;

ALTER TABLE erp_supplier_payments
  ADD COLUMN IF NOT EXISTS exchange_rate DECIMAL(20,8) NULL AFTER amount,
  ADD COLUMN IF NOT EXISTS exchange_rate_date DATE NULL AFTER exchange_rate,
  ADD COLUMN IF NOT EXISTS amount_tnd DECIMAL(20,3) NULL AFTER exchange_rate_date;

UPDATE erp_invoice_payments p
JOIN erp_invoices i ON i.id=p.invoice_id AND i.user_id=p.user_id
SET p.exchange_rate=1,
    p.exchange_rate_date=p.payment_date,
    p.amount_tnd=ROUND(p.amount,3)
WHERE i.currency='TND' AND (p.exchange_rate IS NULL OR p.amount_tnd IS NULL);

UPDATE erp_supplier_payments p
JOIN erp_supplier_invoices i ON i.id=p.supplier_invoice_id AND i.user_id=p.user_id
SET p.exchange_rate=1,
    p.exchange_rate_date=p.payment_date,
    p.amount_tnd=ROUND(p.amount,3)
WHERE i.currency='TND' AND (p.exchange_rate IS NULL OR p.amount_tnd IS NULL);

ALTER TABLE erp_invoice_payments
  ADD KEY IF NOT EXISTS idx_customer_payment_fx_period (user_id,payment_date,status,exchange_rate),
  ADD CONSTRAINT chk_customer_payment_exchange_rate CHECK (exchange_rate IS NULL OR exchange_rate>0),
  ADD CONSTRAINT chk_customer_payment_tnd CHECK (amount_tnd IS NULL OR amount_tnd>0);

ALTER TABLE erp_supplier_payments
  ADD KEY IF NOT EXISTS idx_supplier_payment_fx_period (user_id,payment_date,voided_at,exchange_rate),
  ADD CONSTRAINT chk_supplier_payment_exchange_rate CHECK (exchange_rate IS NULL OR exchange_rate>0),
  ADD CONSTRAINT chk_supplier_payment_tnd CHECK (amount_tnd IS NULL OR amount_tnd>0);

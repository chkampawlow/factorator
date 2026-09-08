-- Immutable supplier-reception confirmation metadata used by the atomic
-- reception -> stock -> purchase-order -> expense workflow.
ALTER TABLE erp_supplier_receptions
  ADD COLUMN IF NOT EXISTS confirmed_at DATETIME NULL AFTER stock_applied_at,
  ADD COLUMN IF NOT EXISTS confirmed_by INT NULL AFTER confirmed_at,
  ADD COLUMN IF NOT EXISTS confirmation_hash CHAR(64) NULL AFTER confirmed_by;

CREATE INDEX IF NOT EXISTS idx_supplier_reception_confirmation
  ON erp_supplier_receptions(user_id, confirmed_at, confirmed_by);

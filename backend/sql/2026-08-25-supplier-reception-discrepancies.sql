-- Supplier delivery evidence, controlled exceptions, and per-line discrepancy
-- quantities for the supplier-reception workflow.
ALTER TABLE erp_supplier_receptions
  ADD COLUMN IF NOT EXISTS supplier_delivery_note_number VARCHAR(120) NULL AFTER invoice_number,
  ADD COLUMN IF NOT EXISTS supplier_delivery_note_date DATE NULL AFTER supplier_delivery_note_number,
  ADD COLUMN IF NOT EXISTS exception_type ENUM('NONE','OVERDELIVERY','NO_ORDER') NOT NULL DEFAULT 'NONE' AFTER notes,
  ADD COLUMN IF NOT EXISTS exception_reason TEXT NULL AFTER exception_type,
  ADD COLUMN IF NOT EXISTS discrepancy_attachment_path VARCHAR(500) NULL AFTER exception_reason,
  ADD COLUMN IF NOT EXISTS discrepancy_attachment_name VARCHAR(255) NULL AFTER discrepancy_attachment_path,
  ADD COLUMN IF NOT EXISTS discrepancy_attachment_mime VARCHAR(120) NULL AFTER discrepancy_attachment_name;

ALTER TABLE erp_supplier_reception_items
  ADD COLUMN IF NOT EXISTS ordered_qty DECIMAL(20,3) NOT NULL DEFAULT 0.000 AFTER item_type,
  ADD COLUMN IF NOT EXISTS accepted_qty DECIMAL(20,3) NOT NULL DEFAULT 0.000 AFTER qty,
  ADD COLUMN IF NOT EXISTS damaged_qty DECIMAL(20,3) NOT NULL DEFAULT 0.000 AFTER accepted_qty,
  ADD COLUMN IF NOT EXISTS rejected_qty DECIMAL(20,3) NOT NULL DEFAULT 0.000 AFTER damaged_qty,
  ADD COLUMN IF NOT EXISTS discrepancy_reason VARCHAR(500) NULL AFTER rejected_qty;

-- Existing confirmed receptions predate discrepancy capture; their complete
-- quantity was accepted into stock.
UPDATE erp_supplier_reception_items
SET accepted_qty = qty,
    ordered_qty = CASE WHEN ordered_qty > 0 THEN ordered_qty ELSE qty END
WHERE accepted_qty = 0 AND damaged_qty = 0 AND rejected_qty = 0;


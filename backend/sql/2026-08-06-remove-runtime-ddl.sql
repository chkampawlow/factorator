ALTER TABLE expense_notes
 ADD COLUMN IF NOT EXISTS supplier_id INT NULL AFTER user_id,
 ADD COLUMN IF NOT EXISTS source_document_type VARCHAR(50) NULL AFTER receipt_path,
 ADD COLUMN IF NOT EXISTS source_document_id INT NULL AFTER source_document_type,
 ADD COLUMN IF NOT EXISTS source_document_number VARCHAR(100) NULL AFTER source_document_id;
CREATE INDEX IF NOT EXISTS idx_expense_company_status_date ON expense_notes(user_id,status,expense_date,id);
CREATE INDEX IF NOT EXISTS idx_expense_company_source ON expense_notes(user_id,source_document_type,source_document_id);

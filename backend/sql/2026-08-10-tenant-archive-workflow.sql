ALTER TABLE users
    ADD COLUMN IF NOT EXISTS account_status ENUM('ACTIVE','ARCHIVED') NOT NULL DEFAULT 'ACTIVE' AFTER role,
    ADD COLUMN IF NOT EXISTS archived_at DATETIME NULL AFTER account_status,
    ADD COLUMN IF NOT EXISTS archived_by INT NULL AFTER archived_at,
    ADD COLUMN IF NOT EXISTS archive_reason VARCHAR(500) NULL AFTER archived_by;

CREATE INDEX IF NOT EXISTS idx_users_account_status ON users(account_status,id);

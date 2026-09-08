ALTER TABLE users
    MODIFY COLUMN account_status ENUM('PENDING','ACTIVE','ARCHIVED') NOT NULL DEFAULT 'PENDING',
    ADD COLUMN IF NOT EXISTS approved_at DATETIME NULL AFTER account_status;

UPDATE users
SET approved_at = COALESCE(approved_at, created_at)
WHERE account_status IN ('ACTIVE', 'ARCHIVED');

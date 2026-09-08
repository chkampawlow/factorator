ALTER TABLE erp_accounting_periods MODIFY status ENUM('OPEN','CLOSED','DRAFT','REVIEWED','LOCKED','FILED') NOT NULL DEFAULT 'DRAFT';
UPDATE erp_accounting_periods SET status=CASE status WHEN 'OPEN' THEN 'DRAFT' WHEN 'CLOSED' THEN 'LOCKED' ELSE status END;
ALTER TABLE erp_accounting_periods
    MODIFY status ENUM('DRAFT','REVIEWED','LOCKED','FILED') NOT NULL DEFAULT 'DRAFT',
    ADD COLUMN reviewed_by INT NULL AFTER status,ADD COLUMN reviewed_at DATETIME NULL AFTER reviewed_by,
    ADD COLUMN locked_by INT NULL AFTER reviewed_at,ADD COLUMN locked_at DATETIME NULL AFTER locked_by,
    ADD COLUMN filed_by INT NULL AFTER locked_at,ADD COLUMN filed_at DATETIME NULL AFTER filed_by;
UPDATE erp_accounting_periods SET reviewed_by=closed_by,reviewed_at=closed_at,locked_by=closed_by,locked_at=closed_at WHERE status='LOCKED';

CREATE TABLE erp_accounting_period_snapshots (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,period_id BIGINT UNSIGNED NOT NULL,user_id INT NOT NULL,version INT UNSIGNED NOT NULL,
    status ENUM('DRAFT','REVIEWED','LOCKED','FILED') NOT NULL,snapshot_json LONGTEXT NOT NULL,snapshot_sha256 CHAR(64) NOT NULL,
    captured_by INT NOT NULL,captured_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY(id),UNIQUE KEY uq_accounting_period_snapshot(period_id,version),KEY idx_accounting_period_snapshot(user_id,status,captured_at),
    CONSTRAINT fk_accounting_period_snapshot FOREIGN KEY(period_id) REFERENCES erp_accounting_periods(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO erp_accounting_period_snapshots(period_id,user_id,version,status,snapshot_json,snapshot_sha256,captured_by,captured_at)
SELECT id,user_id,1,status,
    JSON_OBJECT('period',JSON_OBJECT('from',period_start,'to',period_end),'status',status,'legacy_migration',TRUE),
    SHA2(JSON_OBJECT('period',JSON_OBJECT('from',period_start,'to',period_end),'status',status,'legacy_migration',TRUE),256),
    COALESCE(locked_by,user_id),COALESCE(locked_at,created_at)
FROM erp_accounting_periods;

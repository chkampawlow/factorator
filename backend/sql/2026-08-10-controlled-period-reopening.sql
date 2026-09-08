ALTER TABLE erp_filing_archives
    DROP INDEX uq_filing_archive,
    ADD COLUMN filing_sequence INT UNSIGNED NOT NULL DEFAULT 1 AFTER source_entity_id,
    ADD UNIQUE KEY uq_filing_archive_sequence(user_id,declaration_type,source_entity_id,filing_sequence);

CREATE TABLE erp_period_reopenings (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,user_id INT NOT NULL,
    period_type ENUM('VAT','ACCOUNTING_PERIOD') NOT NULL,period_id BIGINT UNSIGNED NOT NULL,
    previous_status ENUM('LOCKED','FILED') NOT NULL,reopened_status ENUM('REVIEWED') NOT NULL DEFAULT 'REVIEWED',
    reason VARCHAR(1000) NOT NULL,prior_snapshot_sha256 CHAR(64) NULL,prior_filing_archive_id BIGINT UNSIGNED NULL,
    reopened_by INT NOT NULL,reopened_by_role VARCHAR(40) NOT NULL,reopened_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY(id),KEY idx_period_reopening(user_id,period_type,period_id,id),
    CONSTRAINT fk_reopening_archive FOREIGN KEY(prior_filing_archive_id) REFERENCES erp_filing_archives(id),
    CONSTRAINT chk_reopening_reason CHECK(CHAR_LENGTH(reason)>=20)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TRIGGER trg_period_reopening_no_update BEFORE UPDATE ON erp_period_reopenings FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Period reopening history is immutable';
CREATE TRIGGER trg_period_reopening_no_delete BEFORE DELETE ON erp_period_reopenings FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Period reopening history is immutable';

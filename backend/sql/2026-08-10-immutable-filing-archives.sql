CREATE TABLE erp_filing_archives (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,user_id INT NOT NULL,
    declaration_type ENUM('VAT','ACCOUNTING_PERIOD') NOT NULL,source_entity_id BIGINT UNSIGNED NOT NULL,
    period_start DATE NOT NULL,period_end DATE NOT NULL,report_version VARCHAR(40) NOT NULL,
    source_json LONGTEXT NOT NULL,result_json LONGTEXT NOT NULL,source_sha256 CHAR(64) NOT NULL,result_sha256 CHAR(64) NOT NULL,archive_sha256 CHAR(64) NOT NULL,
    source_row_count INT UNSIGNED NOT NULL,captured_by INT NOT NULL,captured_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY(id),UNIQUE KEY uq_filing_archive(user_id,declaration_type,source_entity_id),KEY idx_filing_archive_period(user_id,declaration_type,period_end),
    CONSTRAINT chk_filing_archive_rows CHECK(source_row_count>=0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TRIGGER trg_filing_archive_no_update BEFORE UPDATE ON erp_filing_archives FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Filing archives are immutable';
CREATE TRIGGER trg_filing_archive_no_delete BEFORE DELETE ON erp_filing_archives FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Filing archives are immutable';

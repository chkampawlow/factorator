CREATE TABLE erp_tax_schedule_entries (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,user_id INT NOT NULL,fiscal_year SMALLINT UNSIGNED NOT NULL,
    schedule_type ENUM('DEPRECIATION','PROVISION','DONATION','SUBSIDY') NOT NULL,reference VARCHAR(120) NOT NULL,
    description VARCHAR(255) NOT NULL,event_date DATE NOT NULL,beneficiary VARCHAR(255) NULL,
    gross_amount DECIMAL(20,3) NOT NULL,opening_book_value DECIMAL(20,3) NULL,annual_rate DECIMAL(10,6) NULL,
    accounting_amount DECIMAL(20,3) NOT NULL,fiscal_amount DECIMAL(20,3) NOT NULL,
    fiscal_addition DECIMAL(20,3) NOT NULL,fiscal_deduction DECIMAL(20,3) NOT NULL,closing_book_value DECIMAL(20,3) NULL,
    timing ENUM('PERMANENT','TEMPORARY') NOT NULL,legal_basis VARCHAR(255) NOT NULL,evidence_reference VARCHAR(255) NULL,notes VARCHAR(500) NULL,
    status ENUM('DRAFT','REVIEWED','CANCELLED') NOT NULL DEFAULT 'DRAFT',created_by INT NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY(id),UNIQUE KEY uq_tax_schedule_entry(user_id,fiscal_year,schedule_type,reference),KEY idx_tax_schedule_year(user_id,fiscal_year,schedule_type,status),
    CONSTRAINT chk_tax_schedule_year CHECK(fiscal_year BETWEEN 2000 AND 2200),
    CONSTRAINT chk_tax_schedule_amounts CHECK(gross_amount>=0 AND accounting_amount>=0 AND fiscal_amount>=0 AND fiscal_addition>=0 AND fiscal_deduction>=0 AND(opening_book_value IS NULL OR opening_book_value>=0)AND(closing_book_value IS NULL OR closing_book_value>=0)AND(annual_rate IS NULL OR annual_rate BETWEEN 0 AND 100))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

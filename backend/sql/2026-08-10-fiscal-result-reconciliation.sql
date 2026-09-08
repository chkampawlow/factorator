CREATE TABLE erp_fiscal_reconciliations (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,user_id INT NOT NULL,fiscal_year SMALLINT UNSIGNED NOT NULL,
    accounting_result DECIMAL(20,3) NOT NULL,accounting_source ENUM('OPERATIONAL_LEDGER','MANUAL_STATUTORY_ACCOUNTS') NOT NULL DEFAULT 'OPERATIONAL_LEDGER',
    status ENUM('DRAFT','REVIEWED','LOCKED','FILED') NOT NULL DEFAULT 'DRAFT',notes VARCHAR(500) NULL,
    reviewed_by INT NULL,reviewed_at DATETIME NULL,locked_by INT NULL,locked_at DATETIME NULL,filed_by INT NULL,filed_at DATETIME NULL,
    created_by INT NOT NULL,created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY(id),UNIQUE KEY uq_fiscal_reconciliation(user_id,fiscal_year),KEY idx_fiscal_reconciliation_status(user_id,status,fiscal_year),
    CONSTRAINT chk_fiscal_reconciliation_year CHECK(fiscal_year BETWEEN 2000 AND 2200)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE erp_fiscal_adjustments (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,reconciliation_id BIGINT UNSIGNED NOT NULL,user_id INT NOT NULL,
    adjustment_type ENUM('ADDITION','DEDUCTION') NOT NULL,timing ENUM('PERMANENT','TEMPORARY') NOT NULL,
    category VARCHAR(120) NOT NULL,description VARCHAR(255) NOT NULL,amount DECIMAL(20,3) NOT NULL,legal_basis VARCHAR(255) NOT NULL,notes VARCHAR(500) NULL,
    created_by INT NOT NULL,created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY(id),KEY idx_fiscal_adjustments(reconciliation_id,adjustment_type,category),
    CONSTRAINT fk_fiscal_adjustment_reconciliation FOREIGN KEY(reconciliation_id) REFERENCES erp_fiscal_reconciliations(id),
    CONSTRAINT chk_fiscal_adjustment_amount CHECK(amount>0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

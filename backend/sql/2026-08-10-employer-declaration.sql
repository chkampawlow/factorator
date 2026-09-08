CREATE TABLE erp_employer_declarations (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,user_id INT NOT NULL,declaration_year SMALLINT UNSIGNED NOT NULL,
    status ENUM('DRAFT','REVIEWED','LOCKED','FILED') NOT NULL DEFAULT 'DRAFT',notes VARCHAR(500) NULL,
    reviewed_by INT NULL,reviewed_at DATETIME NULL,locked_by INT NULL,locked_at DATETIME NULL,filed_by INT NULL,filed_at DATETIME NULL,
    created_by INT NOT NULL,created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY(id),UNIQUE KEY uq_employer_declaration(user_id,declaration_year),KEY idx_employer_declaration_status(user_id,status,declaration_year),
    CONSTRAINT chk_employer_declaration_year CHECK(declaration_year BETWEEN 2000 AND 2200)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE erp_employer_declaration_lines (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,declaration_id BIGINT UNSIGNED NOT NULL,user_id INT NOT NULL,
    category ENUM('SUPPLIER','PAYROLL','OTHER') NOT NULL,beneficiary_name VARCHAR(255) NOT NULL,beneficiary_fiscal_id VARCHAR(60) NULL,
    gross_amount DECIMAL(20,3) NOT NULL,withheld_amount DECIMAL(20,3) NOT NULL,source_supplier_payment_id INT NULL,notes VARCHAR(500) NULL,
    created_by INT NOT NULL,created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY(id),UNIQUE KEY uq_employer_declaration_source(user_id,source_supplier_payment_id),KEY idx_employer_declaration_lines(declaration_id,category),
    CONSTRAINT fk_employer_line_declaration FOREIGN KEY(declaration_id) REFERENCES erp_employer_declarations(id),
    CONSTRAINT fk_employer_line_supplier_payment FOREIGN KEY(source_supplier_payment_id) REFERENCES erp_supplier_payments(id),
    CONSTRAINT chk_employer_line_amounts CHECK(gross_amount>=0 AND withheld_amount>=0 AND withheld_amount<=gross_amount)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

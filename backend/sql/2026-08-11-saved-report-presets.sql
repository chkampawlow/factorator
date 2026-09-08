CREATE TABLE erp_report_presets (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id INT NOT NULL,
    name VARCHAR(80) NOT NULL,
    period_kind ENUM('CUSTOM','CURRENT_MONTH','PREVIOUS_MONTH','CURRENT_QUARTER','CURRENT_YEAR','PREVIOUS_YEAR','LAST_30_DAYS') NOT NULL DEFAULT 'CUSTOM',
    date_from DATE NULL,
    date_to DATE NULL,
    created_by INT NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_report_preset_name (user_id,name),
    KEY idx_report_preset_tenant (user_id,updated_at,id),
    CONSTRAINT chk_report_preset_dates CHECK (
        (period_kind='CUSTOM' AND date_from IS NOT NULL AND date_to IS NOT NULL AND date_to>=date_from)
        OR (period_kind<>'CUSTOM' AND date_from IS NULL AND date_to IS NULL)
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

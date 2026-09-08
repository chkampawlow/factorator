CREATE TABLE IF NOT EXISTS erp_platform_settings (
    setting_key VARCHAR(100) NOT NULL,
    setting_value VARCHAR(255) NOT NULL,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (setting_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO erp_platform_settings (setting_key, setting_value)
VALUES ('new_user_approval_required', '1')
ON DUPLICATE KEY UPDATE setting_key = VALUES(setting_key);


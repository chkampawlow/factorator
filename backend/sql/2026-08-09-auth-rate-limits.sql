CREATE TABLE IF NOT EXISTS auth_rate_limits (
    key_hash CHAR(64) NOT NULL PRIMARY KEY,
    action_name VARCHAR(64) NOT NULL,
    subject_hash CHAR(64) NOT NULL,
    attempts INT UNSIGNED NOT NULL DEFAULT 0,
    window_started_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    INDEX idx_auth_rate_limits_cleanup (updated_at),
    INDEX idx_auth_rate_limits_action (action_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

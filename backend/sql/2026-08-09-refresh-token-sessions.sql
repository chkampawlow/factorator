CREATE TABLE IF NOT EXISTS auth_refresh_tokens (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    token_hash CHAR(64) NOT NULL UNIQUE,
    expires_at DATETIME NOT NULL,
    revoked_at DATETIME NULL,
    replaced_by_hash CHAR(64) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_used_at DATETIME NULL,
    user_agent_hash CHAR(64) NOT NULL,
    ip_hash CHAR(64) NOT NULL,
    INDEX idx_refresh_user_active (user_id, revoked_at, expires_at),
    INDEX idx_refresh_cleanup (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

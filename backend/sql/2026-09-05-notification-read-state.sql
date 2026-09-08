CREATE TABLE IF NOT EXISTS erp_notification_reads (
    tenant_id INT NOT NULL,
    actor_id INT NOT NULL,
    notification_key VARCHAR(191) NOT NULL,
    read_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (tenant_id, actor_id, notification_key),
    KEY idx_notification_reads_actor (actor_id, tenant_id, read_at),
    KEY idx_notification_reads_cleanup (updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

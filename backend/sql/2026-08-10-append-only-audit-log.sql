CREATE TABLE IF NOT EXISTS app_audit_log (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    tenant_id INT NULL,
    actor_id INT NULL,
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(80) NOT NULL,
    entity_id VARCHAR(100) NULL,
    before_values JSON NULL,
    after_values JSON NULL,
    request_id CHAR(36) NOT NULL,
    source VARCHAR(40) NOT NULL DEFAULT 'API',
    source_ip_hash CHAR(64) NULL,
    user_agent VARCHAR(255) NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    KEY idx_audit_tenant_created (tenant_id, created_at, id),
    KEY idx_audit_actor_created (actor_id, created_at, id),
    KEY idx_audit_entity (tenant_id, entity_type, entity_id, created_at),
    KEY idx_audit_request (request_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TRIGGER IF EXISTS app_audit_log_no_update;
DROP TRIGGER IF EXISTS app_audit_log_no_delete;

DELIMITER //
CREATE TRIGGER app_audit_log_no_update
BEFORE UPDATE ON app_audit_log
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Audit records are immutable';
END//

CREATE TRIGGER app_audit_log_no_delete
BEFORE DELETE ON app_audit_log
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Audit records are append-only';
END//
DELIMITER ;

INSERT INTO app_audit_log
    (tenant_id,actor_id,action,entity_type,entity_id,request_id,source,after_values)
SELECT NULL,NULL,'SYSTEM.AUDIT_ENABLED','SYSTEM','AUDIT_LOG',UUID(),'MIGRATION',
       JSON_OBJECT('append_only',TRUE,'schema_version','2026-08-10')
WHERE NOT EXISTS (
    SELECT 1 FROM app_audit_log
    WHERE action='SYSTEM.AUDIT_ENABLED' AND entity_id='AUDIT_LOG'
);

CREATE TABLE erp_accountant_review_events (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,user_id INT NOT NULL,
    entity_type ENUM('VAT_PERIOD','ACCOUNTING_PERIOD','CONTRIBUTION_PERIOD','EMPLOYER_DECLARATION','FISCAL_RECONCILIATION','TAX_SCHEDULE_ENTRY','FILING_ARCHIVE') NOT NULL,
    entity_id BIGINT UNSIGNED NOT NULL,action ENUM('NOTE','REQUEST_CHANGES','APPROVE','REJECT') NOT NULL,
    note VARCHAR(2000) NOT NULL,actor_id INT NOT NULL,actor_role VARCHAR(40) NOT NULL,
    previous_event_hash CHAR(64) NULL,event_hash CHAR(64) NOT NULL,created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY(id),KEY idx_accountant_review_entity(user_id,entity_type,entity_id,id),KEY idx_accountant_review_action(user_id,action,created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TRIGGER trg_accountant_review_no_update BEFORE UPDATE ON erp_accountant_review_events FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Accountant review history is immutable';
CREATE TRIGGER trg_accountant_review_no_delete BEFORE DELETE ON erp_accountant_review_events FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Accountant review history is immutable';

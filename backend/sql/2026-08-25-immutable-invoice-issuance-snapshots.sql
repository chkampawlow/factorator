CREATE TABLE IF NOT EXISTS erp_invoice_issuance_snapshots (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    invoice_id INT NOT NULL,
    user_id INT NOT NULL,
    document_type ENUM('FACTURE','DEVIS','AVOIR') NOT NULL,
    snapshot_version SMALLINT UNSIGNED NOT NULL DEFAULT 1,
    snapshot_json LONGTEXT NOT NULL,
    snapshot_sha256 CHAR(64) NOT NULL,
    captured_by INT NULL,
    captured_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_invoice_issuance_snapshot (invoice_id),
    KEY idx_invoice_snapshot_tenant (user_id, document_type, captured_at),
    KEY idx_invoice_snapshot_hash (snapshot_sha256),
    CONSTRAINT fk_invoice_snapshot_invoice
        FOREIGN KEY (invoice_id) REFERENCES erp_invoices(id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_invoice_snapshot_actor
        FOREIGN KEY (captured_by) REFERENCES users(id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT chk_invoice_snapshot_json CHECK (JSON_VALID(snapshot_json))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TRIGGER IF EXISTS trg_invoice_snapshot_no_update;
CREATE TRIGGER trg_invoice_snapshot_no_update BEFORE UPDATE ON erp_invoice_issuance_snapshots FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Invoice issuance snapshots are immutable';

DROP TRIGGER IF EXISTS trg_invoice_snapshot_no_delete;
CREATE TRIGGER trg_invoice_snapshot_no_delete BEFORE DELETE ON erp_invoice_issuance_snapshots FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Invoice issuance snapshots are immutable';

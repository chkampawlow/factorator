ALTER TABLE users
    ADD COLUMN IF NOT EXISTS display_name VARCHAR(191) NULL AFTER id,
    ADD COLUMN IF NOT EXISTS default_company_id INT NULL AFTER role,
    MODIFY fiscal_id VARCHAR(20) NULL;

UPDATE users
SET display_name = COALESCE(
    NULLIF(TRIM(display_name), ''),
    NULLIF(TRIM(organization_name), ''),
    SUBSTRING_INDEX(email, '@', 1)
)
WHERE display_name IS NULL OR TRIM(display_name) = '';

CREATE TABLE IF NOT EXISTS companies (
    id INT NOT NULL AUTO_INCREMENT,
    owner_user_id INT NOT NULL,
    organization_name VARCHAR(191) NOT NULL,
    fiscal_id VARCHAR(20) NULL,
    phone VARCHAR(30) NULL,
    fax VARCHAR(50) NULL,
    address VARCHAR(255) NULL,
    website VARCHAR(255) NULL,
    fodec TINYINT(1) NOT NULL DEFAULT 0,
    status ENUM('ACTIVE','ARCHIVED') NOT NULL DEFAULT 'ACTIVE',
    archived_at DATETIME NULL,
    archived_by INT NULL,
    archive_reason VARCHAR(500) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_companies_owner (owner_user_id),
    UNIQUE KEY uq_companies_fiscal_id (fiscal_id),
    KEY idx_companies_status (status, id),
    CONSTRAINT fk_companies_owner
        FOREIGN KEY (owner_user_id) REFERENCES users(id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS company_memberships (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    company_id INT NOT NULL,
    user_id INT NOT NULL,
    role ENUM('ADMINISTRATOR','COMMERCIAL','STOCK','ACCOUNTING') NOT NULL,
    status ENUM('ACTIVE','SUSPENDED','REVOKED') NOT NULL DEFAULT 'ACTIVE',
    is_owner TINYINT(1) NOT NULL DEFAULT 0,
    version INT UNSIGNED NOT NULL DEFAULT 1,
    invited_by INT NULL,
    joined_at DATETIME NULL,
    suspended_at DATETIME NULL,
    revoked_at DATETIME NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_company_membership (company_id, user_id),
    KEY idx_membership_user_status (user_id, status, company_id),
    KEY idx_membership_company_role (company_id, status, role, id),
    CONSTRAINT fk_membership_company
        FOREIGN KEY (company_id) REFERENCES companies(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_membership_user
        FOREIGN KEY (user_id) REFERENCES users(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_membership_inviter
        FOREIGN KEY (invited_by) REFERENCES users(id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS company_invitations (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    company_id INT NOT NULL,
    email VARCHAR(191) NOT NULL,
    display_name VARCHAR(191) NULL,
    role ENUM('ADMINISTRATOR','COMMERCIAL','STOCK','ACCOUNTING') NOT NULL,
    status ENUM('PENDING','ACCEPTED','REVOKED','EXPIRED') NOT NULL DEFAULT 'PENDING',
    token_hash CHAR(64) NOT NULL,
    invited_by INT NOT NULL,
    expires_at DATETIME NOT NULL,
    accepted_by INT NULL,
    accepted_at DATETIME NULL,
    revoked_at DATETIME NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_company_invitation_token (token_hash),
    KEY idx_invitation_company_status (company_id, status, expires_at),
    KEY idx_invitation_email_status (email, status, expires_at),
    CONSTRAINT fk_invitation_company
        FOREIGN KEY (company_id) REFERENCES companies(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_invitation_inviter
        FOREIGN KEY (invited_by) REFERENCES users(id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_invitation_acceptor
        FOREIGN KEY (accepted_by) REFERENCES users(id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Keep each legacy tenant identifier stable: the new company ID deliberately
-- equals its existing owner user ID. Existing business rows can therefore keep
-- using user_id during the staged tenant_id migration without changing scope.
INSERT INTO companies (
    id,
    owner_user_id,
    organization_name,
    fiscal_id,
    phone,
    fax,
    address,
    website,
    fodec,
    status,
    archived_at,
    archived_by,
    archive_reason,
    created_at,
    updated_at
)
SELECT
    u.id,
    u.id,
    COALESCE(NULLIF(TRIM(u.organization_name), ''), CONCAT('Workspace ', u.id)),
    NULLIF(TRIM(u.fiscal_id), ''),
    NULLIF(TRIM(u.phone), ''),
    NULLIF(TRIM(u.fax), ''),
    NULLIF(TRIM(u.address), ''),
    NULLIF(TRIM(u.website), ''),
    IFNULL(u.fodec, 0),
    CASE WHEN u.account_status = 'ARCHIVED' THEN 'ARCHIVED' ELSE 'ACTIVE' END,
    u.archived_at,
    u.archived_by,
    u.archive_reason,
    u.created_at,
    u.updated_at
FROM users u
LEFT JOIN companies c ON c.id = u.id
WHERE c.id IS NULL;

INSERT INTO company_memberships (
    company_id,
    user_id,
    role,
    status,
    is_owner,
    joined_at,
    created_at,
    updated_at
)
SELECT
    u.id,
    u.id,
    CASE
        WHEN u.role IN ('ADMINISTRATOR','COMMERCIAL','STOCK','ACCOUNTING') THEN u.role
        ELSE 'ADMINISTRATOR'
    END,
    CASE WHEN u.account_status = 'ACTIVE' THEN 'ACTIVE' ELSE 'SUSPENDED' END,
    1,
    u.created_at,
    u.created_at,
    u.updated_at
FROM users u
LEFT JOIN company_memberships cm
    ON cm.company_id = u.id AND cm.user_id = u.id
WHERE cm.id IS NULL;

UPDATE users u
JOIN company_memberships cm
    ON cm.user_id = u.id AND cm.is_owner = 1
SET u.default_company_id = cm.company_id
WHERE u.default_company_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_users_default_company
    ON users(default_company_id, id);

ALTER TABLE auth_refresh_tokens
    ADD COLUMN IF NOT EXISTS company_id INT NULL AFTER user_id,
    ADD COLUMN IF NOT EXISTS membership_id BIGINT UNSIGNED NULL AFTER company_id;

CREATE INDEX IF NOT EXISTS idx_refresh_membership_active
    ON auth_refresh_tokens(company_id, membership_id, revoked_at, expires_at);

UPDATE auth_refresh_tokens rt
JOIN company_memberships cm
    ON cm.user_id = rt.user_id AND cm.is_owner = 1
SET rt.company_id = cm.company_id,
    rt.membership_id = cm.id
WHERE rt.company_id IS NULL OR rt.membership_id IS NULL;

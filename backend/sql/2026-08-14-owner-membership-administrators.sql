-- A company owner is the recovery authority for membership and company
-- settings. Legacy account roles described an operator, not a workspace
-- membership, so every owner membership must start as an administrator.
UPDATE auth_refresh_tokens rt
JOIN company_memberships cm
  ON cm.id = rt.membership_id
 AND cm.company_id = rt.company_id
SET rt.revoked_at = COALESCE(rt.revoked_at, NOW())
WHERE cm.is_owner = 1
  AND cm.role <> 'ADMINISTRATOR';

UPDATE company_memberships
SET role = 'ADMINISTRATOR',
    version = version + 1
WHERE is_owner = 1
  AND role <> 'ADMINISTRATOR';

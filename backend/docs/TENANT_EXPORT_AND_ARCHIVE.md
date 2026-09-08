# Company data export and archive

`GET /user/export_tenant_data.php` is restricted to the company administrator. It
returns a ZIP containing a manifest, tenant-owned business datasets as JSON, and the
tenant's accounting attachments. Password hashes, 2FA secrets, session/token hashes,
idempotency fingerprints, and internal attachment paths are excluded.

`POST /user/archive_tenant.php` preserves all legal, financial, stock, and audit
records while disabling login and revoking refresh sessions. It requires:

```json
{
  "password": "current administrator password",
  "reason": "A closure reason of at least ten characters",
  "confirmation": "ARCHIVE MY COMPANY",
  "export_acknowledged": true
}
```

The administrator should download and verify the export before acknowledging it.
Archival is intentionally not deletion and there is no self-service reactivation.
Reactivation requires an authorized support/administrative process with identity
verification and a new append-only audit record.

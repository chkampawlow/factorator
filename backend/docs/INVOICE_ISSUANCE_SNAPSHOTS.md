# Immutable invoice issuance snapshots

When a `FACTURE`, `DEVIS` or `AVOIR` becomes issued, the backend stores one canonical JSON snapshot in `erp_invoice_issuance_snapshots`. The snapshot freezes the official number, dates, currency, totals, line descriptions and tax data, seller and buyer identities, salesperson label, and authenticated issuer identity.

The JSON is hashed with SHA-256. Database triggers reject updates and deletes, while the foreign key prevents deleting the issued source invoice. Official server PDFs and electronic-invoice preparation verify the hash and reconstruct identity, lines and totals from this snapshot instead of mutable company, client, user or product records.

Deployment order:

1. Run `php backend/bin/migrate.php`.
2. Run `php backend/bin/backfill_invoice_issuance_snapshots.php` once to freeze currently issued legacy documents.
3. Run `php backend/bin/verify_invoice_issuance_snapshots.php` and the document PDF regression test.

The backfill preserves the best data currently available. It cannot reconstruct identity values that were already changed before this feature was deployed.

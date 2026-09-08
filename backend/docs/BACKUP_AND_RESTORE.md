# Encrypted backup and restore runbook

## Policy

- Create a daily encrypted backup and retain the newest 14 daily sets.
- Create a weekly encrypted backup and retain the newest 8 weekly sets.
- Set `BACKUP_OFFSITE_DIR` to a separately mounted, access-controlled remote volume.
- Keep `BACKUP_ENCRYPTION_KEY` outside source control and outside the backup location.
- Alert on `BACKUP.FAILED`; periodically confirm `BACKUP.COMPLETED` events.
- Test restoration at least quarterly and after database or attachment-layout changes.

Each completed set contains encrypted database and attachment artifacts, SHA-256
checksums, an HMAC-signed manifest, and a `COMPLETE` marker. Incomplete directories
must never be copied off-site or restored.

## Scheduling

```cron
15 2 * * 1-6 /usr/bin/php /path/to/backend/bin/backup.php --tier=daily
15 2 * * 0   /usr/bin/php /path/to/backend/bin/backup.php --tier=weekly
```

## Restore drill

Never restore over the live database. The restore command only accepts a new database
whose name contains `_restore_test_` and refuses an existing target. Use a new empty
attachment target as well.

```bash
php bin/restore_backup.php \
  --backup=/secure/backups/el-fatoura-weekly-YYYYMMDDTHHMMSSZ-ID \
  --target-db=facturation_restore_test_YYYYMMDD \
  --attachments-target=/secure/restore-test/attachments
```

The command verifies the manifest HMAC, both encrypted artifact checksums, successful
decryption, database import, and critical row counts. Review representative invoices,
payments, stock history, audit records, and attachments before deleting the isolated
test database and directory.

The current XAMPP installation has an outdated `mysql.proc` system table. Run the
vendor-supported `mysql_upgrade` during a maintenance window before relying on stored
routines. El Fatoura currently uses no stored routines; application backups include
tables, data, views, and triggers.

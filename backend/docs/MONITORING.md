# Error monitoring and uptime

Monitoring is an operations integration, not an Angular feature. Keep the alert
receiver outside the El Fatoura server so it can still report a complete server
outage.

Use `/health/live.php` to verify that PHP is serving requests. Use
`/health/ready.php` for uptime monitoring; it returns HTTP 503 unless the database,
critical schema, and structured-log destination are available. Responses deliberately
exclude database names, paths, credentials, and exception text.

Set `ERROR_MONITOR_WEBHOOK_URL` to an HTTPS receiver to forward redacted ERROR and
CRITICAL events. Set `ERROR_MONITOR_WEBHOOK_SECRET` to sign each JSON body using the
`X-El-Fatoura-Signature: sha256=...` header. Alert delivery uses an 800 ms hard timeout,
does not follow redirects, and never blocks application success or error handling.

Set `UPTIME_READY_URL` to the deployed readiness URL. Run this every minute:

```cron
* * * * * /usr/bin/php /path/to/backend/bin/check_uptime.php >> /var/log/el-fatoura-uptime.log 2>&1
```

An external uptime provider should also probe readiness from outside the server and
alert after two consecutive failures. Never point monitoring at an authenticated or
data-returning business endpoint.

## Production integration

1. Create an HTTPS webhook receiver in the monitoring or incident-management service.
   It must accept JSON and verify `X-El-Fatoura-Signature` using the configured secret.
2. Set these values only in the deployed `backend/.env`:

   ```dotenv
   ERROR_MONITOR_WEBHOOK_URL=https://external-monitor.example/events
   ERROR_MONITOR_WEBHOOK_SECRET=generate-a-random-secret-of-at-least-32-characters
   UPTIME_READY_URL=https://your-domain.example/backend/health/ready.php
   ```

3. Configure an external HTTP monitor for `UPTIME_READY_URL` every minute. Alert after
   two consecutive non-200 responses and send recovery notifications as well.
4. Install the local cron check shown above. This records readiness failures in the
   structured application log and forwards them to the webhook while PHP is running.
5. Schedule encrypted daily/weekly backups using `BACKUP_AND_RESTORE.md`. A
   `BACKUP.FAILED` event is CRITICAL and uses the same webhook.
6. Complete `INCIDENT_RESPONSE.md` with named primary and backup owners, escalation
   contacts and acknowledgement targets.

## Acceptance test

Notify the incident contact, then run from the backend directory:

```bash
php bin/send_monitoring_test.php --send
```

The command succeeds only when the HTTPS receiver accepts the signed event. Record the
test request ID, receiver timestamp, notification timestamp, owner acknowledgement and
recovery notification. Do not close EF-025 until the external readiness probe and the
test alert both reach the named owner.

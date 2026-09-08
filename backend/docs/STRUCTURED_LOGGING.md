# Structured server logging

The web backend writes one JSON object per line to `storage/logs/app.jsonl` by default;
CLI jobs use `storage/logs/app-cli.jsonl` so Apache and scheduled jobs can keep strict
per-owner `0600` file permissions.
Every record includes the UTC timestamp, severity, event, request ID, HTTP method,
endpoint path, tenant/actor IDs, and redacted context.

Passwords, tokens, 2FA material, email addresses, phone numbers, addresses, fiscal
identifiers, CIN values, IP addresses, user agents, proof paths, and attachment paths
must never be logged. The central logger redacts these keys and masks bearer tokens
and email addresses embedded in messages.

Set `APP_LOG_PATH` to an absolute path outside the web root in production. Set
`APP_LOG_MAX_BYTES` to control local rotation (minimum 1 MiB). The web-accessible
fallback storage directory is protected by `.htaccess`.

# Incident response

Complete this file for the production environment. Do not store personal phone numbers,
webhook URLs, credentials or secrets in Git; reference the protected operations contact
directory instead.

## Ownership

| Responsibility | Named owner or protected contact reference | Target |
|---|---|---|
| Primary incident owner | To be assigned | Acknowledge critical alerts within 15 minutes |
| Backup incident owner | To be assigned | Take over after 15 minutes without acknowledgement |
| Deployment owner | To be assigned | Stop deployments and provide the deployed revision |
| Database/backup owner | To be assigned | Protect evidence and lead restore decisions |
| Business contact | To be assigned | Approve customer communication and operational workarounds |

## Severity

| Severity | Examples | Initial action |
|---|---|---|
| SEV-1 | Application unavailable, database unavailable, suspected breach or data corruption | Acknowledge immediately, stop risky changes, preserve logs and escalate |
| SEV-2 | Repeated HTTP 5xx, failed backups, email/document delivery outage or blocked core workflow | Assign an owner, contain the failure and provide status updates |
| SEV-3 | Isolated recoverable defect with a safe workaround | Record, prioritize and monitor for recurrence |

## Response procedure

1. Acknowledge the alert through the configured monitoring channel.
2. Record UTC start time, event name, request ID, affected environment and current owner.
3. Check `/backend/health/live.php`, then `/backend/health/ready.php`.
4. Correlate the request ID in the server dashboard and private structured logs.
5. Stop deployments and avoid destructive SQL while impact is unknown.
6. Contain the incident using a documented reversible action or rollback procedure.
7. Verify recovery from outside the server and confirm the readiness monitor recovers.
8. Record the root cause, affected records, corrective changes and follow-up tests.

## Evidence log

| UTC time | Environment | Severity | Event/request ID | Owner | Alert received | Acknowledged | Recovered | Follow-up |
|---|---|---|---|---|---|---|---|---|
| - | - | - | - | - | - | - | - | - |


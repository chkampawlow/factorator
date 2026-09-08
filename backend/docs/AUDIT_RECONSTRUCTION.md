# Audit reconstruction

`GET /reports/audit_entity_timeline.php?entity_type=...&entity_id=...` returns a
tenant-scoped, chronological lifecycle for one audited entity. The backend replays
each event's `after_values` and verifies that the next event's `before_values` agree
with the reconstructed state. A mismatch is returned as a path-specific continuity
issue rather than silently producing an unreliable result.

Run `php bin/verify_audit_reconstruction.php` during release verification. It creates
three synthetic payment lifecycle events inside a transaction, confirms the final
state, proves a deliberately broken chain is detected, checks production coverage for
critical action groups, and rolls the transaction back. No test audit events remain.

Reconstruction applies to events recorded after the append-only audit migration.
Legacy transactions created before that migration cannot acquire reliable historical
actor/request metadata retroactively and should be treated as imported opening data.

# Controlled period reopening

Locked accounting or VAT periods may be reopened to Reviewed only through a dedicated endpoint and a reason of at least 20 characters. Reopening a Filed period requires an Administrator.

The append-only reopening record preserves the previous status, reason, actor and role, prior snapshot hash, and prior filing archive where applicable. Accounting reopening immediately captures a new Reviewed snapshot. The original filing archive remains immutable.

After corrections, the normal Reviewed → Locked → Filed workflow applies again. Filing archives carry a sequence number, so refiling creates a new immutable archive without replacing the earlier filing. Reopening events themselves cannot be updated or deleted.

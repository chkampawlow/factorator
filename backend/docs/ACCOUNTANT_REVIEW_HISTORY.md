# Accountant review notes and approvals

Reviews are append-only events attached to VAT periods, accounting periods, contribution periods, employer declarations, fiscal reconciliations, tax-schedule entries, or filing archives. Actions are Note, Request changes, Approve, and Reject.

Every event records the actor, actor-role snapshot, timestamp, note, previous-event hash, and its own SHA-256 hash. This creates a separate verifiable chain for each reviewed entity. Database triggers reject updates and deletes; corrections are new review events.

An approval records professional review but does not by itself change a declaration or accounting-period status. Status transitions remain separate controlled actions and filing readiness still requires the appropriate accountant validation.

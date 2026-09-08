# Accounting-period snapshots

Accounting periods follow `DRAFT → REVIEWED → LOCKED → FILED`. Repeating Draft or Reviewed is allowed to capture a fresh version; transitions cannot move backwards. Locked and filed periods block invoice creation or validation in their date range.

Every save captures a versioned JSON snapshot of period sales, purchases, customer and supplier payments, expenses, and stock/COGS aggregates. Each snapshot has a SHA-256 digest and records its actor and timestamp. Snapshots are append-only.

The aggregate snapshot establishes period state and change detection. Exact declaration-specific source rows and results are preserved by the separate filing archive workflow. No controlled reopening is enabled yet; a locked/filed period remains immutable.

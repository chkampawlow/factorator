# Immutable filing archives

When a VAT or accounting period moves from Locked to Filed, the same database transaction captures the exact source rows and final calculated/header result. The archive records its report version, actor, timestamp, source-row count, source hash, result hash, and combined archive hash.

VAT archives include validated invoices, credit notes and their lines, non-cancelled supplier invoices and their lines, and the opening-credit source period. Accounting-period archives include invoices and lines, purchases and lines, payments, withholding certificates, expenses, stock movements, and the complete snapshot history.

Database triggers reject archive updates and deletes. The archive-list endpoint returns metadata, while an ID lookup returns decoded source and result payloads. Archives may contain sensitive accounting data and remain tenant-scoped.

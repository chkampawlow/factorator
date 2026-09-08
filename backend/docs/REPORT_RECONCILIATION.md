# Cross-report reconciliation

The master reconciliation independently checks sales and credit-note headers against their lines, posted supplier invoices against purchase lines, VAT deductible/non-deductible buckets, customer and supplier settlement limits, recognized expenses, and tenant ownership across report sources.

Accounting reports use only posted supplier invoices (`VALIDATED`, `PARTIALLY_PAID`, or `PAID`) and recognized expense notes (`APPROVED` or `REIMBURSED`). Draft supplier documents and pending/rejected expenses remain operational records but do not enter tax or profitability totals.

This master check complements the dedicated VAT, FODEC, stamp-duty, stock, withholding, snapshot, archive, and review-chain verifiers. A zero-discrepancy technical reconciliation does not replace independent accountant validation of legal classification or filing treatment.

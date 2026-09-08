# Withholding-tax register and certificates

Each withholding record snapshots its configurable type, rate, calculation base, calculated amount, related invoice, and certificate lifecycle.

Lifecycle: `PENDING → RECEIVED → VALIDATED`; any active record may be cancelled. Received and validated certificates require a number and date. The register also tracks an optional expected date, attachment presence, received/validated/cancelled timestamps, notes, and the recording user.

Reports group records by type and status and identify overdue expected certificates, missing attachments, formula mismatches, and duplicate active certificate numbers. The CSV register uses the invoice period so pending certificates are not omitted merely because they have no certificate date.

Only received or validated amounts reduce invoice balances. Applicable withholding types, rates, bases, and certificate obligations must be validated by the company's Tunisian accountant.

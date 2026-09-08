# VAT credit carry-forward

VAT periods are monthly snapshots with `DRAFT`, `REVIEWED`, `LOCKED`, and `FILED`
states. The first period may accept a manually verified opening VAT credit. Every
later period inherits the closing credit from the latest reviewed, locked, or filed
predecessor; inherited opening credit cannot be overridden.

Formula in TND:

- Available credit = opening credit + deductible VAT.
- VAT payable = max(collected VAT − available credit, 0).
- Closing VAT credit = max(available credit − collected VAT, 0).

Payable VAT and closing VAT credit cannot both be positive. Collected VAT includes
validated invoices and subtracts validated credit notes. Deductible VAT uses supplier
invoice VAT converted with the stored invoice exchange rate. FODEC is not included as
VAT.

Use `POST /reports/save_vat_period.php` with `month`, optional `opening_credit`, and
`status`. Use `GET /reports/vat_periods.php` for the saved ledger. These calculations
support preparation and review; filing remains subject to validation by the company's
Tunisian accountant.

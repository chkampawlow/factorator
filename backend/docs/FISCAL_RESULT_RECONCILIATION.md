# Fiscal-result reconciliation

The bridge starts from an accounting-result snapshot and applies documented tax additions and deductions to obtain a provisional taxable result. Adjustments record timing (`PERMANENT` or `TEMPORARY`), category, description, amount, and legal basis.

The default starting result is explicitly `OPERATIONAL_LEDGER`: validated net sales minus inventory COGS movements minus non-cancelled expense notes. It is not a substitute for a statutory general ledger, accruals, payroll, depreciation, or closing entries. The report displays any difference between the saved snapshot and the current operational result.

The CSV export preserves the bridge lines. A Tunisian accountant must replace or validate the starting accounting result, tax treatment, legal basis, and taxable result before filing.

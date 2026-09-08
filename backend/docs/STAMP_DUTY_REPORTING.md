# Stamp-duty reporting and reconciliation

Stamp duty is stored as a document-level amount in the document currency and reported in TND using the exchange rate saved on that document.

- Validated sales invoices add stamp duty.
- Validated sales credit notes reverse it in the report.
- Supplier invoices may record an optional `stamp_duty`; it is added to TTC but not to VAT or FODEC totals.
- The report exposes issued, credited, purchase, and net TND amounts.
- The CSV export is available as `report=stamp-duty`.

The verifier reconciles source/TND stamp values and recomposes document totals from lines plus stamp duty. Applicability and the statutory amount must be confirmed by the company's Tunisian accountant before filing.

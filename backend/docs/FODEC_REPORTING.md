# FODEC reporting and reconciliation

FODEC is calculated line by line on the net amount before VAT. VAT is then calculated on the net amount plus FODEC. Reports convert FODEC to TND using the exchange rate stored on the document.

The report separates sales from purchases, groups each side by FODEC rate, and applies a negative sign to validated credit notes. Its reconciliation checks verify:

- line FODEC equals the rounded net line amount multiplied by its stored FODEC rate;
- each document's TND tax total equals the sum of its line tax totals;
- FODEC is not included in the VAT-only collected or deductible fields.

The CSV export is available as `report=fodec`. Filing treatment and applicable products/rates must be confirmed by the company's Tunisian accountant.

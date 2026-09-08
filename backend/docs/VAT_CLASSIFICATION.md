# VAT classification

VAT reports classify lines from their stored tax regime; a zero rate is never used to guess a regime.

- `STANDARD` sales contribute to collected VAT.
- `EXEMPT`, `SUSPENDED`, and `OUT_OF_SCOPE` sales are reported as separate taxable-base buckets with zero VAT.
- Purchase lines snapshot a deductibility percentage and explicit deductible/non-deductible VAT amounts in TND.
- VAT-period payable and carry-forward calculations use deductible VAT only.
- FODEC remains outside the VAT amount and is handled by its own reconciliation report.

Tax profiles require a legal basis or reference for non-standard regimes. These categories and formulas must be validated by the company's Tunisian accountant before a declaration is treated as filing-ready.

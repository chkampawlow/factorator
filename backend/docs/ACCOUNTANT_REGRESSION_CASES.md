# Deterministic accountant regression cases

Run:

```bash
php bin/test_accountant_cases.php
```

The suite fixes inputs and expected three-decimal TND results independently for:

- invoice discount, FODEC, VAT and stamp arithmetic;
- VAT credit notes, payable VAT and credit carry-forward;
- withholding gross, withheld and net amounts;
- configurable TFP, FOPROLOS and TCL calculations;
- fiscal additions and deductions;
- annual employer-declaration totals.

The expected amounts are intentionally hard-coded rather than generated from the
same formulas being tested. The tolerance is 0.0005 TND.

This is a regression and rounding suite. It does not certify rates, eligibility,
legal bases, filing formats, or filing readiness. Those still require validation
by a qualified Tunisian accountant for the company and applicable tax period.

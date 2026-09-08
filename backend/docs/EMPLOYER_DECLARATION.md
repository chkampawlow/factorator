# Annual employer-declaration reconciliation

The annual register is an outbound beneficiary declaration and intentionally excludes withholding certificates received from customers. It supports supplier, payroll, and other beneficiary lines with fiscal IDs, gross amounts, withheld amounts, and notes.

Supplier lines may link to a non-voided supplier payment in the same declaration year. The backend then snapshots the supplier identity and payment amount and the verifier reconciles that source. Payroll and other lines are explicitly manual because this application has no payroll ledger.

The annual report highlights unlinked supplier payments as a coverage control; this is not a claim that every supplier payment is declarable. Applicability, beneficiary categories, withheld amounts, and final filing must be reviewed by a Tunisian accountant.

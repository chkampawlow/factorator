# Credit-note reporting sign policy

Invoice and credit-note amounts are persisted as positive absolute values. Financial
reports apply the sign at query time exactly once: `FACTURE = +1`, `AVOIR = -1`.

- Sales, revenue, collected VAT, and accountant exports include validated invoices
  and validated credit notes using the signed value.
- Customer aging subtracts only validated credit notes linked to the invoice through
  `source_invoice_id` and issued on or before the aging date.
- An unlinked credit remains visible as negative turnover and VAT but cannot be used
  to reduce an arbitrary invoice balance.
- Supplier credit treatment continues through `credited_amount` on the supplier
  invoice and is not affected by the customer-credit sign rule.

Run `php bin/verify_credit_note_reporting.php [tenant] [from] [to]` to reconcile gross
invoice amounts minus credit notes to net reported revenue and VAT.

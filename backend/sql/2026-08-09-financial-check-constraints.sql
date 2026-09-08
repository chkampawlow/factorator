-- Normalize legacy test workflow flags before enforcing database invariants.
UPDATE erp_invoices
SET is_validated = 1
WHERE invoice_type = 'DEVIS' AND status IN ('SENT','ACCEPTED','REJECTED');

UPDATE erp_invoices
SET status = 'DRAFT'
WHERE invoice_type = 'AVOIR';

ALTER TABLE erp_invoices
    ADD CONSTRAINT chk_invoice_type CHECK (invoice_type IN ('DRAFT','FACTURE','DEVIS','AVOIR')),
    ADD CONSTRAINT chk_invoice_status CHECK (status IN ('DRAFT','SENT','ACCEPTED','REJECTED','UNPAID','PARTIALLY_PAID','PAID','OVERDUE','CANCELLED')),
    ADD CONSTRAINT chk_invoice_currency CHECK (currency IN ('TND','EUR','USD')),
    ADD CONSTRAINT chk_invoice_validation_flag CHECK (is_validated IN (0,1)),
    ADD CONSTRAINT chk_invoice_exchange_rate CHECK (exchange_rate > 0),
    ADD CONSTRAINT chk_invoice_header_values CHECK (shipping >= 0 AND discount BETWEEN 0 AND 100 AND vat >= 0 AND timbre >= 0 AND tx_retenue BETWEEN 0 AND 100 AND retenue >= 0);

ALTER TABLE erp_invoice_items
    ADD CONSTRAINT chk_invoice_item_values CHECK (qty > 0 AND price >= 0 AND discount BETWEEN 0 AND 100 AND tva_rate BETWEEN 0 AND 100 AND fodec_rate BETWEEN 0 AND 100);

ALTER TABLE erp_invoice_payments
    ADD CONSTRAINT chk_invoice_payment_amount CHECK (amount > 0),
    ADD CONSTRAINT chk_invoice_payment_method CHECK (method IN ('CASH','CHEQUE','BANK_TRANSFER','CARD','DRAFT','OTHER'));

ALTER TABLE erp_invoice_withholdings
    ADD CONSTRAINT chk_invoice_withholding_values CHECK (rate BETWEEN 0 AND 100 AND calculation_base > 0 AND withheld_amount >= 0);

ALTER TABLE erp_sales_orders
    ADD CONSTRAINT chk_sales_order_totals CHECK (subtotal >= 0 AND montant_tva >= 0 AND total >= 0);

ALTER TABLE erp_sales_order_items
    ADD CONSTRAINT chk_sales_order_item_values CHECK (qty > 0 AND price >= 0 AND discount BETWEEN 0 AND 100 AND tva_rate BETWEEN 0 AND 100);

ALTER TABLE erp_delivery_note_items
    ADD CONSTRAINT chk_delivery_item_values CHECK (qty > 0 AND price >= 0 AND discount BETWEEN 0 AND 100 AND tva_rate BETWEEN 0 AND 100);

ALTER TABLE erp_supplier_orders
    ADD CONSTRAINT chk_supplier_order_totals CHECK (subtotal >= 0 AND total_vat >= 0 AND total >= 0);

ALTER TABLE erp_supplier_order_items
    ADD CONSTRAINT chk_supplier_order_item_values CHECK (qty > 0 AND price >= 0 AND tva_rate BETWEEN 0 AND 100);

ALTER TABLE erp_supplier_receptions
    ADD CONSTRAINT chk_supplier_reception_totals CHECK (total_ht >= 0 AND total_vat >= 0 AND total_ttc >= 0),
    ADD CONSTRAINT chk_supplier_reception_stock_flag CHECK (stock_applied IN (0,1));

ALTER TABLE erp_supplier_reception_items
    ADD CONSTRAINT chk_supplier_reception_item_values CHECK (qty > 0 AND stock_impact >= 0 AND price >= 0 AND selling_price >= 0 AND tva_rate BETWEEN 0 AND 100);

ALTER TABLE erp_supplier_invoices
    ADD CONSTRAINT chk_supplier_invoice_currency CHECK (currency IN ('TND','EUR','USD')),
    ADD CONSTRAINT chk_supplier_invoice_values CHECK (exchange_rate > 0 AND total_ht >= 0 AND total_vat >= 0 AND total_ttc >= 0 AND credited_amount >= 0 AND credited_amount <= total_ttc + 0.0005);

ALTER TABLE erp_supplier_invoice_items
    ADD CONSTRAINT chk_supplier_invoice_item_values CHECK (quantity > 0 AND unit_price >= 0 AND vat_rate BETWEEN 0 AND 100 AND fodec_rate BETWEEN 0 AND 100);

ALTER TABLE erp_supplier_payments
    ADD CONSTRAINT chk_supplier_payment_amount CHECK (amount > 0);

ALTER TABLE erp_supplier_credit_notes
    ADD CONSTRAINT chk_supplier_credit_amount CHECK (amount > 0);

ALTER TABLE erp_supplier_returns
    ADD CONSTRAINT chk_supplier_return_stock_flag CHECK (stock_applied IN (0,1));

ALTER TABLE erp_supplier_return_items
    ADD CONSTRAINT chk_supplier_return_item_values CHECK (quantity > 0 AND unit_cost >= 0);

ALTER TABLE products
    ADD CONSTRAINT chk_product_financial_values CHECK (price >= 0 AND last_purchase_price >= 0 AND average_cost >= 0 AND tva_rate BETWEEN 0 AND 100);

ALTER TABLE expense_notes
    ADD CONSTRAINT chk_expense_amount CHECK (amount >= 0);


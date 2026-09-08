ALTER TABLE erp_invoices
    ADD COLUMN sales_order_id INT(11) NULL AFTER custom_code,
    ADD COLUMN delivery_note_id INT(11) NULL AFTER sales_order_id,
    ADD COLUMN source_flow ENUM('DIRECT', 'ORDER', 'DELIVERY') NOT NULL DEFAULT 'DIRECT' AFTER delivery_note_id;

ALTER TABLE erp_invoices
    ADD KEY idx_erp_invoices_sales_order (sales_order_id),
    ADD KEY idx_erp_invoices_delivery_note (delivery_note_id),
    ADD KEY idx_erp_invoices_source_flow (source_flow);

ALTER TABLE erp_invoices
    ADD CONSTRAINT fk_erp_invoices_sales_order
        FOREIGN KEY (sales_order_id) REFERENCES erp_sales_orders(id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    ADD CONSTRAINT fk_erp_invoices_delivery_note
        FOREIGN KEY (delivery_note_id) REFERENCES erp_delivery_notes(id)
        ON DELETE SET NULL ON UPDATE CASCADE;

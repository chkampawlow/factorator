ALTER TABLE erp_delivery_note_items
    ADD COLUMN price DECIMAL(20,3) NOT NULL DEFAULT 0.000 AFTER qty,
    ADD COLUMN discount DECIMAL(20,3) NOT NULL DEFAULT 0.000 AFTER price,
    ADD COLUMN tva_rate DECIMAL(10,3) NOT NULL DEFAULT 0.000 AFTER discount,
    ADD COLUMN subtotal DECIMAL(20,3) NOT NULL DEFAULT 0.000 AFTER tva_rate,
    ADD COLUMN montant_tva DECIMAL(20,3) NOT NULL DEFAULT 0.000 AFTER subtotal,
    ADD COLUMN total DECIMAL(20,3) NOT NULL DEFAULT 0.000 AFTER montant_tva;

UPDATE erp_delivery_note_items di
LEFT JOIN products p ON p.id = di.product_id
SET
    di.price = COALESCE(di.price, 0.000) + CASE WHEN di.price = 0 THEN COALESCE(p.price, 0.000) ELSE 0 END,
    di.discount = COALESCE(di.discount, 0.000),
    di.tva_rate = COALESCE(di.tva_rate, 0.000) + CASE WHEN di.tva_rate = 0 THEN COALESCE(p.tva_rate, 0.000) ELSE 0 END;

UPDATE erp_delivery_note_items
SET
    subtotal = ROUND(qty * price * (1 - (discount / 100)), 3),
    montant_tva = ROUND((qty * price * (1 - (discount / 100))) * (tva_rate / 100), 3),
    total = ROUND((qty * price * (1 - (discount / 100))) + ((qty * price * (1 - (discount / 100))) * (tva_rate / 100)), 3);

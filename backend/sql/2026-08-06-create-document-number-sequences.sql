CREATE TABLE IF NOT EXISTS erp_document_number_sequences (
    user_id INT NOT NULL,
    document_type VARCHAR(20) NOT NULL,
    document_year SMALLINT UNSIGNED NOT NULL,
    next_number INT UNSIGNED NOT NULL DEFAULT 1,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, document_type, document_year)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO erp_document_number_sequences (user_id, document_type, document_year, next_number)
SELECT user_id, 'FACTURE',
       CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(invoice, '-', 2), '-', -1) AS UNSIGNED),
       MAX(CAST(SUBSTRING_INDEX(invoice, '-', -1) AS UNSIGNED))
FROM erp_invoices
WHERE invoice REGEXP '^FAC-[0-9]{4}-[0-9]{6}$'
GROUP BY user_id, CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(invoice, '-', 2), '-', -1) AS UNSIGNED)
ON DUPLICATE KEY UPDATE next_number = GREATEST(next_number, VALUES(next_number));

INSERT INTO erp_document_number_sequences (user_id, document_type, document_year, next_number)
SELECT user_id, 'AVOIR',
       CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(invoice, '-', 2), '-', -1) AS UNSIGNED),
       MAX(CAST(SUBSTRING_INDEX(invoice, '-', -1) AS UNSIGNED))
FROM erp_invoices
WHERE invoice REGEXP '^AV-[0-9]{4}-[0-9]{6}$'
GROUP BY user_id, CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(invoice, '-', 2), '-', -1) AS UNSIGNED)
ON DUPLICATE KEY UPDATE next_number = GREATEST(next_number, VALUES(next_number));

INSERT INTO erp_document_number_sequences (user_id, document_type, document_year, next_number)
SELECT user_id, 'DEVIS',
       CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(invoice, '-', 2), '-', -1) AS UNSIGNED),
       MAX(CAST(SUBSTRING_INDEX(invoice, '-', -1) AS UNSIGNED))
FROM erp_invoices
WHERE invoice REGEXP '^DEV-[0-9]{4}-[0-9]{6}$'
GROUP BY user_id, CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(invoice, '-', 2), '-', -1) AS UNSIGNED)
ON DUPLICATE KEY UPDATE next_number = GREATEST(next_number, VALUES(next_number));

INSERT INTO erp_document_number_sequences (user_id, document_type, document_year, next_number)
SELECT user_id, 'BON_COMMANDE',
       CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(order_number, '-', 2), '-', -1) AS UNSIGNED),
       MAX(CAST(SUBSTRING_INDEX(order_number, '-', -1) AS UNSIGNED))
FROM erp_sales_orders
WHERE order_number REGEXP '^BC-[0-9]{4}-[0-9]{6}$'
GROUP BY user_id, CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(order_number, '-', 2), '-', -1) AS UNSIGNED)
ON DUPLICATE KEY UPDATE next_number = GREATEST(next_number, VALUES(next_number));

INSERT INTO erp_document_number_sequences (user_id, document_type, document_year, next_number)
SELECT user_id, 'BON_LIVRAISON',
       CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(delivery_number, '-', 2), '-', -1) AS UNSIGNED),
       MAX(CAST(SUBSTRING_INDEX(delivery_number, '-', -1) AS UNSIGNED))
FROM erp_delivery_notes
WHERE delivery_number REGEXP '^BL-[0-9]{4}-[0-9]{6}$'
GROUP BY user_id, CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(delivery_number, '-', 2), '-', -1) AS UNSIGNED)
ON DUPLICATE KEY UPDATE next_number = GREATEST(next_number, VALUES(next_number));

INSERT INTO erp_document_number_sequences (user_id, document_type, document_year, next_number)
SELECT user_id, 'BON_SORTIE',
       CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(delivery_number, '-', 2), '-', -1) AS UNSIGNED),
       MAX(CAST(SUBSTRING_INDEX(delivery_number, '-', -1) AS UNSIGNED))
FROM erp_delivery_notes
WHERE delivery_number REGEXP '^BS-[0-9]{4}-[0-9]{6}$'
GROUP BY user_id, CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(delivery_number, '-', 2), '-', -1) AS UNSIGNED)
ON DUPLICATE KEY UPDATE next_number = GREATEST(next_number, VALUES(next_number));

-- Existing tables already enforce unique document numbers:
-- erp_invoices(user_id, invoice), erp_sales_orders(user_id, order_number),
-- and erp_delivery_notes(user_id, delivery_number).

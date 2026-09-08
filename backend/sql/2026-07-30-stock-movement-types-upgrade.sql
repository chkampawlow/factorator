ALTER TABLE product_stock_movements
MODIFY COLUMN movement_type ENUM(
  'INITIAL',
  'SUPPLIER_IN',
  'DELIVERY_OUT',
  'INVOICE_OUT',
  'ADJUSTMENT',
  'RETURN_IN',
  'MANUAL',
  'DELIVERY',
  'EXIT',
  'RETURN'
) NOT NULL;

UPDATE product_stock_movements
SET movement_type = 'SUPPLIER_IN'
WHERE movement_type = 'MANUAL'
  AND UPPER(COALESCE(reference_type, '')) = 'SUPPLIER_BILL';

UPDATE product_stock_movements
SET movement_type = 'DELIVERY_OUT'
WHERE movement_type = 'DELIVERY';

UPDATE product_stock_movements
SET movement_type = 'DELIVERY_OUT'
WHERE movement_type = 'EXIT'
  AND UPPER(COALESCE(reference_type, '')) = 'DELIVERY_NOTE';

UPDATE product_stock_movements
SET movement_type = 'INVOICE_OUT'
WHERE movement_type = 'EXIT'
  AND UPPER(COALESCE(reference_type, '')) = 'INVOICE';

UPDATE product_stock_movements
SET movement_type = 'RETURN_IN'
WHERE movement_type = 'RETURN';

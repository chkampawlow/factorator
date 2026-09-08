<?php

if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
require_once __DIR__.'/../config/db.php';

$conn=db();
$checks=[
    'invoice clients'=>"SELECT COUNT(*) FROM erp_invoices i LEFT JOIN clients c ON c.id=CAST(i.custom_code AS UNSIGNED) WHERE CAST(i.custom_code AS UNSIGNED)>0 AND (c.id IS NULL OR c.user_id<>i.user_id)",
    'invoice item products'=>"SELECT COUNT(*) FROM erp_invoice_items ii JOIN erp_invoices i ON i.id=ii.invoice_id LEFT JOIN products p ON p.id=ii.product_id WHERE ii.product_id>0 AND (p.id IS NULL OR p.user_id<>i.user_id)",
    'sales order clients'=>"SELECT COUNT(*) FROM erp_sales_orders o LEFT JOIN clients c ON c.id=o.client_id WHERE c.id IS NULL OR c.user_id<>o.user_id",
    'sales order products'=>"SELECT COUNT(*) FROM erp_sales_order_items oi JOIN erp_sales_orders o ON o.id=oi.sales_order_id LEFT JOIN products p ON p.id=oi.product_id WHERE oi.product_id>0 AND (p.id IS NULL OR p.user_id<>o.user_id)",
    'delivery clients and orders'=>"SELECT COUNT(*) FROM erp_delivery_notes d LEFT JOIN clients c ON c.id=d.client_id LEFT JOIN erp_sales_orders o ON o.id=d.sales_order_id WHERE c.id IS NULL OR c.user_id<>d.user_id OR (d.sales_order_id IS NOT NULL AND (o.id IS NULL OR o.user_id<>d.user_id))",
    'delivery products'=>"SELECT COUNT(*) FROM erp_delivery_note_items di JOIN erp_delivery_notes d ON d.id=di.delivery_note_id LEFT JOIN products p ON p.id=di.product_id WHERE di.product_id>0 AND (p.id IS NULL OR p.user_id<>d.user_id)",
    'expense suppliers'=>"SELECT COUNT(*) FROM expense_notes e LEFT JOIN suppliers s ON s.id=e.supplier_id WHERE e.supplier_id>0 AND (s.id IS NULL OR s.user_id<>e.user_id)",
    'expense source orders'=>"SELECT COUNT(*) FROM expense_notes e LEFT JOIN erp_supplier_orders o ON o.id=e.source_document_id WHERE e.source_document_type='SUPPLIER_ORDER' AND e.source_document_id>0 AND (o.id IS NULL OR o.user_id<>e.user_id OR (e.supplier_id>0 AND o.supplier_id<>e.supplier_id))",
    'expense source receptions'=>"SELECT COUNT(*) FROM expense_notes e LEFT JOIN erp_supplier_receptions r ON r.id=e.source_document_id WHERE e.source_document_type='SUPPLIER_RECEPTION' AND e.source_document_id>0 AND (r.id IS NULL OR r.user_id<>e.user_id OR (e.supplier_id>0 AND r.supplier_id<>e.supplier_id))",
    'supplier order suppliers'=>"SELECT COUNT(*) FROM erp_supplier_orders o LEFT JOIN suppliers s ON s.id=o.supplier_id WHERE s.id IS NULL OR s.user_id<>o.user_id",
    'supplier order products'=>"SELECT COUNT(*) FROM erp_supplier_order_items oi JOIN erp_supplier_orders o ON o.id=oi.supplier_order_id LEFT JOIN products p ON p.id=oi.catalog_id WHERE oi.catalog_id>0 AND (p.id IS NULL OR p.user_id<>o.user_id)",
    'supplier reception ownership'=>"SELECT COUNT(*) FROM erp_supplier_receptions r LEFT JOIN suppliers s ON s.id=r.supplier_id LEFT JOIN erp_supplier_orders o ON o.id=r.supplier_order_id WHERE s.id IS NULL OR s.user_id<>r.user_id OR (r.supplier_order_id IS NOT NULL AND (o.id IS NULL OR o.user_id<>r.user_id))",
    'supplier reception products'=>"SELECT COUNT(*) FROM erp_supplier_reception_items ri JOIN erp_supplier_receptions r ON r.id=ri.supplier_reception_id LEFT JOIN products p ON p.id=ri.catalog_id WHERE ri.catalog_id>0 AND (p.id IS NULL OR p.user_id<>r.user_id)",
    'supplier invoice ownership'=>"SELECT COUNT(*) FROM erp_supplier_invoices i LEFT JOIN suppliers s ON s.id=i.supplier_id LEFT JOIN erp_supplier_orders o ON o.id=i.supplier_order_id WHERE s.id IS NULL OR s.user_id<>i.user_id OR (i.supplier_order_id IS NOT NULL AND (o.id IS NULL OR o.user_id<>i.user_id))",
    'supplier invoice products'=>"SELECT COUNT(*) FROM erp_supplier_invoice_items ii JOIN erp_supplier_invoices i ON i.id=ii.supplier_invoice_id LEFT JOIN products p ON p.id=ii.product_id WHERE ii.product_id>0 AND (p.id IS NULL OR p.user_id<>i.user_id)",
    'stock movement products'=>"SELECT COUNT(*) FROM product_stock_movements m LEFT JOIN products p ON p.id=m.product_id WHERE p.id IS NULL OR p.user_id<>m.user_id",
    'inventory adjustment products'=>"SELECT COUNT(*) FROM erp_inventory_adjustments a LEFT JOIN products p ON p.id=a.product_id WHERE p.id IS NULL OR p.user_id<>a.user_id",
    'product tax profiles'=>"SELECT COUNT(*) FROM products p LEFT JOIN erp_tax_profiles t ON t.id=p.tax_profile_id WHERE p.tax_profile_id IS NOT NULL AND (t.id IS NULL OR t.user_id<>p.user_id)",
    'invoice item tax profiles'=>"SELECT COUNT(*) FROM erp_invoice_items ii JOIN erp_invoices i ON i.id=ii.invoice_id LEFT JOIN erp_tax_profiles t ON t.id=ii.tax_profile_id WHERE ii.tax_profile_id IS NOT NULL AND (t.id IS NULL OR t.user_id<>i.user_id)",
];
$failures=[];
foreach($checks as $name=>$sql){
    $count=(int)$conn->query($sql)->fetch_row()[0];
    echo ($count===0?'PASS ':'FAIL ').$name.' '.$count.PHP_EOL;
    if($count!==0)$failures[$name]=$count;
}
$sourceChecks=[
    'expense_notes/add.php'=>'requireTenantExpenseSource',
    'products/create_stock_adjustment.php'=>'requireTenantProduct',
    'supplier_invoices/save_supplier_invoice.php'=>'requireTenantSupplier',
    'bon_commandes/save.php'=>'requireTenantProduct',
    'bon_livraisons/save.php'=>'requireTenantProduct',
    'supplier_returns/confirm_supplier_return.php'=>'requireTenantSupplier',
];
foreach($sourceChecks as $file=>$needle){
    $source=file_get_contents(__DIR__.'/../'.$file);
    if($source===false||!str_contains($source,$needle)){
        echo "FAIL $file missing $needle".PHP_EOL;
        $failures[$file]=1;
    }
}
exit($failures?1:0);

<?php

if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
require_once __DIR__.'/../config/db.php';
require_once __DIR__.'/../auth/jwt_helper.php';

$base=rtrim((string)(getenv('AUTHZ_TEST_BASE_URL')?:'http://localhost/backend'),'/');
$conn=db();
$owner=$conn->query("SELECT c.id FROM companies c WHERE c.status='ACTIVE'
    AND EXISTS(SELECT 1 FROM erp_invoices i WHERE i.user_id=c.id)
    AND EXISTS(SELECT 1 FROM products p WHERE p.user_id=c.id) ORDER BY c.id LIMIT 1")->fetch_assoc();
if(!$owner)throw new RuntimeException('A tenant with invoice and product fixtures is required');
$ownerId=(int)$owner['id'];
$observerStmt=$conn->prepare("SELECT u.id,u.email,cm.id membership_id,cm.company_id,cm.role,cm.version membership_version
    FROM company_memberships cm JOIN companies c ON c.id=cm.company_id AND c.status='ACTIVE'
    JOIN users u ON u.id=cm.user_id
    WHERE cm.company_id<>? AND cm.status='ACTIVE' AND u.account_status='ACTIVE'
      AND u.email_verified_at IS NOT NULL ORDER BY cm.is_owner DESC,cm.id LIMIT 1");
$observerStmt->bind_param('i',$ownerId);$observerStmt->execute();$observer=$observerStmt->get_result()->fetch_assoc();$observerStmt->close();
if(!$observer)throw new RuntimeException('A second active verified tenant is required');
$observerId=(int)$observer['id'];$observerMembershipId=(int)$observer['membership_id'];$observerCompanyId=(int)$observer['company_id'];$originalRole=(string)$observer['role'];
$ids=[];
foreach([
 'invoice'=>"SELECT MIN(id) FROM erp_invoices WHERE user_id=$ownerId",
 'product'=>"SELECT MIN(id) FROM products WHERE user_id=$ownerId",
 'order'=>"SELECT MIN(id) FROM erp_sales_orders WHERE user_id=$ownerId",
 'delivery'=>"SELECT MIN(id) FROM erp_delivery_notes WHERE user_id=$ownerId",
] as $name=>$sql)$ids[$name]=(int)$conn->query($sql)->fetch_row()[0];

$endpoints=[
 'invoices/get_invoice_by_id.php?id='.$ids['invoice'],
 'invoice_items/get_invoice_items.php?invoice_id='.$ids['invoice'],
 'invoice_settlements/get.php?invoice_id='.$ids['invoice'],
 'einvoices/get.php?invoice_id='.$ids['invoice'],
 'products/get_product_stock_history.php?id='.$ids['product'],
];
if($ids['order']>0)$endpoints[]='bon_commandes/get.php?id='.$ids['order'];
if($ids['delivery']>0)$endpoints[]='bon_livraisons/get.php?id='.$ids['delivery'];

function requestStatus(string $url,string $token):int{
    $context=stream_context_create(['http'=>['method'=>'GET','header'=>"Accept: application/json\r\nX-Access-Token: $token\r\n",'ignore_errors'=>true,'timeout'=>20]]);
    file_get_contents($url,false,$context);$headers=$http_response_header??[];$status=0;
    foreach($headers as $header)if(preg_match('#^HTTP/\S+\s+(\d{3})#',$header,$m))$status=(int)$m[1];
    return $status;
}
$admin='ADMINISTRATOR';$update=$conn->prepare('UPDATE company_memberships SET role=? WHERE id=? AND company_id=?');$failures=[];
try{
    $update->bind_param('sii',$admin,$observerMembershipId,$observerCompanyId);$update->execute();
    $token=generateJwt([
        'id'=>$observerId,
        'email'=>(string)$observer['email'],
        'role'=>$admin,
        'company_id'=>$observerCompanyId,
        'membership_id'=>$observerMembershipId,
        'membership_version'=>(int)$observer['membership_version'],
    ],300);
    foreach($endpoints as $endpoint){
        $status=requestStatus($base.'/'.$endpoint,$token);$passed=$status===404;
        echo ($passed?'PASS ':'FAIL ')."$endpoint foreign lookup ($status)".PHP_EOL;
        if(!$passed)$failures[]="$endpoint returned $status instead of 404";
    }
} finally {
    $update->bind_param('sii',$originalRole,$observerMembershipId,$observerCompanyId);$update->execute();$update->close();
}
if($failures){foreach($failures as $failure)fwrite(STDERR,"FAIL $failure".PHP_EOL);exit(1);}
echo "PASS observer membership role restored for user $observerId".PHP_EOL;

<?php

if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
require_once __DIR__.'/../config/db.php';
require_once __DIR__.'/../auth/jwt_helper.php';
require_once __DIR__.'/../auth/role_helper.php';

$base=rtrim((string)(getenv('AUTHZ_TEST_BASE_URL')?:'http://localhost/backend'),'/');
$conn=db();
$candidate=$conn->query("SELECT c.id company_id,
    (SELECT COUNT(*) FROM erp_invoices i WHERE i.user_id=c.id)+(SELECT COUNT(*) FROM products p WHERE p.user_id=c.id) business_rows
    FROM companies c WHERE c.status='ACTIVE' ORDER BY business_rows DESC,c.id LIMIT 1")->fetch_assoc();
if(!$candidate)throw new RuntimeException('An active authorization-test company is required');
$companyId=(int)$candidate['company_id'];
$marker=bin2hex(random_bytes(6));
$email="role-test-{$marker}@example.test";
$displayName='Role authorization fixture';
$organizationName='Role authorization fixture';
$fiscalId="RT{$marker}";
$passwordHash=password_hash('Role-authorization-fixture-2026!',PASSWORD_DEFAULT);
$legacyRole='COMMERCIAL';
$insertUser=$conn->prepare("INSERT INTO users(display_name,organization_name,fiscal_id,email,password_hash,email_verified_at,role,account_status) VALUES(?,?,?,?,?,NOW(),?,'ACTIVE')");
$insertUser->bind_param('ssssss',$displayName,$organizationName,$fiscalId,$email,$passwordHash,$legacyRole);
$insertUser->execute();$userId=(int)$insertUser->insert_id;$insertUser->close();
$initialRole='ADMINISTRATOR';
$insertMembership=$conn->prepare("INSERT INTO company_memberships(company_id,user_id,role,status,is_owner,version,joined_at) VALUES(?,? ,?,'ACTIVE',0,1,NOW())");
$insertMembership->bind_param('iis',$companyId,$userId,$initialRole);$insertMembership->execute();$membershipId=(int)$insertMembership->insert_id;$insertMembership->close();
$setDefault=$conn->prepare('UPDATE users SET default_company_id=? WHERE id=?');$setDefault->bind_param('ii',$companyId,$userId);$setDefault->execute();$setDefault->close();

$cases=[
 'ADMINISTRATOR'=>[
   'allow'=>['reports/overview.php','user/list_users.php'],
   'deny'=>[],
 ],
 'COMMERCIAL'=>[
   'allow'=>['clients/get_clients.php','products/get_products.php','invoices/get_invoices.php','bon_commandes/list.php','bon_livraisons/list.php'],
   'deny'=>['reports/overview.php','suppliers/get_suppliers.php','user/list_users.php'],
 ],
 'STOCK'=>[
   'allow'=>['products/get_products.php','suppliers/get_suppliers.php','supplier_orders/list_page.php?page=1&page_size=1'],
   'deny'=>['expense_notes/list.php','reports/overview.php','user/list_users.php'],
 ],
 'ACCOUNTING'=>[
   'allow'=>['invoices/get_invoices.php','expense_notes/list.php','reports/overview.php','suppliers/get_suppliers.php'],
   'deny'=>['bon_commandes/list.php','products/list_page.php','user/list_users.php'],
 ],
];

function httpStatus(string $url,string $token):int{
    $context=stream_context_create(['http'=>['method'=>'GET','header'=>"Accept: application/json\r\nX-Access-Token: $token\r\n",'ignore_errors'=>true,'timeout'=>20]]);
    $body=file_get_contents($url,false,$context);
    $headers=$http_response_header??[];
    $status=0;
    foreach($headers as $header)if(preg_match('#^HTTP/\S+\s+(\d{3})#',$header,$m))$status=(int)$m[1];
    if($body===false&&$status===0)throw new RuntimeException("HTTP request failed: $url");
    return $status;
}

$failures=[];
$update=$conn->prepare('UPDATE company_memberships SET role=? WHERE id=? AND company_id=?');
try{
    foreach($cases as $role=>$expectations){
        $update->bind_param('sii',$role,$membershipId,$companyId);$update->execute();
        $token=generateJwt([
            'id'=>$userId,
            'email'=>$email,
            'role'=>$role,
            'company_id'=>$companyId,
            'membership_id'=>$membershipId,
            'membership_version'=>1,
        ],300);
        foreach($expectations['allow'] as $endpoint){
            $status=httpStatus($base.'/'.$endpoint,$token);
            $passed=$status>=200&&$status<300;
            echo ($passed?'PASS ':'FAIL ')."$role allows $endpoint ($status)".PHP_EOL;
            if(!$passed)$failures[]="$role should allow $endpoint, got $status";
        }
        foreach($expectations['deny'] as $endpoint){
            $status=httpStatus($base.'/'.$endpoint,$token);
            $passed=$status===403;
            echo ($passed?'PASS ':'FAIL ')."$role denies $endpoint ($status)".PHP_EOL;
            if(!$passed)$failures[]="$role should deny $endpoint with 403, got $status";
        }
    }
} finally {
    $update->close();
    $deleteMembership=$conn->prepare('DELETE FROM company_memberships WHERE id=? AND company_id=?');
    $deleteMembership->bind_param('ii',$membershipId,$companyId);$deleteMembership->execute();$deleteMembership->close();
    $deleteUser=$conn->prepare('DELETE FROM users WHERE id=? AND email=?');
    $deleteUser->bind_param('is',$userId,$email);$deleteUser->execute();$deleteUser->close();
}
if(normalizeUserRole('INVALID_ROLE')!=='UNAUTHORIZED')$failures[]='Invalid roles must normalize to UNAUTHORIZED';
if($failures){foreach($failures as $failure)fwrite(STDERR,"FAIL $failure".PHP_EOL);exit(1);}
echo "PASS temporary role fixture removed".PHP_EOL;

<?php

declare(strict_types=1);

if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
require_once __DIR__ . '/../config/db.php';

$conn=db();$database=(string)$conn->query('SELECT DATABASE()')->fetch_row()[0];
if(!preg_match('/(?:^|_)(?:test|testing|local)(?:_|$)/i',$database)){fwrite(STDERR,"REFUSED on $database\n");exit(2);}
$marker=bin2hex(random_bytes(6));$email="payment-race-$marker@example.test";$userId=0;$invoiceId=0;

function runWorkers(array $commands,string $barrier):array{
    $processes=[];
    foreach($commands as $command){$pipes=[];$process=proc_open($command,[1=>['pipe','w'],2=>['pipe','w']],$pipes);if(!is_resource($process))throw new RuntimeException('Could not start payment worker');$processes[]=[$process,$pipes];}
    touch($barrier);$results=[];
    foreach($processes as [$process,$pipes]){$stdout=stream_get_contents($pipes[1]);$stderr=stream_get_contents($pipes[2]);fclose($pipes[1]);fclose($pipes[2]);$exit=proc_close($process);$results[]=['exit'=>$exit,'data'=>json_decode($stdout,true),'stderr'=>$stderr];}
    @unlink($barrier);return $results;
}
function check(bool $ok,string $label,array &$failures):void{echo($ok?'PASS ':'FAIL ').$label.PHP_EOL;if(!$ok)$failures[]=$label;}

$failures=[];
try{
    $password=password_hash('Integration-only-password-2026!',PASSWORD_DEFAULT);$fiscal='PAY'.strtoupper($marker);$name='Payment Race Fixture';
    $stmt=$conn->prepare("INSERT INTO users(organization_name,fiscal_id,email,password_hash,email_verified_at,role,account_status) VALUES(?,?,?,?,NOW(),'ACCOUNTING','ACTIVE')");$stmt->bind_param('ssss',$name,$fiscal,$email,$password);$stmt->execute();$userId=(int)$stmt->insert_id;$stmt->close();
    $number="RACE-$marker";$date='2026-08-10';$notes='Concurrency integration fixture';$type='FACTURE';$status='UNPAID';
    $stmt=$conn->prepare("INSERT INTO erp_invoices(invoice,invoice_date,invoice_due_date,subtotal,subtotal_tnd,base_tva,montant_tva,tax_total_tnd,subtotal_ttc,shipping,discount,vat,total,total_tnd,notes,invoice_type,status,is_validated,timbre,user_id) VALUES(?,?,?,1000,1000,1000,0,0,1000,0,0,0,1000,1000,?,?,?,1,0,?)");
    $stmt->bind_param('ssssssi',$number,$date,$date,$notes,$type,$status,$userId);$stmt->execute();$invoiceId=(int)$stmt->insert_id;$stmt->close();

    $worker=__DIR__.'/concurrency_payment_worker.php';$barrier=sys_get_temp_dir()."/fatoura-payment-$marker.go";
    $commands=[[PHP_BINARY,$worker,(string)$invoiceId,(string)$userId,'700.000',"race-a-$marker",$barrier],[PHP_BINARY,$worker,(string)$invoiceId,(string)$userId,'700.000',"race-b-$marker",$barrier]];
    $race=runWorkers($commands,$barrier);$successes=array_values(array_filter($race,fn($r)=>($r['data']['success']??false)===true));$rejections=array_values(array_filter($race,fn($r)=>($r['data']['success']??true)===false));
    check(count($successes)===1&&count($rejections)===1,'simultaneous overpayment race allows exactly one payment',$failures);
    check(str_contains((string)($rejections[0]['data']['message']??''),'exceeds'),'losing payment is rejected as exceeding the balance',$failures);
    $winningKey=($race[0]['data']['success']??false)?"race-a-$marker":"race-b-$marker";$winningId=(int)$successes[0]['data']['id'];
    $replayBarrier=sys_get_temp_dir()."/fatoura-replay-$marker.go";$replay=runWorkers([[PHP_BINARY,$worker,(string)$invoiceId,(string)$userId,'700.000',$winningKey,$replayBarrier]],$replayBarrier)[0];
    check(($replay['data']['success']??false)===true&&($replay['data']['replayed']??false)===true&&(int)$replay['data']['id']===$winningId,'identical retry returns the original payment',$failures);
    $conflictBarrier=sys_get_temp_dir()."/fatoura-conflict-$marker.go";$conflict=runWorkers([[PHP_BINARY,$worker,(string)$invoiceId,(string)$userId,'200.000',$winningKey,$conflictBarrier]],$conflictBarrier)[0];
    check(($conflict['data']['success']??true)===false&&str_contains((string)($conflict['data']['message']??''),'different request'),'reused key with changed amount is rejected',$failures);
    $paid=(float)$conn->query("SELECT COALESCE(SUM(amount),0) FROM erp_invoice_payments WHERE invoice_id=$invoiceId AND status='POSTED'")->fetch_row()[0];
    check(abs($paid-700.0)<0.0005,'stored payments never exceed invoice total',$failures);
}finally{
    if($invoiceId>0){$conn->query("DELETE FROM erp_invoice_payments WHERE invoice_id=$invoiceId");$conn->query("DELETE FROM erp_idempotency_keys WHERE user_id=$userId");$conn->query("DELETE FROM erp_invoices WHERE id=$invoiceId");}
    if($userId>0)$conn->query("DELETE FROM users WHERE id=$userId");
}
check((int)$conn->query("SELECT COUNT(*) FROM users WHERE email='".$conn->real_escape_string($email)."'")->fetch_row()[0]===0,'concurrency fixtures cleaned up',$failures);
if($failures!==[])exit(1);echo 'Payment concurrency and idempotency suite passed.'.PHP_EOL;

<?php

declare(strict_types=1);

if(PHP_SAPI!=='cli'){http_response_code(404);exit;}
require_once __DIR__.'/../config/db.php';require_once __DIR__.'/../reports/cashflow_forecast_service.php';
$conn=db();$database=(string)$conn->query('SELECT DATABASE()')->fetch_row()[0];if(!preg_match('/(?:^|_)(?:test|testing|local)(?:_|$)/i',$database)){fwrite(STDERR,"REFUSED on $database\n");exit(2);}
$failures=[];function forecastCheck(bool $ok,string $label,array &$failures):void{echo($ok?'PASS ':'FAIL ').$label.PHP_EOL;if(!$ok)$failures[]=$label;}
$summary=summarizeCashflowForecast(
    [['forecast_date'=>'2026-08-11','amount_tnd'=>'125.500','overdue_tnd'=>'25.500'],['forecast_date'=>'2026-08-20','amount_tnd'=>'74.500','overdue_tnd'=>'0.000']],
    [['forecast_date'=>'2026-08-11','amount_tnd'=>'40.125','overdue_tnd'=>'10.125']],
    [['direction'=>'PAYMENT','source_id'=>2,'document_number'=>'ACH-2','forecast_date'=>'2026-08-11'],['direction'=>'COLLECTION','source_id'=>1,'document_number'=>'FAC-1','forecast_date'=>'2026-08-11']],
    '2026-08-11','2026-09-10',false
);
forecastCheck($summary['summary']===['expected_collections'=>'200.000','expected_payments'=>'40.125','net_cashflow'=>'159.875','overdue_collections'=>'25.500','overdue_payments'=>'10.125'],'forecast totals preserve millime precision',$failures);
forecastCheck(($summary['daily'][0]['net']??null)==='85.375'&&($summary['daily'][1]['cumulative_net']??null)==='159.875','daily forecast carries cumulative net movement',$failures);
forecastCheck(($summary['events'][0]['direction']??'')==='COLLECTION','agenda ordering is deterministic',$failures);
$manyEvents=[];for($index=1;$index<=501;$index++)$manyEvents[]=['direction'=>'COLLECTION','source_id'=>$index,'document_number'=>sprintf('FAC-%04d',$index),'forecast_date'=>'2026-08-11'];
$limited=summarizeCashflowForecast([],[],$manyEvents,'2026-08-11','2026-09-10',false);
forecastCheck(count($limited['events'])===500&&$limited['truncated']===true&&$limited['event_limit']===500,'agenda is capped without changing summary totals',$failures);
$today=new DateTimeImmutable('2026-08-11',new DateTimeZone('Africa/Tunis'));
try{validateCashflowForecastPeriod('2026-08-10','2026-09-10',$today);$pastRejected=false;}catch(InvalidArgumentException){$pastRejected=true;}forecastCheck($pastRejected,'past forecast starts are rejected',$failures);
try{validateCashflowForecastPeriod('2026-08-11','2027-08-12',$today);$longRejected=false;}catch(InvalidArgumentException){$longRejected=true;}forecastCheck($longRejected,'forecast horizon is bounded',$failures);
$empty=buildTenantCashflowForecast($conn,random_int(600000000,699999999),'2026-08-11','2026-11-09',$today);
forecastCheck($empty['summary']['net_cashflow']==='0.000'&&$empty['daily']===[]&&$empty['events']===[],'empty tenant forecast has an explicit zero state',$failures);
if($failures!==[])exit(1);echo'Cash-flow forecast suite passed.'.PHP_EOL;

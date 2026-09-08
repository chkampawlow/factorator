<?php

declare(strict_types=1);

if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../reports/report_preset_service.php';

$conn=db();$database=(string)$conn->query('SELECT DATABASE()')->fetch_row()[0];
if(!preg_match('/(?:^|_)(?:test|testing|local)(?:_|$)/i',$database)){fwrite(STDERR,"REFUSED on $database\n");exit(2);}
$uid=random_int(700000000,799999999);$failures=[];
function presetCheck(bool $ok,string $label,array &$failures):void{echo($ok?'PASS ':'FAIL ').$label.PHP_EOL;if(!$ok)$failures[]=$label;}

try{
    $today=new DateTimeImmutable('2026-08-11',new DateTimeZone('Africa/Tunis'));
    presetCheck(resolveReportPresetPeriod('CURRENT_MONTH',null,null,$today)===['from'=>'2026-08-01','to'=>'2026-08-11'],'current month resolves through today',$failures);
    presetCheck(resolveReportPresetPeriod('PREVIOUS_MONTH',null,null,$today)===['from'=>'2026-07-01','to'=>'2026-07-31'],'previous month resolves to full month',$failures);
    presetCheck(resolveReportPresetPeriod('CURRENT_QUARTER',null,null,$today)===['from'=>'2026-07-01','to'=>'2026-08-11'],'current quarter resolves through today',$failures);
    presetCheck(resolveReportPresetPeriod('LAST_30_DAYS',null,null,$today)===['from'=>'2026-07-13','to'=>'2026-08-11'],'last 30 days is inclusive',$failures);

    $custom=saveReportPreset($conn,$uid,$uid,0,'Clôture juillet','CUSTOM','2026-07-01','2026-07-31');
    $rolling=saveReportPreset($conn,$uid,$uid,0,'Mois courant','CURRENT_MONTH',null,null);
    presetCheck((int)$custom['id']>0&&$custom['resolved_from']==='2026-07-01'&&$custom['resolved_to']==='2026-07-31','custom preset is stored and resolved',$failures);
    presetCheck(count(listReportPresets($conn,$uid))===2,'tenant lists only its presets',$failures);
    presetCheck(reportPresetForTenant($conn,$uid+1,(int)$custom['id'])===null,'preset read is isolated by tenant',$failures);
    $updated=saveReportPreset($conn,$uid,$uid,(int)$custom['id'],'Clôture T3','CUSTOM','2026-07-01','2026-09-30');
    presetCheck($updated['name']==='Clôture T3'&&$updated['resolved_to']==='2026-09-30','preset can be updated',$failures);
    try{saveReportPreset($conn,$uid,$uid,0,'Mois courant','PREVIOUS_MONTH',null,null);$duplicate=false;}catch(InvalidArgumentException){$duplicate=true;}
    presetCheck($duplicate,'duplicate tenant preset names are rejected',$failures);
    presetCheck(deleteReportPreset($conn,$uid+1,(int)$rolling['id'])===null,'preset delete is isolated by tenant',$failures);
    presetCheck(deleteReportPreset($conn,$uid,(int)$rolling['id'])!==null&&count(listReportPresets($conn,$uid))===1,'tenant can delete its preset',$failures);
}finally{
    $stmt=$conn->prepare('DELETE FROM erp_report_presets WHERE user_id=?');$stmt->bind_param('i',$uid);$stmt->execute();$stmt->close();
}
if($failures!==[])exit(1);echo'Report preset suite passed.'.PHP_EOL;

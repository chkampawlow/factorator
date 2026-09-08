<?php

function auditStateMerge(array $state,array $changes):array{
    foreach($changes as $key=>$value){
        if(is_array($value)&&isset($state[$key])&&is_array($state[$key]))$state[$key]=auditStateMerge($state[$key],$value);
        else $state[$key]=$value;
    }
    return $state;
}

function auditValuesAgree(array $state,array $before,string $prefix=''):array{
    $mismatches=[];
    foreach($before as $key=>$expected){$path=$prefix===''?(string)$key:$prefix.'.'.$key;
        if(!array_key_exists($key,$state)){$mismatches[]=$path.':missing';continue;}
        $actual=$state[$key];
        if(is_array($expected)&&is_array($actual))$mismatches=array_merge($mismatches,auditValuesAgree($actual,$expected,$path));
        elseif($actual!=$expected)$mismatches[]=$path.':expected='.json_encode($expected).':actual='.json_encode($actual);
    }
    return $mismatches;
}

function reconstructAuditTimeline(array $events):array{
    $state=[];$issues=[];$timeline=[];
    foreach($events as $event){
        $before=is_array($event['before_values']??null)?$event['before_values']:[];
        $after=is_array($event['after_values']??null)?$event['after_values']:[];
        if($state!==[]&&$before!==[]){foreach(auditValuesAgree($state,$before) as $issue)$issues[]=['audit_id'=>$event['id']??null,'issue'=>$issue];}
        $state=auditStateMerge($state,$after);
        $timeline[]=['id'=>$event['id']??null,'action'=>$event['action']??null,'created_at'=>$event['created_at']??null,'request_id'=>$event['request_id']??null,'state_after'=>$state];
    }
    return ['reconstructable'=>$issues===[],'issues'=>$issues,'current_state'=>$state,'timeline'=>$timeline];
}

function loadAuditEntityEvents(mysqli $conn,int $tenantId,string $entityType,string $entityId):array{
    $stmt=$conn->prepare('SELECT id,action,before_values,after_values,request_id,created_at FROM app_audit_log WHERE tenant_id=? AND entity_type=? AND entity_id=? ORDER BY id');
    $stmt->bind_param('iss',$tenantId,$entityType,$entityId);$stmt->execute();$rows=$stmt->get_result()->fetch_all(MYSQLI_ASSOC);$stmt->close();
    foreach($rows as &$row){$row['before_values']=$row['before_values']?json_decode($row['before_values'],true):null;$row['after_values']=$row['after_values']?json_decode($row['after_values'],true):null;}
    return $rows;
}

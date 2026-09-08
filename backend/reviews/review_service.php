<?php
function reviewEntityExists(mysqli $c,int $uid,string $type,int $id):bool{
    $map=['VAT_PERIOD'=>['erp_vat_periods','id'],'ACCOUNTING_PERIOD'=>['erp_accounting_periods','id'],'CONTRIBUTION_PERIOD'=>['erp_contribution_periods','id'],'EMPLOYER_DECLARATION'=>['erp_employer_declarations','id'],'FISCAL_RECONCILIATION'=>['erp_fiscal_reconciliations','id'],'TAX_SCHEDULE_ENTRY'=>['erp_tax_schedule_entries','id'],'FILING_ARCHIVE'=>['erp_filing_archives','id']];if(!isset($map[$type]))return false;[$table,$column]=$map[$type];$s=$c->prepare("SELECT $column FROM $table WHERE $column=? AND user_id=? LIMIT 1");$s->bind_param('ii',$id,$uid);$s->execute();$found=(bool)$s->get_result()->fetch_assoc();$s->close();return$found;
}
function reviewEventHash(int $uid,string $type,int $entityId,string $action,string $note,int $actor,string $role,?string $previous):string{return hash('sha256',implode("\n",[$uid,$type,$entityId,$action,$note,$actor,$role,$previous??'']));}

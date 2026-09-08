<?php
function taxScheduleCalculation(string $type,float $gross,?float $opening,?float $rate,?float $accounting,?float $fiscal):array{
    if($gross<0)throw new InvalidArgumentException('Gross amount cannot be negative');
    if($type==='DEPRECIATION'){
        if($opening===null||$rate===null||$opening<0||$rate<0||$rate>100)throw new InvalidArgumentException('Depreciation requires opening book value and an annual rate between 0 and 100');
        $calculated=round(min($opening,$gross*$rate/100),3);$accounting=$accounting??$calculated;$fiscal=$fiscal??$accounting;$closing=round(max(0,$opening-$accounting),3);
    }else{$accounting=$accounting??$gross;$fiscal=$fiscal??$accounting;$closing=null;}
    if($accounting<0||$fiscal<0)throw new InvalidArgumentException('Accounting and fiscal amounts cannot be negative');
    if($type==='SUBSIDY'){$addition=round(max(0,$fiscal-$accounting),3);$deduction=round(max(0,$accounting-$fiscal),3);}
    else{$addition=round(max(0,$accounting-$fiscal),3);$deduction=round(max(0,$fiscal-$accounting),3);}
    return['accounting_amount'=>round($accounting,3),'fiscal_amount'=>round($fiscal,3),'fiscal_addition'=>$addition,'fiscal_deduction'=>$deduction,'closing_book_value'=>$closing];
}

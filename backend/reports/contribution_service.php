<?php
function contributionDecimal($value,string $label):string{
    $raw=trim((string)$value);if(!preg_match('/^\d+(?:\.\d+)?$/',$raw))throw new InvalidArgumentException("$label must be a non-negative decimal");return bcadd($raw,'0',6);
}
function contributionDates(string $month):array{
    if(!preg_match('/^\d{4}-(0[1-9]|1[0-2])$/',$month))throw new InvalidArgumentException('Month must use YYYY-MM');
    $start=new DateTimeImmutable($month.'-01');return[$start->format('Y-m-d'),$start->modify('last day of this month')->format('Y-m-d')];
}
function resolveContributionConfig(mysqli $conn,int $userId,string $contribution,string $date):array{
    $stmt=$conn->prepare("SELECT * FROM erp_contribution_configs WHERE user_id=? AND contribution=? AND effective_from<=? AND(effective_to IS NULL OR effective_to>=?) ORDER BY effective_from DESC,id DESC LIMIT 1");
    $stmt->bind_param('isss',$userId,$contribution,$date,$date);$stmt->execute();$row=$stmt->get_result()->fetch_assoc();$stmt->close();
    if(!$row)throw new DomainException("No effective $contribution configuration exists for this period");return $row;
}
function contributionAmount(string $basis,string $rate):string{return number_format(round((float)$basis*(float)$rate/100,3),3,'.','');}

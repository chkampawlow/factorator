<?php

declare(strict_types=1);

function reportPresetKinds(): array
{
    return ['CUSTOM','CURRENT_MONTH','PREVIOUS_MONTH','CURRENT_QUARTER','CURRENT_YEAR','PREVIOUS_YEAR','LAST_30_DAYS'];
}

function validateReportPresetInput(string $name, string $kind, ?string $from, ?string $to): array
{
    $name = trim(preg_replace('/\s+/u', ' ', $name) ?? '');
    $kind = strtoupper(trim($kind));
    if (mb_strlen($name) < 2 || mb_strlen($name) > 80) throw new InvalidArgumentException('Preset name must contain between 2 and 80 characters.');
    if (!in_array($kind, reportPresetKinds(), true)) throw new InvalidArgumentException('Unsupported report period type.');
    if ($kind === 'CUSTOM') {
        $from = trim((string)$from);$to = trim((string)$to);
        if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $from) || !preg_match('/^\d{4}-\d{2}-\d{2}$/', $to) || $to < $from) {
            throw new InvalidArgumentException('Custom report dates are invalid.');
        }
    } else {
        $from = null;$to = null;
    }
    return [$name,$kind,$from,$to];
}

function resolveReportPresetPeriod(string $kind, ?string $from, ?string $to, ?DateTimeImmutable $today = null): array
{
    $kind = strtoupper(trim($kind));
    $today ??= new DateTimeImmutable('today', new DateTimeZone('Africa/Tunis'));
    switch ($kind) {
        case 'CUSTOM':
            [,,$from,$to] = validateReportPresetInput('ok', $kind, $from, $to);
            return ['from'=>$from,'to'=>$to];
        case 'CURRENT_MONTH':
            return ['from'=>$today->modify('first day of this month')->format('Y-m-d'),'to'=>$today->format('Y-m-d')];
        case 'PREVIOUS_MONTH':
            $month = $today->modify('first day of previous month');
            return ['from'=>$month->format('Y-m-d'),'to'=>$month->modify('last day of this month')->format('Y-m-d')];
        case 'CURRENT_QUARTER':
            $startMonth = ((int)floor(((int)$today->format('n') - 1) / 3) * 3) + 1;
            $start = $today->setDate((int)$today->format('Y'), $startMonth, 1);
            return ['from'=>$start->format('Y-m-d'),'to'=>$today->format('Y-m-d')];
        case 'CURRENT_YEAR':
            return ['from'=>$today->format('Y-01-01'),'to'=>$today->format('Y-m-d')];
        case 'PREVIOUS_YEAR':
            $year = (int)$today->format('Y') - 1;
            return ['from'=>sprintf('%04d-01-01',$year),'to'=>sprintf('%04d-12-31',$year)];
        case 'LAST_30_DAYS':
            return ['from'=>$today->sub(new DateInterval('P29D'))->format('Y-m-d'),'to'=>$today->format('Y-m-d')];
    }
    throw new InvalidArgumentException('Unsupported report period type.');
}

function presentReportPreset(array $row, ?DateTimeImmutable $today = null): array
{
    $period = resolveReportPresetPeriod((string)$row['period_kind'], $row['date_from'] ?? null, $row['date_to'] ?? null, $today);
    return [
        'id'=>(int)$row['id'],'name'=>(string)$row['name'],'period_kind'=>(string)$row['period_kind'],
        'date_from'=>$row['date_from']??null,'date_to'=>$row['date_to']??null,
        'resolved_from'=>$period['from'],'resolved_to'=>$period['to'],
        'created_at'=>$row['created_at']??null,'updated_at'=>$row['updated_at']??null,
    ];
}

function reportPresetForTenant(mysqli $conn, int $userId, int $id): ?array
{
    $stmt=$conn->prepare('SELECT id,user_id,name,period_kind,date_from,date_to,created_at,updated_at FROM erp_report_presets WHERE id=? AND user_id=? LIMIT 1');
    $stmt->bind_param('ii',$id,$userId);$stmt->execute();$row=$stmt->get_result()->fetch_assoc()?:null;$stmt->close();
    return $row ? presentReportPreset($row) : null;
}

function listReportPresets(mysqli $conn, int $userId): array
{
    $stmt=$conn->prepare('SELECT id,user_id,name,period_kind,date_from,date_to,created_at,updated_at FROM erp_report_presets WHERE user_id=? ORDER BY name,id LIMIT 50');
    $stmt->bind_param('i',$userId);$stmt->execute();$rows=$stmt->get_result()->fetch_all(MYSQLI_ASSOC);$stmt->close();
    return array_map(static fn(array $row):array=>presentReportPreset($row),$rows);
}

function saveReportPreset(mysqli $conn, int $userId, int $actorId, int $id, string $name, string $kind, ?string $from, ?string $to): array
{
    if ($userId<=0||$actorId<=0||$id<0) throw new InvalidArgumentException('Invalid report preset request.');
    [$name,$kind,$from,$to]=validateReportPresetInput($name,$kind,$from,$to);
    try {
        if ($id>0) {
            $existing=reportPresetForTenant($conn,$userId,$id);if(!$existing)throw new OutOfBoundsException('Report preset not found.');
            $stmt=$conn->prepare('UPDATE erp_report_presets SET name=?,period_kind=?,date_from=?,date_to=? WHERE id=? AND user_id=?');
            $stmt->bind_param('ssssii',$name,$kind,$from,$to,$id,$userId);$stmt->execute();$stmt->close();
        } else {
            $stmt=$conn->prepare('SELECT COUNT(*) n FROM erp_report_presets WHERE user_id=?');$stmt->bind_param('i',$userId);$stmt->execute();$count=(int)$stmt->get_result()->fetch_assoc()['n'];$stmt->close();
            if($count>=50)throw new DomainException('A maximum of 50 report presets is allowed.');
            $stmt=$conn->prepare('INSERT INTO erp_report_presets(user_id,name,period_kind,date_from,date_to,created_by) VALUES(?,?,?,?,?,?)');
            $stmt->bind_param('issssi',$userId,$name,$kind,$from,$to,$actorId);$stmt->execute();$id=(int)$stmt->insert_id;$stmt->close();
        }
    } catch (mysqli_sql_exception $error) {
        if ((int)$error->getCode()===1062) throw new InvalidArgumentException('A report preset with this name already exists.');
        throw $error;
    }
    $preset=reportPresetForTenant($conn,$userId,$id);if(!$preset)throw new RuntimeException('Could not load the saved report preset.');return $preset;
}

function deleteReportPreset(mysqli $conn, int $userId, int $id): ?array
{
    $preset=reportPresetForTenant($conn,$userId,$id);if(!$preset)return null;
    $stmt=$conn->prepare('DELETE FROM erp_report_presets WHERE id=? AND user_id=?');$stmt->bind_param('ii',$id,$userId);$stmt->execute();$deleted=$stmt->affected_rows===1;$stmt->close();
    return $deleted?$preset:null;
}

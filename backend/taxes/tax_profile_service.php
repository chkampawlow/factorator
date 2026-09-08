<?php

function ensureTaxProfileSchema(mysqli $conn): void
{
    static $done=false; if($done)return;
    // Read-only schema guard. Deployment migrations own every DDL change.
    $conn->query("SELECT id,user_id,vat_rate,fodec_rate,deductibility_rate,effective_from FROM erp_tax_profiles LIMIT 0");
    $conn->query("SELECT tax_profile_id FROM products LIMIT 0");
    $conn->query("SELECT tax_profile_id,currency,exchange_rate,total_tnd FROM erp_invoices LIMIT 0");
    $conn->query("SELECT tax_profile_id,fodec_rate,total_tnd FROM erp_invoice_items LIMIT 0");
    $done=true;
}

function money3(string $value): string {
    $adjustment = bccomp($value, '0', 4) < 0 ? '-0.0005' : '0.0005';
    return bcadd($value, $adjustment, 3);
}
function decimalInput($value,string $label,int $scale=6): string {
    $raw=trim((string)$value); if(!preg_match('/^-?\d+(?:\.\d+)?$/',$raw))throw new Exception("$label must be a decimal number");
    return bcadd($raw,'0',$scale);
}
function resolveTaxProfile(mysqli $conn,int $userId,int $profileId,int $productId,string $date): array {
    if($profileId<=0&&$productId>0){$s=$conn->prepare('SELECT tax_profile_id FROM products WHERE id=? AND user_id=?');$s->bind_param('ii',$productId,$userId);$s->execute();$r=$s->get_result()->fetch_assoc();$s->close();$profileId=(int)($r['tax_profile_id']??0);}
    if($profileId<=0)throw new Exception('A dated tax profile is required for every invoiced operation');
    $s=$conn->prepare("SELECT * FROM erp_tax_profiles WHERE id=? AND user_id=? AND effective_from<=? AND (effective_to IS NULL OR effective_to>=?) LIMIT 1");$s->bind_param('iiss',$profileId,$userId,$date,$date);$s->execute();$p=$s->get_result()->fetch_assoc();$s->close();if(!$p)throw new Exception('Tax profile is missing, expired, or not yet effective');return $p;
}

function ensureProductTaxProfileForVatRate(
    mysqli $conn,
    int $userId,
    int $productId,
    float $vatRate,
    string $effectiveDate
): int {
    ensureTaxProfileSchema($conn);
    if ($productId <= 0) throw new InvalidArgumentException('A valid product is required');
    if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $effectiveDate)) $effectiveDate = date('Y-m-d');

    $product = $conn->prepare('SELECT tax_profile_id FROM products WHERE id=? AND user_id=? LIMIT 1 FOR UPDATE');
    $product->bind_param('ii', $productId, $userId);
    $product->execute();
    $currentProfileId = (int)($product->get_result()->fetch_assoc()['tax_profile_id'] ?? 0);
    $product->close();
    if ($currentProfileId > 0) return $currentProfileId;

    $profile = $conn->prepare("SELECT id FROM erp_tax_profiles
        WHERE user_id=? AND ABS(vat_rate-?)<=0.0005
          AND effective_from<=? AND (effective_to IS NULL OR effective_to>=?)
        ORDER BY effective_from DESC,id DESC LIMIT 1");
    $profile->bind_param('idss', $userId, $vatRate, $effectiveDate, $effectiveDate);
    $profile->execute();
    $profileId = (int)($profile->get_result()->fetch_assoc()['id'] ?? 0);
    $profile->close();

    if ($profileId <= 0) {
        $normalizedRate = number_format(max(0, min(100, $vatRate)), 3, '.', '');
        $name = 'TVA ' . $normalizedRate . '%';
        $isExempt = (float)$normalizedRate <= 0.0005 ? 1 : 0;
        $taxRegime = $isExempt ? 'EXEMPT' : 'STANDARD';
        $deductibilityRate = $isExempt ? 0.0 : 100.0;
        $effectiveFrom = '2000-01-01';
        $insert = $conn->prepare("INSERT IGNORE INTO erp_tax_profiles
            (user_id,name,vat_rate,vat_exempt,fodec_applicable,fodec_rate,tax_regime,deductibility_rate,effective_from)
            VALUES(?,?,?, ?,0,0,?,?,?)");
        $insert->bind_param('isdisds', $userId, $name, $vatRate, $isExempt, $taxRegime, $deductibilityRate, $effectiveFrom);
        $insert->execute();
        $insert->close();

        $profile = $conn->prepare("SELECT id FROM erp_tax_profiles
            WHERE user_id=? AND ABS(vat_rate-?)<=0.0005
              AND effective_from<=? AND (effective_to IS NULL OR effective_to>=?)
            ORDER BY effective_from DESC,id DESC LIMIT 1");
        $profile->bind_param('idss', $userId, $vatRate, $effectiveDate, $effectiveDate);
        $profile->execute();
        $profileId = (int)($profile->get_result()->fetch_assoc()['id'] ?? 0);
        $profile->close();
    }
    if ($profileId <= 0) throw new RuntimeException('Could not resolve a tax profile for the received product');

    $assign = $conn->prepare('UPDATE products SET tax_profile_id=? WHERE id=? AND user_id=? AND tax_profile_id IS NULL');
    $assign->bind_param('iii', $profileId, $productId, $userId);
    $assign->execute();
    $assign->close();
    return $profileId;
}
function calculateTaxLine($qty,$price,$discount,array $profile,string $exchangeRate): array {
    $q=decimalInput($qty,'Quantity');$p=decimalInput($price,'Price');$d=decimalInput($discount,'Discount');
    if(bccomp($q,'0',6)<=0||bccomp($p,'0',6)<0||bccomp($d,'0',6)<0||bccomp($d,'100',6)>0)throw new Exception('Invalid quantity, price, or discount');
    $gross=bcmul($q,$p,6);$net=bcmul($gross,bcsub('1',bcdiv($d,'100',6),6),6);
    $regime=strtoupper((string)$profile['tax_regime']);
    if(!in_array($regime,['STANDARD','SUSPENDED','EXEMPT','OUT_OF_SCOPE'],true))throw new Exception('Unsupported tax regime');
    $vatRate=($regime==='STANDARD'&&(int)$profile['vat_exempt']!==1)?decimalInput($profile['vat_rate'],'VAT rate'):'0.000000';
    $deductibility=decimalInput($profile['deductibility_rate']??'100','Deductibility rate');
    if(bccomp($deductibility,'0',6)<0||bccomp($deductibility,'100',6)>0)throw new Exception('Deductibility rate must be between 0 and 100');
    if($regime!=='STANDARD')$deductibility='0.000000';
    $fodecRate=((int)$profile['fodec_applicable']===1)?decimalInput($profile['fodec_rate'],'FODEC rate'):'0.000000';
    $fodec=bcmul($net,bcdiv($fodecRate,'100',6),6);$vatBase=bcadd($net,$fodec,6);$vat=bcmul($vatBase,bcdiv($vatRate,'100',6),6);$total=bcadd($vatBase,$vat,6);
    $rate=decimalInput($exchangeRate,'Exchange rate',8);
    return ['subtotal'=>money3($net),'vat_rate'=>money3($vatRate),'fodec_rate'=>money3($fodecRate),'fodec_amount'=>money3($fodec),'vat'=>money3($vat),'total'=>money3($total),'subtotal_tnd'=>money3(bcmul($net,$rate,8)),'vat_tnd'=>money3(bcmul($vat,$rate,8)),'tax_tnd'=>money3(bcmul(bcadd($fodec,$vat,6),$rate,8)),'total_tnd'=>money3(bcmul($total,$rate,8)),'tax_regime'=>$regime,'deductibility_rate'=>money3($deductibility),'legal_basis'=>(string)($profile['legal_basis']??''),'certificate_reference'=>(string)($profile['certificate_reference']??'')];
}

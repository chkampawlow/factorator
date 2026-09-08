<?php

header('Content-Type: application/json');
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/audit.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/tax_profile_service.php';

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') throw new Exception('Method not allowed');
    $userId = (int) requireAuth()->id;
    $data = json_decode(file_get_contents('php://input'), true) ?: [];
    $name = trim((string) ($data['name'] ?? ''));
    $vat = decimalInput($data['vat_rate'] ?? '0', 'VAT rate');
    $fodec = decimalInput($data['fodec_rate'] ?? '0', 'FODEC rate');
    $vatExempt = filter_var($data['vat_exempt'] ?? false, FILTER_VALIDATE_BOOLEAN) ? 1 : 0;
    $fodecApplicable = filter_var($data['fodec_applicable'] ?? false, FILTER_VALIDATE_BOOLEAN) ? 1 : 0;
    $regime = strtoupper(trim((string) ($data['tax_regime'] ?? 'STANDARD')));
    $deductibility = decimalInput($data['deductibility_rate'] ?? '100', 'Deductibility rate');
    $from = (string) ($data['effective_from'] ?? '');
    $to = trim((string) ($data['effective_to'] ?? '')) ?: null;
    $legal = trim((string) ($data['legal_basis'] ?? ''));
    $certificate = trim((string) ($data['certificate_reference'] ?? ''));
    if ($name==='' || !in_array($regime,['STANDARD','SUSPENDED','EXEMPT','OUT_OF_SCOPE'],true)
        || !preg_match('/^\d{4}-\d{2}-\d{2}$/',$from)
        || ($to!==null && !preg_match('/^\d{4}-\d{2}-\d{2}$/',$to))
        || ($to!==null && $to<$from) || bccomp($vat,'0',6)<0 || bccomp($fodec,'0',6)<0
        || bccomp($deductibility,'0',6)<0 || bccomp($deductibility,'100',6)>0) {
        throw new Exception('Invalid tax profile');
    }
    if ($regime!=='STANDARD' && $legal==='' && $certificate==='') {
        throw new Exception('Suspended, exempt, and out-of-scope profiles require a legal basis or reference');
    }
    if ($regime!=='STANDARD' && bccomp($vat,'0',6)!==0) throw new Exception('Only standard profiles may charge VAT');
    if ($regime!=='STANDARD') $deductibility='0.000000';

    $conn = db();
    requireAnyPermission($conn, $userId, ['products.edit', 'services.edit', 'reports.view']);
    ensureTaxProfileSchema($conn);
    $conn->begin_transaction();
    $stmt = $conn->prepare('INSERT INTO erp_tax_profiles
        (user_id,name,vat_rate,vat_exempt,fodec_applicable,fodec_rate,tax_regime,deductibility_rate,
         legal_basis,certificate_reference,effective_from,effective_to)
        VALUES(?,?,?,?,?,?,?,?,?,?,?,?)');
    $stmt->bind_param('isdiidsdssss', $userId,$name,$vat,$vatExempt,$fodecApplicable,
        $fodec,$regime,$deductibility,$legal,$certificate,$from,$to);
    $stmt->execute();
    $profileId = (int) $stmt->insert_id;
    $stmt->close();
    auditLog($conn, $userId, $userId, 'TAX_PROFILE.CREATED', 'TAX_PROFILE', $profileId,
        null, ['name'=>$name,'vat_rate'=>$vat,'vat_exempt'=>(bool)$vatExempt,
        'fodec_applicable'=>(bool)$fodecApplicable,'fodec_rate'=>$fodec,
        'tax_regime'=>$regime,'deductibility_rate'=>$deductibility,'legal_basis'=>$legal,'certificate_reference'=>$certificate,
        'effective_from'=>$from,'effective_to'=>$to]);
    $conn->commit();
    jsonResponse(['success'=>true,'id'=>$profileId]);
} catch (Throwable $e) {
    if (isset($conn)) { try { $conn->rollback(); } catch (Throwable $ignored) {} }
    jsonResponse(['success'=>false,'message'=>$e->getMessage()],400);
}

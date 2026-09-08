<?php

require_once __DIR__ . '/../config/validator.php';
require_once __DIR__ . '/../config/entity_reference.php';

function ensureSuppliersTable(mysqli $conn): void
{
    static $ensured = false;
    if ($ensured) return;
    $conn->query("SELECT id,reference,name,user_id FROM suppliers LIMIT 0");
    $ensured = true;
}

function normalizeSupplierType(string $value): string
{
    return strtolower(trim($value)) === 'individual' ? 'individual' : 'company';
}

function validateSupplierPayload(array $data): array
{
    $type = normalizeSupplierType(getRequiredString($data, 'type', 'Type'));
    $name = getRequiredString($data, 'name', 'Name');
    $name = function_exists('mb_strtoupper') ? mb_strtoupper($name, 'UTF-8') : strtoupper($name);
    $email = strtolower(getOptionalString($data, 'email'));
    $phone = preg_replace('/\s+/', ' ', getOptionalString($data, 'phone'));
    $address = getOptionalString($data, 'address');
    $fiscalId = strtoupper(getOptionalString($data, 'fiscalId'));

    validateEnum($type, ['company', 'individual'], 'Type');
    validateMaxLength($name, 255, 'Name');
    validateMaxLength($email, 255, 'Email');
    validateMaxLength($phone, 30, 'Phone');
    validateMaxLength($address, 255, 'Address');
    validateMaxLength($fiscalId, 30, 'Fiscal ID');
    validateEmailIfPresent($email);

    return [
        'type' => $type,
        'name' => $name,
        'email' => $email,
        'phone' => $phone,
        'address' => $address,
        'fiscalId' => $fiscalId,
    ];
}

function supplierRow(array $row): array
{
    return [
        'id' => (int)($row['id'] ?? 0),
        'reference' => (string)($row['reference'] ?? ''),
        'type' => normalizeSupplierType((string)($row['type'] ?? 'company')),
        'name' => (string)($row['name'] ?? ''),
        'email' => (string)($row['email'] ?? ''),
        'phone' => (string)($row['phone'] ?? ''),
        'address' => (string)($row['address'] ?? ''),
        'fiscalId' => (string)($row['fiscal_id'] ?? ''),
    ];
}

function getSupplierById(mysqli $conn, int $userId, int $id): ?array
{
    $stmt = $conn->prepare("
        SELECT id, reference, type, name, email, phone, address, fiscal_id
        FROM suppliers
        WHERE id = ? AND user_id = ?
        LIMIT 1
    ");

    if (!$stmt) {
        throw new Exception('Failed to prepare supplier lookup: ' . $conn->error);
    }

    $stmt->bind_param('ii', $id, $userId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc() ?: null;
    $stmt->close();

    return $row ? supplierRow($row) : null;
}

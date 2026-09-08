<?php

declare(strict_types=1);

require_once dirname(__DIR__, 2) . '/config/db.php';
require_once dirname(__DIR__, 2) . '/config/validator.php';
require_once dirname(__DIR__, 2) . '/config/entity_reference.php';

function aiCreateClientRecord(int $userId, array $input): array
{
    $type = strtolower(trim((string) ($input['type'] ?? '')));
    $name = trim((string) ($input['name'] ?? ''));
    $name = function_exists('mb_strtoupper') ? mb_strtoupper($name, 'UTF-8') : strtoupper($name);
    $email = strtolower(trim((string) ($input['email'] ?? '')));
    $phone = preg_replace('/\s+/', ' ', trim((string) ($input['phone'] ?? ''))) ?: '';
    $address = trim((string) ($input['address'] ?? ''));
    $fiscalId = strtoupper(trim((string) ($input['fiscalId'] ?? '')));
    $cin = trim((string) ($input['cin'] ?? ''));
    $paymentTermsDays = (int)($input['payment_terms_days'] ?? 30);
    if (!in_array($paymentTermsDays, [0, 30, 60], true)) {
        throw new Exception('Payment terms must be immediate, 30 days, or 60 days.');
    }

    validateEnum($type, ['company', 'individual'], 'Type');

    if ($name === '') {
        throw new Exception('Name is required');
    }

    validateMaxLength($name, 255, 'Name');
    validateMaxLength($email, 255, 'Email');
    validateMaxLength($phone, 20, 'Phone');
    validateMaxLength($address, 255, 'Address');
    validateMaxLength($fiscalId, 13, 'Fiscal ID');
    validateMaxLength($cin, 8, 'CIN');

    validateEmailIfPresent($email);
    validatePhoneIfPresent($phone);
    validateAddressIfPresent($address);

    if ($type === 'company') {
        if ($fiscalId === '') {
            throw new Exception('Fiscal ID is required for company');
        }

        validateFiscalId($fiscalId);
        $cin = '';
    }

    if ($type === 'individual') {
        if ($cin === '') {
            throw new Exception('CIN is required for individual');
        }

        validateCin($cin);
        $fiscalId = '';
    }

    $conn = db();
    ensureClientUnique(
        $conn,
        $userId,
        $email !== '' ? $email : null,
        $fiscalId !== '' ? $fiscalId : null,
        $cin !== '' ? $cin : null,
    );

    $reference = nextEntityReference($conn, $userId, 'CLIENT');

    $stmt = $conn->prepare("
        INSERT INTO clients (
            user_id,
            reference,
            type,
            name,
            email,
            phone,
            address,
            fiscalId,
            cin,
            payment_terms_days
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ");

    if (!$stmt) {
        throw new Exception('Failed to prepare add client query: ' . $conn->error);
    }

    $stmt->bind_param(
        'issssssssi',
        $userId,
        $reference,
        $type,
        $name,
        $email,
        $phone,
        $address,
        $fiscalId,
        $cin,
        $paymentTermsDays
    );

    $stmt->execute();

    if ($stmt->error) {
        throw new Exception('Failed to add client: ' . $stmt->error);
    }

    $newId = (int) $conn->insert_id;
    $stmt->close();

    return [
        'id' => $newId,
        'reference' => $reference,
        'type' => $type,
        'name' => $name,
        'email' => $email,
        'phone' => $phone,
        'address' => $address,
        'fiscalId' => $fiscalId,
        'cin' => $cin,
        'payment_terms_days' => $paymentTermsDays,
    ];
}

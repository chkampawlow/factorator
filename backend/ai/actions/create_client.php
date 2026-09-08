<?php

declare(strict_types=1);

require_once __DIR__ . '/_bootstrap.php';

$data = input();
$userId = authenticatedUserId();
$pdo = db();

ensureUserExists($pdo, $userId);

$type = strtolower(requiredString($data, 'type', 50));

if (!in_array($type, ['company', 'individual'], true)) {
    respond(422, [
        'success' => false,
        'message' => 'type must be company or individual.',
    ]);
}

$name = requiredString($data, 'name');
$name = function_exists('mb_strtoupper') ? mb_strtoupper($name, 'UTF-8') : strtoupper($name);
$email = optionalString($data, 'email');
$phone = optionalString($data, 'phone', 100);
$address = optionalString($data, 'address', 5000);
$fiscalId = optionalString($data, 'fiscalId', 100);
$cin = optionalString($data, 'cin', 100);

if ($email !== null && filter_var($email, FILTER_VALIDATE_EMAIL) === false) {
    respond(422, [
        'success' => false,
        'message' => 'email is invalid.',
    ]);
}

if ($type === 'company' && $fiscalId === null) {
    respond(422, [
        'success' => false,
        'message' => 'fiscalId is required for a company.',
    ]);
}

if ($type === 'individual' && $cin === null) {
    respond(422, [
        'success' => false,
        'message' => 'cin is required for an individual.',
    ]);
}

$fiscalId = $type === 'company' ? $fiscalId : null;
$cin = $type === 'individual' ? $cin : null;

$duplicate = $pdo->prepare(
    'SELECT id
     FROM clients
     WHERE user_id = :user_id
       AND is_archived = 0
       AND (
            (:fiscal_id IS NOT NULL AND fiscalId = :fiscal_id)
         OR (:cin IS NOT NULL AND cin = :cin)
       )
     LIMIT 1'
);

$duplicate->execute([
    'user_id' => $userId,
    'fiscal_id' => $fiscalId,
    'cin' => $cin,
]);

if ($duplicate->fetch()) {
    respond(409, [
        'success' => false,
        'message' => 'A client with this fiscal ID or CIN already exists.',
    ]);
}

$pdo->beginTransaction();
try {
    $sequence = $pdo->prepare(
        "INSERT INTO erp_entity_reference_sequences (user_id, entity_type, next_number)
         VALUES (:user_id, 'CLIENT', 1)
         ON DUPLICATE KEY UPDATE next_number = next_number"
    );
    $sequence->execute(['user_id' => $userId]);
    $sequence = $pdo->prepare(
        "SELECT next_number FROM erp_entity_reference_sequences
         WHERE user_id = :user_id AND entity_type = 'CLIENT' FOR UPDATE"
    );
    $sequence->execute(['user_id' => $userId]);
    $number = (int)$sequence->fetchColumn();
    $reference = 'C' . str_pad((string)$number, 6, '0', STR_PAD_LEFT);
    $sequence = $pdo->prepare(
        "UPDATE erp_entity_reference_sequences SET next_number = :next_number
         WHERE user_id = :user_id AND entity_type = 'CLIENT'"
    );
    $sequence->execute(['next_number' => $number + 1, 'user_id' => $userId]);

    $statement = $pdo->prepare(
    'INSERT INTO clients
        (reference, type, name, email, phone, address, fiscalId, cin, user_id)
     VALUES
        (:reference, :type, :name, :email, :phone, :address, :fiscal_id, :cin, :user_id)'
    );

    $statement->execute([
    'reference' => $reference,
    'type' => $type,
    'name' => $name,
    'email' => $email,
    'phone' => $phone,
    'address' => $address,
    'fiscal_id' => $fiscalId,
    'cin' => $cin,
    'user_id' => $userId,
    ]);
    $clientId = (int)$pdo->lastInsertId();
    $pdo->commit();
} catch (Throwable $error) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    throw $error;
}

respond(201, [
    'success' => true,
    'message' => 'Client created successfully.',
    'client_id' => $clientId,
    'reference' => $reference,
]);

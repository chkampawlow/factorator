<?php

declare(strict_types=1);

require_once __DIR__ . '/_bootstrap.php';

$data = input();
$userId = authenticatedUserId();
$clientId = positiveId($data, 'id');
$pdo = db();

$existing = $pdo->prepare(
    'SELECT *
     FROM clients
     WHERE id = :id
       AND user_id = :user_id
       AND is_archived = 0
     LIMIT 1'
);
$existing->execute([
    'id' => $clientId,
    'user_id' => $userId,
]);
$client = $existing->fetch();

if (!$client) {
    respond(404, [
        'success' => false,
        'message' => 'Client not found.',
    ]);
}

$type = strtolower(trim((string) ($data['type'] ?? $client['type'])));
$name = trim((string) ($data['name'] ?? $client['name']));
$email = array_key_exists('email', $data)
    ? optionalString($data, 'email')
    : $client['email'];
$phone = array_key_exists('phone', $data)
    ? optionalString($data, 'phone', 100)
    : $client['phone'];
$address = array_key_exists('address', $data)
    ? optionalString($data, 'address', 5000)
    : $client['address'];
$fiscalId = array_key_exists('fiscalId', $data)
    ? optionalString($data, 'fiscalId', 100)
    : $client['fiscalId'];
$cin = array_key_exists('cin', $data)
    ? optionalString($data, 'cin', 100)
    : $client['cin'];

if (!in_array($type, ['company', 'individual'], true)) {
    respond(422, [
        'success' => false,
        'message' => 'type must be company or individual.',
    ]);
}

if ($name === '') {
    respond(422, [
        'success' => false,
        'message' => 'name is required.',
    ]);
}

if ($email !== null && $email !== '' &&
    filter_var($email, FILTER_VALIDATE_EMAIL) === false) {
    respond(422, [
        'success' => false,
        'message' => 'email is invalid.',
    ]);
}

if ($type === 'company') {
    $cin = null;

    if ($fiscalId === null || trim((string) $fiscalId) === '') {
        respond(422, [
            'success' => false,
            'message' => 'fiscalId is required for a company.',
        ]);
    }
} else {
    $fiscalId = null;

    if ($cin === null || trim((string) $cin) === '') {
        respond(422, [
            'success' => false,
            'message' => 'cin is required for an individual.',
        ]);
    }
}

$duplicate = $pdo->prepare(
    'SELECT id
     FROM clients
     WHERE user_id = :user_id
       AND id <> :id
       AND is_archived = 0
       AND (
            (:fiscal_id IS NOT NULL AND fiscalId = :fiscal_id)
         OR (:cin IS NOT NULL AND cin = :cin)
       )
     LIMIT 1'
);
$duplicate->execute([
    'user_id' => $userId,
    'id' => $clientId,
    'fiscal_id' => $fiscalId,
    'cin' => $cin,
]);

if ($duplicate->fetch()) {
    respond(409, [
        'success' => false,
        'message' => 'Another client uses this fiscal ID or CIN.',
    ]);
}

$statement = $pdo->prepare(
    'UPDATE clients
     SET type = :type,
         name = :name,
         email = :email,
         phone = :phone,
         address = :address,
         fiscalId = :fiscal_id,
         cin = :cin
     WHERE id = :id
       AND user_id = :user_id'
);

$statement->execute([
    'type' => $type,
    'name' => $name,
    'email' => $email,
    'phone' => $phone,
    'address' => $address,
    'fiscal_id' => $fiscalId,
    'cin' => $cin,
    'id' => $clientId,
    'user_id' => $userId,
]);

respond(200, [
    'success' => true,
    'message' => 'Client updated successfully.',
    'client_id' => $clientId,
]);

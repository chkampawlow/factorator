<?php

/* =========================
   CORE VALIDATION
========================= */

function requireJsonBody(): array
{
    $data = json_decode(file_get_contents("php://input"), true);

    if (!is_array($data)) {
        throw new Exception("Invalid JSON body.");
    }

    return $data;
}

function getRequiredString(array $data, string $key, string $label): string
{
    $value = trim((string)($data[$key] ?? ''));

    if ($value === '') {
        throw new Exception("$label is required");
    }

    return $value;
}

function getOptionalString(array $data, string $key): string
{
    return trim((string)($data[$key] ?? ''));
}

function getRequiredInt(array $data, string $key, string $label): int
{
    $value = (int)($data[$key] ?? 0);

    if ($value <= 0) {
        throw new Exception("$label is required");
    }

    return $value;
}

function validateEnum(string $value, array $allowed, string $label): void
{
    if (!in_array($value, $allowed, true)) {
        throw new Exception("$label is invalid");
    }
}

function validateEmailIfPresent(string $email): void
{
    if ($email !== '' && !filter_var($email, FILTER_VALIDATE_EMAIL)) {
        throw new Exception("Invalid email format");
    }
}

function validateMaxLength(string $value, int $max, string $label): void
{
    if (mb_strlen($value) > $max) {
        throw new Exception("$label is too long");
    }
}

function validateDate(string $date, string $label): void
{
    $d = DateTime::createFromFormat('Y-m-d', $date);

    if (!$d || $d->format('Y-m-d') !== $date) {
        throw new Exception("$label must be YYYY-MM-DD");
    }
}

function validatePositiveNumber($value, string $label): float
{
    $num = (float)$value;

    if ($num < 0) {
        throw new Exception("$label must be positive");
    }

    return $num;
}

function validateNonNegativeInt($value, string $label): int
{
    if ($value === '' || $value === null) {
        return 0;
    }

    if (filter_var($value, FILTER_VALIDATE_INT) === false) {
        throw new Exception("$label must be a whole number");
    }

    $num = (int)$value;
    if ($num < 0) {
        throw new Exception("$label must be positive");
    }

    return $num;
}

function normalizeLanguage(?string $language): string
{
    $lang = strtolower(trim((string)$language));
    return in_array($lang, ['fr', 'en', 'ar'], true) ? $lang : 'en';
}


/* =========================
   CLIENT VALIDATION
========================= */

function validateClient(array $data): array
{
    $type = getRequiredString($data, 'type', 'Type');
    $name = getRequiredString($data, 'name', 'Name');
    $email = getOptionalString($data, 'email');
    $phone = getOptionalString($data, 'phone');
    $address = getOptionalString($data, 'address');
    $fiscalId = strtoupper(getOptionalString($data, 'fiscalId'));
    $cin = getOptionalString($data, 'cin');

    validateEnum($type, ['company', 'individual'], 'Type');
    validateEmailIfPresent($email);

    if ($type === 'company' && $fiscalId === '') {
        throw new Exception("Fiscal ID is required for company");
    }

    if ($type === 'company' && !preg_match('/^[0-9]{7}[A-Z]$/', $fiscalId)) {
        throw new Exception("Fiscal ID must match 1234567A");
    }

    if ($type === 'individual' && $cin === '') {
        throw new Exception("CIN is required for individual");
    }

    return compact(
        'type',
        'name',
        'email',
        'phone',
        'address',
        'fiscalId',
        'cin'
    );
}


/* =========================
   UNIQUE VALIDATION
========================= */

function ensureClientUnique(
    mysqli $conn,
    int $userId,
    ?string $email,
    ?string $fiscalId,
    ?string $cin,
    ?int $ignoreClientId = null
): void {

    // EMAIL
    if ($email) {
        $sql = "SELECT id FROM clients WHERE user_id = ? AND email = ?";
        if ($ignoreClientId) $sql .= " AND id != ?";
        $sql .= " LIMIT 1";

        $stmt = $conn->prepare($sql);
        if ($ignoreClientId) {
            $stmt->bind_param("isi", $userId, $email, $ignoreClientId);
        } else {
            $stmt->bind_param("is", $userId, $email);
        }
        $stmt->execute();

        if ($stmt->get_result()->num_rows > 0) {
            throw new Exception("Email already exists");
        }

        $stmt->close();
    }

    // FISCAL ID
    if ($fiscalId) {
        $sql = "SELECT id FROM clients WHERE user_id = ? AND fiscalId = ?";
        if ($ignoreClientId) $sql .= " AND id != ?";
        $sql .= " LIMIT 1";

        $stmt = $conn->prepare($sql);
        if ($ignoreClientId) {
            $stmt->bind_param("isi", $userId, $fiscalId, $ignoreClientId);
        } else {
            $stmt->bind_param("is", $userId, $fiscalId);
        }
        $stmt->execute();

        if ($stmt->get_result()->num_rows > 0) {
            throw new Exception("Fiscal ID already exists");
        }

        $stmt->close();
    }

    // CIN
    if ($cin) {
        $sql = "SELECT id FROM clients WHERE user_id = ? AND cin = ?";
        if ($ignoreClientId) $sql .= " AND id != ?";
        $sql .= " LIMIT 1";

        $stmt = $conn->prepare($sql);
        if ($ignoreClientId) {
            $stmt->bind_param("isi", $userId, $cin, $ignoreClientId);
        } else {
            $stmt->bind_param("is", $userId, $cin);
        }
        $stmt->execute();

        if ($stmt->get_result()->num_rows > 0) {
            throw new Exception("CIN already exists");
        }

        $stmt->close();
    }
}

function ensureUserFiscalIdUnique(
    mysqli $conn,
    string $fiscalId,
    ?int $ignoreUserId = null,
    string $column = 'fiscal_id'
): void {

    if ($fiscalId === '') return;

    $sql = "SELECT id FROM users WHERE {$column} = ?";
    if ($ignoreUserId) $sql .= " AND id != ?";
    $sql .= " LIMIT 1";

    $stmt = $conn->prepare($sql);

    if ($ignoreUserId) {
        $stmt->bind_param("si", $fiscalId, $ignoreUserId);
    } else {
        $stmt->bind_param("s", $fiscalId);
    }

    $stmt->execute();

    if ($stmt->get_result()->num_rows > 0) {
        throw new Exception("User fiscal ID already exists");
    }

    $stmt->close();
}
function validateFiscalId(string $fiscalId): void
{
    $v = strtoupper(trim($fiscalId));

    // Matricule fiscal (simple): 7 chiffres + 1 lettre majuscule (ex: 1234567A)
    if (!preg_match('/^[0-9]{7}[A-Z]{1}$/', $v)) {
        throw new Exception("Matricule fiscal invalide. Exemple: 1234567A");
    }
}

function validateCin(string $cin): void
{
    if (!preg_match('/^[0-9]{8}$/', $cin)) {
        throw new Exception("CIN must be exactly 8 digits.");
    }
}

function validatePhoneIfPresent(string $phone): void
{
    $p = trim($phone);
    if ($p === '') return;

    $compact = preg_replace('/\s+/', '', $p);

    // Generic E.164-ish: +<1-3 digits country><6-12 digits local>
    if (preg_match('/^\+\d{7,15}$/', $compact)) return;

    throw new Exception("Invalid phone number. Example: +216 20123456");
}

function validateAddressIfPresent(string $address): void
{
    if ($address !== '' && mb_strlen($address) < 5) {
        throw new Exception("Address is too short.");
    }
}

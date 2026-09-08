<?php

function passwordLength(string $password): int
{
    return function_exists('mb_strlen') ? mb_strlen($password, 'UTF-8') : strlen($password);
}

function assertStrongPassword(string $password, array $accountIdentifiers = []): void
{
    $length = passwordLength($password);
    if ($length < 12 || $length > 128) {
        throw new InvalidArgumentException('Password must contain between 12 and 128 characters.');
    }
    if ($password !== trim($password)) {
        throw new InvalidArgumentException('Password cannot start or end with whitespace.');
    }

    $normalized = strtolower($password);
    $commonPasswords = [
        '123456789012', '1234567890', 'password1234', 'password123',
        'qwerty123456', 'azerty123456', 'administrator', 'admin123456',
        'letmein123456', 'welcome123456', 'iloveyou1234', 'motdepasse123',
    ];
    if (in_array($normalized, $commonPasswords, true)) {
        throw new InvalidArgumentException('Choose a password that is not commonly used or compromised.');
    }
    if (preg_match('/^(.)\1{11,}$/us', $password) === 1) {
        throw new InvalidArgumentException('Password cannot consist of one repeated character.');
    }

    $normalizedCompact = preg_replace('/[^a-z0-9]/', '', $normalized) ?? '';
    foreach ($accountIdentifiers as $identifier) {
        $identifier = strtolower(trim((string)$identifier));
        if (str_contains($identifier, '@')) $identifier = explode('@', $identifier, 2)[0];
        $identifier = preg_replace('/[^a-z0-9]/', '', $identifier) ?? '';
        if (strlen($identifier) >= 4 && str_contains($normalizedCompact, $identifier)) {
            throw new InvalidArgumentException('Password must not contain your email, company name, or fiscal ID.');
        }
    }
}

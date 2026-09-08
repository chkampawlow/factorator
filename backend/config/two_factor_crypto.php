<?php

require_once __DIR__ . '/env.php';

function twoFactorEncryptionKey(): string
{
    if (empty($_ENV['TWO_FACTOR_ENCRYPTION_KEY'])) {
        loadEnv(__DIR__ . '/../.env');
    }

    $key = base64_decode((string)($_ENV['TWO_FACTOR_ENCRYPTION_KEY'] ?? ''), true);
    if ($key === false || strlen($key) !== 32) {
        throw new RuntimeException('TWO_FACTOR_ENCRYPTION_KEY must be a base64-encoded 32-byte key.');
    }

    return $key;
}

function encryptTwoFactorSecret(string $secret): string
{
    if ($secret === '') {
        throw new InvalidArgumentException('Two-factor secret cannot be empty.');
    }

    $nonce = random_bytes(12);
    $tag = '';
    $ciphertext = openssl_encrypt(
        $secret,
        'aes-256-gcm',
        twoFactorEncryptionKey(),
        OPENSSL_RAW_DATA,
        $nonce,
        $tag,
        'el-fatoura:2fa:v1',
        16
    );
    if ($ciphertext === false) {
        throw new RuntimeException('Unable to encrypt the two-factor secret.');
    }

    return 'enc:v1:' . base64_encode($nonce) . ':' . base64_encode($tag) . ':' . base64_encode($ciphertext);
}

function decryptTwoFactorSecret(string $encrypted): string
{
    $parts = explode(':', $encrypted, 5);
    if (count($parts) !== 5 || $parts[0] !== 'enc' || $parts[1] !== 'v1') {
        throw new RuntimeException('Two-factor secret is not encrypted.');
    }

    $nonce = base64_decode($parts[2], true);
    $tag = base64_decode($parts[3], true);
    $ciphertext = base64_decode($parts[4], true);
    if ($nonce === false || strlen($nonce) !== 12 || $tag === false || strlen($tag) !== 16 || $ciphertext === false) {
        throw new RuntimeException('Two-factor secret has an invalid encrypted format.');
    }

    $secret = openssl_decrypt(
        $ciphertext,
        'aes-256-gcm',
        twoFactorEncryptionKey(),
        OPENSSL_RAW_DATA,
        $nonce,
        $tag,
        'el-fatoura:2fa:v1'
    );
    if ($secret === false || $secret === '') {
        throw new RuntimeException('Unable to decrypt the two-factor secret.');
    }

    return $secret;
}

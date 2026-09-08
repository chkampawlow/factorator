<?php

require_once __DIR__ . '/../auth/password_policy.php';

$cases = [
    ['short', 'Short7!', [], false],
    ['common compromised', 'password1234', [], false],
    ['repeated characters', 'aaaaaaaaaaaa', [], false],
    ['email identifier', 'dayna11-Safe-Phrase!', ['dayna11@example.com'], false],
    ['fiscal identifier', 'Safe-1234567A-Phrase!', ['1234567A'], false],
    ['leading whitespace', ' Strong passphrase 2026!', [], false],
    ['long passphrase', 'Correct horse battery staple 2026!', [], true],
    ['symbols optional', 'four calm words together', [], true],
];

$failures = 0;
foreach ($cases as [$name, $password, $identifiers, $shouldPass]) {
    try {
        assertStrongPassword($password, $identifiers);
        $passed = true;
    } catch (InvalidArgumentException) {
        $passed = false;
    }

    if ($passed !== $shouldPass) {
        echo "FAIL {$name}\n";
        $failures++;
    } else {
        echo "PASS {$name}\n";
    }
}

exit($failures === 0 ? 0 : 1);

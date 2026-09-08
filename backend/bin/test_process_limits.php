<?php

require_once __DIR__ . '/../config/process.php';

function assertProcess(bool $condition, string $message): void
{
    if (!$condition) throw new RuntimeException('FAIL ' . $message);
    echo 'PASS ' . $message . "\n";
}

$injectionPayload = '; echo INJECTED && touch /tmp/el-fatoura-injected';
$arguments = runBoundedProcess([
    PHP_BINARY, '-r', 'echo json_encode(array_slice($argv, 1));', $injectionPayload,
], 2, 4096);
assertProcess($arguments['exitCode'] === 0, 'argument-array process completes');
assertProcess(json_decode($arguments['output'], true) === [$injectionPayload], 'shell metacharacters remain a literal argument');
assertProcess(!is_file('/tmp/el-fatoura-injected'), 'shell injection payload is not executed');

$timeout = runBoundedProcess([PHP_BINARY, '-r', 'sleep(5);'], 1, 4096);
assertProcess($timeout['exitCode'] === 124 && $timeout['timedOut'] === true, 'process timeout terminates long-running work');
assertProcess($timeout['elapsedMs'] < 3000, 'timeout returns promptly');

$oversized = runBoundedProcess([PHP_BINARY, '-r', 'echo str_repeat("x", 8192);'], 2, 1024);
assertProcess($oversized['exitCode'] === 125 && $oversized['outputExceeded'] === true, 'output limit terminates excessive output');
assertProcess(strlen($oversized['output']) <= 1024, 'captured output is capped');

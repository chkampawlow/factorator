<?php

declare(strict_types=1);

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

require_once __DIR__ . '/../config/env.php';
loadEnv(__DIR__ . '/../.env');
require_once __DIR__ . '/../config/logger.php';

if (!in_array('--send', $argv, true)) {
    fwrite(STDERR, "This command sends a real test alert. Re-run with --send after notifying the incident contact.\n");
    exit(2);
}

$url = trim((string)($_ENV['ERROR_MONITOR_WEBHOOK_URL'] ?? ''));
$secret = trim((string)($_ENV['ERROR_MONITOR_WEBHOOK_SECRET'] ?? ''));
if ($url === '' || !filter_var($url, FILTER_VALIDATE_URL) || $secret === '') {
    fwrite(STDERR, "ERROR_MONITOR_WEBHOOK_URL and ERROR_MONITOR_WEBHOOK_SECRET must be configured.\n");
    exit(2);
}

$record = [
    'timestamp' => (new DateTimeImmutable('now', new DateTimeZone('UTC')))->format('Y-m-d\TH:i:s.u\Z'),
    'level' => 'ERROR',
    'event' => 'MONITORING.TEST_ALERT',
    'request_id' => 'MONITORING-TEST-' . gmdate('YmdHis'),
    'method' => 'CLI',
    'endpoint' => 'backend/bin/send_monitoring_test.php',
    'tenant_id' => null,
    'actor_id' => null,
    'context' => [
        'test' => true,
        'environment' => (string)($_ENV['APP_ENV'] ?? 'unknown'),
        'instruction' => 'Acknowledge this test through the incident-response procedure.',
    ],
];

$delivered = appSendMonitoringAlert($record);
structuredLog($delivered ? 'INFO' : 'WARNING', $delivered ? 'MONITORING.TEST_DISPATCHED' : 'MONITORING.TEST_FAILED', [
    'test_request_id' => $record['request_id'],
]);

echo json_encode([
    'success' => $delivered,
    'event' => $record['event'],
    'request_id' => $record['request_id'],
    'receiver_accepted' => $delivered,
], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . PHP_EOL;

exit($delivered ? 0 : 1);

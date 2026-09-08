<?php

declare(strict_types=1);

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

final class CapturedReportResponse extends RuntimeException
{
    public function __construct(public array $payload, public int $status)
    {
        parent::__construct('Captured report response');
    }
}

$capturedReportLogs = [];

function jsonResponse(array $payload, int $status = 200): void
{
    throw new CapturedReportResponse($payload, $status);
}

function structuredLog(string $level, string $event, array $context = []): void
{
    global $capturedReportLogs;
    $capturedReportLogs[] = compact('level', 'event', 'context');
}

require_once __DIR__ . '/../reports/report_error.php';

function captureReportFailure(Throwable $error): CapturedReportResponse
{
    try {
        reportFailureResponse($error, 'Safe report failure.', 'REPORT_TEST_FAILED');
    } catch (CapturedReportResponse $response) {
        return $response;
    }

    throw new LogicException('The report error boundary did not respond.');
}

$failures = [];
$check = static function (bool $condition, string $label) use (&$failures): void {
    echo ($condition ? 'PASS ' : 'FAIL ') . $label . PHP_EOL;
    if (!$condition) $failures[] = $label;
};

$validation = captureReportFailure(new InvalidArgumentException('Controlled validation message.'));
$check($validation->status === 422 && $validation->payload['message'] === 'Controlled validation message.', 'validation errors remain actionable');

$missing = captureReportFailure(new OutOfBoundsException('Controlled missing-resource message.'));
$check($missing->status === 404 && $missing->payload['error_code'] === 'REPORT_RESOURCE_NOT_FOUND', 'missing report resources return 404');

$conflict = captureReportFailure(new DomainException('Controlled workflow conflict.'));
$check($conflict->status === 409 && $conflict->payload['error_code'] === 'REPORT_WORKFLOW_CONFLICT', 'workflow conflicts return 409');

$internalMarker = 'SQLSTATE[42S02]: Base table or view not found: secret_table';
$internal = captureReportFailure(new RuntimeException($internalMarker));
$check($internal->status === 500 && $internal->payload['message'] === 'Safe report failure.', 'internal failures return a generic message');
$check(!str_contains(json_encode($internal->payload), $internalMarker), 'internal exception details are absent from the response');
$lastLog = $capturedReportLogs[array_key_last($capturedReportLogs)] ?? [];
$check(($lastLog['event'] ?? '') === 'REPORT.ENDPOINT_FAILED' && ($lastLog['context']['message'] ?? '') === $internalMarker, 'internal details remain available in structured logs');

if ($failures !== []) exit(1);

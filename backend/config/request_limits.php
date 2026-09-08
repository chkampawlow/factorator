<?php

function applyRequestLimits(): void
{
    $maxRequestBytes = max(1024 * 1024, min(64 * 1024 * 1024, (int)($_ENV['MAX_REQUEST_BYTES'] ?? 64 * 1024 * 1024)));
    $declaredLength = (int)($_SERVER['CONTENT_LENGTH'] ?? 0);
    if ($declaredLength > $maxRequestBytes) {
        http_response_code(413);
        header('Content-Type: application/json; charset=UTF-8');
        echo json_encode(['success'=>false,'message'=>'The request body is too large.']);
        exit;
    }

    $executionSeconds = max(5, min(120, (int)($_ENV['MAX_EXECUTION_SECONDS'] ?? 60)));
    if (function_exists('set_time_limit')) @set_time_limit($executionSeconds);
}

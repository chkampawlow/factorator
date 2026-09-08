<?php

declare(strict_types=1);

function reportFailureResponse(
    Throwable $error,
    string $publicMessage,
    string $errorCode
): void {
    if ($error instanceof InvalidArgumentException) {
        jsonResponse([
            'success' => false,
            'message' => $error->getMessage(),
            'error_code' => 'REPORT_VALIDATION_FAILED',
        ], 422);
    }

    if ($error instanceof OutOfBoundsException) {
        jsonResponse([
            'success' => false,
            'message' => $error->getMessage(),
            'error_code' => 'REPORT_RESOURCE_NOT_FOUND',
        ], 404);
    }

    if ($error instanceof DomainException) {
        jsonResponse([
            'success' => false,
            'message' => $error->getMessage(),
            'error_code' => 'REPORT_WORKFLOW_CONFLICT',
        ], 409);
    }

    structuredLog('ERROR', 'REPORT.ENDPOINT_FAILED', [
        'error_code' => $errorCode,
        'exception' => get_class($error),
        'message' => $error->getMessage(),
        'file' => basename($error->getFile()),
        'line' => $error->getLine(),
    ]);

    jsonResponse([
        'success' => false,
        'message' => $publicMessage,
        'error_code' => $errorCode,
    ], 500);
}

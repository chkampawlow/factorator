<?php
header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/upload.php';
require_once __DIR__ . '/../config/process.php';




function formatBytes(int $bytes): string
{
    $units = ['B', 'KB', 'MB', 'GB'];
    $value = (float) $bytes;
    $unitIndex = 0;
    while ($value >= 1024 && $unitIndex < count($units) - 1) {
        $value /= 1024;
        $unitIndex++;
    }

    return number_format($value, $unitIndex === 0 ? 0 : 2) . ' ' . $units[$unitIndex];
}

function normalizeUploads(array $fileBag): array
{
    if (!isset($fileBag['name']) || !is_array($fileBag['name'])) {
        return [];
    }

    $entries = [];
    foreach ($fileBag['name'] as $index => $name) {
        $entries[] = [
            'name' => (string) $name,
            'tmp_name' => (string) ($fileBag['tmp_name'][$index] ?? ''),
            'error' => (int) ($fileBag['error'][$index] ?? UPLOAD_ERR_NO_FILE),
            'size' => (int) ($fileBag['size'][$index] ?? 0),
        ];
    }

    return $entries;
}

function runExtractor(string $pythonBin, string $scriptPath, string $configPath, string $targetPath): array
{
    $timeout = max(5, min(180, (int)($_ENV['EXTRACTOR_TIMEOUT_SECONDS'] ?? 60)));
    $maxOutput = max(65536, min(5 * 1024 * 1024, (int)($_ENV['EXTRACTOR_MAX_OUTPUT_BYTES'] ?? 2 * 1024 * 1024)));
    $result = runBoundedProcess([$pythonBin, $scriptPath, $targetPath, '--config', $configPath, '--pretty'], $timeout, $maxOutput);
    if ($result['timedOut']) $result['output'] = 'The extractor exceeded its execution-time limit.';
    if ($result['outputExceeded']) $result['output'] = 'The extractor exceeded its output-size limit.';
    $result['output'] = trim((string)$result['output']);
    return $result;
}

function resolveExtractorBaseDir(): string
{
    $configured = trim((string)($_ENV['EL_FATOURA_EXTRACTOR_DIR'] ?? getenv('EL_FATOURA_EXTRACTOR_DIR') ?: ''));
    $candidates = array_filter([
        $configured !== '' ? $configured : null,
        realpath(__DIR__ . '/../../extractor') ?: null,
    ]);

    foreach ($candidates as $candidate) {
        if (!is_string($candidate) || $candidate === '') {
            continue;
        }

        $normalized = rtrim($candidate, DIRECTORY_SEPARATOR);
        if (is_dir($normalized)) {
            return $normalized;
        }
    }

    throw new RuntimeException('Extractor workspace was not found.');
}

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        jsonResponse([
            'success' => false,
            'message' => 'Method not allowed. Use POST.',
        ], 405);
    }

    $authUser = requireAuth();
    $actorId = authActorId($authUser);
    $tenantId = authTenantId($authUser);
    appSetLogContext($tenantId, $actorId);
    $conn = db();
    requirePermission($conn, $actorId, 'extractor.use');

    $baseDir = resolveExtractorBaseDir();

    $pythonBin = $baseDir . '/.venv/bin/python';
    $scriptPath = $baseDir . '/extract_invoice.py';
    $configPath = $baseDir . '/default.json';
    $sampleDir = realpath($baseDir . '/1000+ PDF_Invoice_Folder');
    $uploadDir = ensurePrivateDirectory('extractor/' . $tenantId . '/' . $actorId);
    $allowedUploadTypes = [
        'application/pdf' => ['pdf'], 'image/png' => ['png'],
        'image/jpeg' => ['jpg', 'jpeg'], 'image/tiff' => ['tif', 'tiff'],
        'image/bmp' => ['bmp'], 'image/x-ms-bmp' => ['bmp'], 'image/webp' => ['webp'],
    ];

    if (!is_file($pythonBin) || !is_file($scriptPath) || !is_file($configPath)) {
        throw new RuntimeException('Extractor runtime is incomplete. Check the Python venv and config files.');
    }

    $source = ($_POST['source'] ?? 'upload') === 'sample' ? 'sample' : 'upload';
    $targets = [];

    if ($source === 'sample') {
        if ($sampleDir === false || !is_dir($sampleDir)) {
            throw new RuntimeException('Sample directory was not found.');
        }

        $selectedSamples = array_values(array_filter(
            array_map(static fn($value): string => trim((string) $value), (array) ($_POST['sample_files'] ?? [])),
            static fn(string $value): bool => $value !== ''
        ));

        if ($selectedSamples === []) {
            jsonResponse([
                'success' => false,
                'message' => 'Choose at least one sample invoice.',
            ], 422);
        }

        foreach ($selectedSamples as $selectedSample) {
            $path = realpath($sampleDir . DIRECTORY_SEPARATOR . $selectedSample);
            if ($path === false || basename($selectedSample) !== $selectedSample || dirname($path) !== $sampleDir) {
                jsonResponse([
                    'success' => false,
                    'message' => 'One of the selected sample files is invalid.',
                ], 422);
            }

            $targets[] = [
                'displayName' => basename($path),
                'path' => $path,
                'sizeBytes' => (int) filesize($path),
                'cleanup' => false,
            ];
        }
    } else {
        $uploads = normalizeUploads((array) ($_FILES['invoice_files'] ?? []));
        if ($uploads === []) {
            jsonResponse([
                'success' => false,
                'message' => 'Upload at least one file.',
            ], 422);
        }

        if (count($uploads) > 10) throw new InvalidArgumentException('A maximum of 10 files is allowed per extraction.');
        $batchBytes = 0;
        foreach ($uploads as $upload) {
            $validated = validatedUpload($upload, $allowedUploadTypes, 15 * 1024 * 1024);
            $batchBytes += $validated['size'];
            if ($batchBytes > 50 * 1024 * 1024) throw new InvalidArgumentException('The upload batch cannot exceed 50 MB.');
            $targetPath = $uploadDir . DIRECTORY_SEPARATOR . $validated['stored_name'];
            if (!move_uploaded_file($validated['tmp_name'], $targetPath)) {
                throw new RuntimeException('Could not store one of the uploaded files.');
            }
            chmod($targetPath, 0660);

            $targets[] = [
                'displayName' => $validated['display_name'],
                'path' => $targetPath,
                'sizeBytes' => $validated['size'],
                'cleanup' => true,
            ];
        }
    }

    $overallStarted = microtime(true);
    $results = [];
    $processed = 0;
    $failed = 0;
    $totalPages = 0;
    $totalInputBytes = 0;
    $totalOutputBytes = 0;

    foreach ($targets as $target) {
        $totalInputBytes += (int) $target['sizeBytes'];
        $run = runExtractor($pythonBin, $scriptPath, $configPath, $target['path']);

        $item = [
            'fileName' => $target['displayName'],
            'sizeBytes' => (int) $target['sizeBytes'],
            'sizeLabel' => formatBytes((int) $target['sizeBytes']),
            'elapsedMs' => round((float) $run['elapsedMs'], 1),
            'success' => false,
            'result' => null,
            'error' => null,
        ];

        if ((int) $run['exitCode'] !== 0) {
            $failed++;
            $item['error'] = 'The extractor could not process this file.';
            structuredLog('WARNING', 'EXTRACTOR.FILE_FAILED', [
                'file_name' => $target['displayName'],
                'exit_code' => (int)$run['exitCode'],
                'timed_out' => (bool)$run['timedOut'],
                'output_exceeded' => (bool)$run['outputExceeded'],
            ]);
        } else {
            $decoded = json_decode((string) $run['output'], true);
            if (!is_array($decoded)) {
                $failed++;
                $item['error'] = 'The extractor returned invalid JSON.';
            } else {
                $processed++;
                $item['success'] = true;
                $item['result'] = $decoded;
                $totalPages += (int) ($decoded['page_count'] ?? 0);
                $totalOutputBytes += strlen((string) $run['output']);
            }
        }

        $results[] = $item;

        if (($target['cleanup'] ?? false) === true && is_file($target['path'])) {
            unlink($target['path']);
        }
    }

    $requested = count($targets);
    $wallClockMs = (microtime(true) - $overallStarted) * 1000;

    jsonResponse([
        'success' => true,
        'summary' => [
            'requested' => $requested,
            'processed' => $processed,
            'failed' => $failed,
            'successRate' => $requested > 0 ? round(($processed / $requested) * 100, 1) : 0.0,
            'totalInputBytes' => $totalInputBytes,
            'totalInputLabel' => formatBytes($totalInputBytes),
            'totalOutputBytes' => $totalOutputBytes,
            'totalOutputLabel' => formatBytes($totalOutputBytes),
            'totalPages' => $totalPages,
            'wallClockMs' => round($wallClockMs, 1),
            'avgMsPerFile' => $requested > 0 ? round($wallClockMs / $requested, 1) : 0.0,
            'peakPhpMemoryBytes' => memory_get_peak_usage(true),
            'peakPhpMemoryLabel' => formatBytes(memory_get_peak_usage(true)),
        ],
        'items' => $results,
    ]);
} catch (Throwable $e) {
    foreach ($targets ?? [] as $target) {
        if (($target['cleanup'] ?? false) === true && is_file((string)($target['path'] ?? ''))) unlink($target['path']);
    }
    $isInputError = $e instanceof InvalidArgumentException;
    structuredLog($isInputError ? 'WARNING' : 'ERROR', 'EXTRACTOR.REQUEST_FAILED', [
        'exception' => get_class($e),
        'message' => $e->getMessage(),
    ]);
    jsonResponse([
        'success' => false,
        'message' => $isInputError
            ? $e->getMessage()
            : 'The extractor is temporarily unavailable.',
        'error_code' => $isInputError ? 'EXTRACTOR_INVALID_INPUT' : 'EXTRACTOR_UNAVAILABLE',
    ], $isInputError ? 422 : 503);
}
?>

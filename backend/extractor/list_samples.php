<?php
header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../config/db.php';




try {
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        jsonResponse([
            'success' => false,
            'message' => 'Method not allowed. Use GET.',
        ], 405);
    }

    $authUser = requireAuth();
    $userId = authActorId($authUser);
    appSetLogContext(authTenantId($authUser), $userId);
    $conn = db();
    requirePermission($conn, $userId, 'extractor.use');

    $configuredBaseDir = trim((string)($_ENV['EL_FATOURA_EXTRACTOR_DIR'] ?? getenv('EL_FATOURA_EXTRACTOR_DIR') ?: ''));
    $baseDir = $configuredBaseDir !== '' ? realpath($configuredBaseDir) : realpath(__DIR__ . '/../../extractor');
    $sampleDir = $baseDir !== false ? realpath($baseDir . '/1000+ PDF_Invoice_Folder') : false;
    if ($sampleDir === false || !is_dir($sampleDir)) {
        jsonResponse([
            'success' => true,
            'available' => false,
            'items' => [],
        ]);
    }

    $entries = scandir($sampleDir);
    if ($entries === false) {
        throw new RuntimeException('Could not read sample directory.');
    }

    $files = [];
    foreach ($entries as $entry) {
        if ($entry === '.' || $entry === '..') {
            continue;
        }
        $path = $sampleDir . DIRECTORY_SEPARATOR . $entry;
        if (!is_file($path)) {
            continue;
        }
        if (!preg_match('/\.(pdf|png|jpe?g|tiff?|bmp|webp)$/i', $entry)) {
            continue;
        }

        $files[] = [
            'name' => $entry,
            'sizeBytes' => (int) filesize($path),
        ];
    }

    usort($files, static function (array $left, array $right): int {
        return strnatcasecmp($left['name'], $right['name']);
    });

    jsonResponse([
        'success' => true,
        'available' => true,
        'items' => array_slice($files, 0, 120),
    ]);
} catch (Throwable $e) {
    structuredLog('ERROR', 'EXTRACTOR.SAMPLES_FAILED', [
        'exception' => get_class($e),
        'message' => $e->getMessage(),
    ]);
    jsonResponse([
        'success' => false,
        'message' => 'Sample invoices are temporarily unavailable.',
        'error_code' => 'EXTRACTOR_SAMPLES_UNAVAILABLE',
    ], 503);
}
?>

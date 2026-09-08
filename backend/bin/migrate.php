<?php
declare(strict_types=1);
if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
$_SERVER['REQUEST_METHOD'] = $_SERVER['REQUEST_METHOD'] ?? 'CLI';
require_once __DIR__ . '/../config/db.php';
$conn = db();
$conn->query("CREATE TABLE IF NOT EXISTS schema_migrations(version VARCHAR(190) PRIMARY KEY,checksum CHAR(64) NOT NULL,applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
$files = glob(__DIR__ . '/../sql/*.sql') ?: [];
sort($files, SORT_STRING);
$baseline = in_array('--baseline', $argv ?? [], true);
foreach ($files as $file) {
    $version = basename($file); $sql = file_get_contents($file);
    if ($sql === false) throw new RuntimeException("Cannot read $version");
    $checksum = hash('sha256', $sql);
    $stmt = $conn->prepare('SELECT checksum FROM schema_migrations WHERE version=?');
    $stmt->bind_param('s', $version); $stmt->execute(); $row = $stmt->get_result()->fetch_assoc(); $stmt->close();
    if ($row) {
        if (!hash_equals((string)$row['checksum'], $checksum)) throw new RuntimeException("Applied migration changed: $version");
        echo "skip  $version\n"; continue;
    }
    if ($baseline) {
        $stmt = $conn->prepare('INSERT INTO schema_migrations(version,checksum) VALUES(?,?)');
        $stmt->bind_param('ss', $version, $checksum); $stmt->execute(); $stmt->close();
        echo "base  $version\n"; continue;
    }
    $conn->begin_transaction();
    try {
        $conn->multi_query($sql);
        do { if ($result = $conn->store_result()) $result->free(); } while ($conn->more_results() && $conn->next_result());
        if ($conn->errno) throw new RuntimeException($conn->error);
        $stmt = $conn->prepare('INSERT INTO schema_migrations(version,checksum) VALUES(?,?)');
        $stmt->bind_param('ss', $version, $checksum); $stmt->execute(); $stmt->close();
        $conn->commit(); echo "apply $version\n";
    } catch (Throwable $e) {
        $conn->rollback(); throw new RuntimeException("Migration $version failed: " . $e->getMessage(), 0, $e);
    }
}

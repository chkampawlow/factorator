<?php

declare(strict_types=1);

/*
 * El Fatoura Super Admin portal.
 * Deploy beside the backend directory or directly inside it.
 * Secrets belong in backend/.env; never put them in this file or in the URL.
 */

ini_set('display_errors', '0');
ini_set('display_startup_errors', '0');
ini_set('log_errors', '1');
error_reporting(E_ALL);

const SQL_MAX_BYTES = 262144;
const SQL_RESULT_ROW_LIMIT = 500;
const SESSION_IDLE_SECONDS = 1200;

function resolveBackendDirectory(): string
{
    $candidates = [
        __DIR__ . '/backend',
        __DIR__,
        dirname(__DIR__) . '/backend',
    ];
    foreach (array_unique($candidates) as $candidate) {
        if (is_file($candidate . '/config/env.php')) return $candidate;
    }
    return '';
}

define('BACKEND_DIRECTORY', resolveBackendDirectory());
define('ENV_FILE', BACKEND_DIRECTORY !== '' ? BACKEND_DIRECTORY . '/.env' : '');

header('Content-Type: text/html; charset=utf-8');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');
header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');
header('Referrer-Policy: no-referrer');
header('Permissions-Policy: camera=(), microphone=(), geolocation=()');

$cspNonce = base64_encode(random_bytes(18));
header("Content-Security-Policy: default-src 'none'; style-src 'self' 'unsafe-inline'; script-src 'nonce-{$cspNonce}'; img-src 'self' data:; form-action 'self'; base-uri 'none'; frame-ancestors 'none'");

function h(mixed $value): string
{
    return htmlspecialchars((string)$value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

function envFlag(string $key, bool $default = false): bool
{
    $value = strtolower(trim((string)($_ENV[$key] ?? '')));
    if ($value === '') return $default;
    return in_array($value, ['1', 'true', 'yes', 'on'], true);
}

function envFirst(array $keys, string $default = ''): string
{
    foreach ($keys as $key) {
        $value = trim((string)($_ENV[$key] ?? ''));
        if ($value !== '') return $value;
    }
    return $default;
}

function requestIsHttps(): bool
{
    if (!empty($_SERVER['HTTPS']) && strtolower((string)$_SERVER['HTTPS']) !== 'off') return true;
    return strtolower((string)($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '')) === 'https';
}

function csrfValid(): bool
{
    $provided = (string)($_POST['csrf_token'] ?? '');
    $expected = (string)($_SESSION['super_admin_csrf'] ?? '');
    return $provided !== '' && $expected !== '' && hash_equals($expected, $provided);
}

function sqlLeadingKeyword(string $sql): string
{
    $clean = preg_replace('/\A(?:\s+|--[^\r\n]*(?:\r?\n|\z)|#[^\r\n]*(?:\r?\n|\z)|\/\*.*?\*\/)+/s', '', $sql) ?? $sql;
    if (!preg_match('/\A([A-Za-z]+)/', ltrim($clean), $match)) return 'UNKNOWN';
    return strtoupper($match[1]);
}

function sqlIsReadOnly(string $sql): bool
{
    $statement = rtrim(trim($sql), "; \t\n\r\0\x0B");
    if ($statement === '' || str_contains($statement, ';')) return false;
    return in_array(sqlLeadingKeyword($statement), ['SELECT', 'SHOW', 'DESCRIBE', 'DESC', 'EXPLAIN'], true);
}

function sqlAudit(string $sql, string $database, string $databaseUser, bool $write, bool $success, float $durationMs, ?string $error): void
{
    $directory = BACKEND_DIRECTORY . '/storage/logs';
    if (!is_dir($directory) && !@mkdir($directory, 0700, true) && !is_dir($directory)) return;
    $path = $directory . '/super-admin-sql.jsonl';
    $record = [
        'timestamp' => gmdate('c'),
        'event' => 'SUPER_ADMIN.SQL_EXECUTED',
        'database' => $database,
        'database_user' => $databaseUser,
        'client_ip_sha256' => hash('sha256', (string)($_SERVER['REMOTE_ADDR'] ?? 'unknown')),
        'query_sha256' => hash('sha256', $sql),
        'leading_keyword' => sqlLeadingKeyword($sql),
        'write' => $write,
        'success' => $success,
        'duration_ms' => round($durationMs, 2),
        'error' => $error !== null ? mb_substr($error, 0, 300) : null,
    ];
    @file_put_contents($path, json_encode($record, JSON_UNESCAPED_SLASHES) . PHP_EOL, FILE_APPEND | LOCK_EX);
    @chmod($path, 0600);
}

function migrationAudit(string $version, string $checksum, string $database, string $databaseUser, bool $success, float $durationMs, ?string $error): void
{
    $directory = BACKEND_DIRECTORY . '/storage/logs';
    if (!is_dir($directory) && !@mkdir($directory, 0700, true) && !is_dir($directory)) return;
    $path = $directory . '/super-admin-migrations.jsonl';
    $record = [
        'timestamp' => gmdate('c'),
        'event' => 'SUPER_ADMIN.MIGRATION_EXECUTED',
        'database' => $database,
        'database_user' => $databaseUser,
        'client_ip_sha256' => hash('sha256', (string)($_SERVER['REMOTE_ADDR'] ?? 'unknown')),
        'migration' => $version,
        'checksum' => $checksum,
        'success' => $success,
        'duration_ms' => round($durationMs, 2),
        'error' => $error !== null ? mb_substr($error, 0, 300) : null,
    ];
    @file_put_contents($path, json_encode($record, JSON_UNESCAPED_SLASHES) . PHP_EOL, FILE_APPEND | LOCK_EX);
    @chmod($path, 0600);
}

function superAdminOperationAudit(string $event, int $targetUserId, bool $success, ?string $error = null): void
{
    $directory = BACKEND_DIRECTORY . '/storage/logs';
    if (!is_dir($directory) && !@mkdir($directory, 0700, true) && !is_dir($directory)) return;
    $path = $directory . '/super-admin-operations.jsonl';
    $record = [
        'timestamp' => gmdate('c'),
        'event' => $event,
        'target_user_id' => $targetUserId > 0 ? $targetUserId : null,
        'client_ip_sha256' => hash('sha256', (string)($_SERVER['REMOTE_ADDR'] ?? 'unknown')),
        'success' => $success,
        'error' => $error !== null ? mb_substr($error, 0, 300) : null,
    ];
    @file_put_contents($path, json_encode($record, JSON_UNESCAPED_SLASHES) . PHP_EOL, FILE_APPEND | LOCK_EX);
    @chmod($path, 0600);
}

function executeSql(mysqli $db, string $sql): array
{
    $results = [];
    $db->multi_query($sql);
    do {
        $result = $db->store_result();
        if ($result instanceof mysqli_result) {
            $columns = array_map(static fn(object $field): string => (string)$field->name, $result->fetch_fields());
            $rows = [];
            while (count($rows) < SQL_RESULT_ROW_LIMIT && ($row = $result->fetch_assoc())) $rows[] = $row;
            $truncated = $result->fetch_assoc() !== null;
            $result->free();
            $results[] = ['columns' => $columns, 'rows' => $rows, 'truncated' => $truncated, 'affected' => null];
        } else {
            $results[] = ['columns' => [], 'rows' => [], 'truncated' => false, 'affected' => $db->affected_rows];
        }
    } while ($db->more_results() && $db->next_result());
    if ($db->errno) throw new RuntimeException($db->error);
    return $results;
}

function ensureSchemaMigrationsTable(mysqli $db): void
{
    $db->query("CREATE TABLE IF NOT EXISTS schema_migrations (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        version VARCHAR(255) NOT NULL,
        checksum CHAR(64) NULL,
        applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        execution_ms DECIMAL(12,2) NULL,
        PRIMARY KEY (id),
        UNIQUE KEY uq_schema_migrations_version (version)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    $columns = [];
    $result = $db->query("SELECT column_name FROM information_schema.columns WHERE table_schema=DATABASE() AND table_name='schema_migrations'");
    foreach ($result as $row) $columns[(string)$row['column_name']] = true;

    if (!isset($columns['checksum'])) {
        $db->query("ALTER TABLE schema_migrations ADD COLUMN checksum CHAR(64) NULL AFTER version");
    }
    if (!isset($columns['execution_ms'])) {
        $db->query("ALTER TABLE schema_migrations ADD COLUMN execution_ms DECIMAL(12,2) NULL AFTER applied_at");
    }
}

function runMigration(mysqli $db, string $path, string $version): array
{
    if (!is_file($path) || !is_readable($path)) throw new RuntimeException('Migration file is unavailable.');
    $sql = file_get_contents($path);
    if ($sql === false || trim($sql) === '') throw new RuntimeException('Migration file is empty.');
    if (strlen($sql) > SQL_MAX_BYTES) throw new RuntimeException('Migration exceeds the configured 256 KB SQL size limit.');

    $checksum = hash('sha256', $sql);

    $check = $db->prepare("SELECT checksum FROM schema_migrations WHERE version=? LIMIT 1");
    $check->bind_param('s', $version);
    $check->execute();
    $existing = $check->get_result()->fetch_assoc();
    $check->close();

    if ($existing) {
        $stored = trim((string)($existing['checksum'] ?? ''));
        if ($stored !== '' && !hash_equals($stored, $checksum)) {
            throw new RuntimeException('SECURITY WARNING: this migration was already applied but its file checksum has changed.');
        }
        throw new RuntimeException('This migration has already been applied.');
    }

    $started = microtime(true);
    executeSql($db, $sql);
    $executionMs = round((microtime(true) - $started) * 1000, 2);

    $insert = $db->prepare("INSERT INTO schema_migrations(version,checksum,applied_at,execution_ms) VALUES(?,?,NOW(),?)");
    $insert->bind_param('ssd', $version, $checksum, $executionMs);
    $insert->execute();
    $insert->close();

    return ['version' => $version, 'checksum' => $checksum, 'execution_ms' => $executionMs];
}

function formatBytes(float $bytes): string
{
    if ($bytes <= 0) return '0 B';
    $units = ['B', 'KB', 'MB', 'GB', 'TB'];
    $power = min((int)floor(log($bytes, 1024)), count($units) - 1);
    return round($bytes / (1024 ** $power), 2) . ' ' . $units[$power];
}

function shortChecksum(string $checksum): string
{
    return $checksum === '' ? '-' : substr($checksum, 0, 12) . '…';
}

function dashboardTableExists(mysqli $db, string $table): bool
{
    try {
        $statement = $db->prepare("SELECT COUNT(*) total FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name=?");
        $statement->bind_param('s', $table);
        $statement->execute();
        $exists = (int)($statement->get_result()->fetch_assoc()['total'] ?? 0) > 0;
        $statement->close();
        return $exists;
    } catch (Throwable) {
        return false;
    }
}

function dashboardRow(mysqli $db, string $sql): array
{
    try {
        return $db->query($sql)->fetch_assoc() ?: [];
    } catch (Throwable) {
        return [];
    }
}

function dashboardRows(mysqli $db, string $sql): array
{
    try {
        return $db->query($sql)->fetch_all(MYSQLI_ASSOC);
    } catch (Throwable) {
        return [];
    }
}

function dashboardColumnExists(mysqli $db, string $table, string $column): bool
{
    try {
        $statement = $db->prepare("SELECT COUNT(*) total FROM information_schema.columns WHERE table_schema=DATABASE() AND table_name=? AND column_name=?");
        $statement->bind_param('ss', $table, $column);
        $statement->execute();
        $exists = (int)($statement->get_result()->fetch_assoc()['total'] ?? 0) > 0;
        $statement->close();
        return $exists;
    } catch (Throwable) {
        return false;
    }
}

function backupDirectory(): string
{
    return BACKEND_DIRECTORY . '/storage/backups';
}

function ensureBackupDirectory(): bool
{
    $directory = backupDirectory();
    if (!is_dir($directory) && !@mkdir($directory, 0700, true) && !is_dir($directory)) return false;
    @chmod($directory, 0700);
    return is_writable($directory);
}

function safeBackupFile(string $name): string
{
    $base = basename($name);
    if ($base === '' || !preg_match('/\Ael-fatoura-[A-Za-z0-9._-]+\.(?:sql|sql\.gz)\z/', $base)) return '';
    $path = backupDirectory() . '/' . $base;
    return is_file($path) ? $path : '';
}

function backupFiles(): array
{
    if (!is_dir(backupDirectory())) return [];
    $files = [];
    foreach (glob(backupDirectory() . '/el-fatoura-*.sql*') ?: [] as $path) {
        if (str_ends_with($path, '.sha256')) continue;
        if (!is_file($path)) continue;
        $checksum = is_file($path . '.sha256') ? trim((string)@file_get_contents($path . '.sha256')) : '';
        $files[] = [
            'name' => basename($path),
            'size' => (float)(filesize($path) ?: 0),
            'modified_at' => date('Y-m-d H:i:s', (int)(filemtime($path) ?: time())),
            'checksum' => $checksum,
        ];
    }
    usort($files, static fn(array $a, array $b): int => strcmp($b['modified_at'], $a['modified_at']));
    return $files;
}

function backupSqlIdentifier(string $identifier): string
{
    return '`' . str_replace('`', '``', $identifier) . '`';
}

function backupSqlValue(mysqli $db, mixed $value): string
{
    if ($value === null) return 'NULL';
    return "'" . $db->real_escape_string((string)$value) . "'";
}

function backupWrite($handle, string $text): void
{
    $length = strlen($text);
    $written = 0;

    while ($written < $length) {
        $result = fwrite($handle, substr($text, $written));
        if ($result === false || $result === 0) {
            throw new RuntimeException('Could not write the database backup file.');
        }
        $written += $result;
    }
}

function createDatabaseBackup(string $host, int $port, string $database, string $user, string $password): array
{
    if (!ensureBackupDirectory()) {
        throw new RuntimeException('Backup directory is unavailable or not writable.');
    }

    $timestamp = gmdate('Ymd-His');
    $safeDatabase = preg_replace('/[^A-Za-z0-9_-]+/', '-', $database) ?: 'database';
    $baseName = 'el-fatoura-' . $safeDatabase . '-' . $timestamp . '.sql';
    $sqlPath = backupDirectory() . '/' . $baseName;

    $backupDb = null;
    $handle = null;
    $tableCount = 0;
    $rowCount = 0;
    $viewCount = 0;

    try {
        /*
         * Dedicated mysqli connection. No shell command, mysqldump or
         * mariadb-dump is required.
         */
        $backupDb = new mysqli($host, $user, $password, $database, $port);
        $backupDb->set_charset('utf8mb4');

        $handle = @fopen($sqlPath, 'wb');
        if ($handle === false) {
            throw new RuntimeException('Could not create the database backup file.');
        }
        @chmod($sqlPath, 0600);

        backupWrite($handle, "-- El Fatoura database backup\n");
        backupWrite($handle, "-- Pure PHP backup engine\n");
        backupWrite($handle, "-- Database: " . str_replace(["\r", "\n"], '', $database) . "\n");
        backupWrite($handle, "-- Generated UTC: " . gmdate('c') . "\n");
        backupWrite($handle, "-- Server: " . $backupDb->server_info . "\n\n");
        backupWrite($handle, "SET NAMES utf8mb4;\n");
        backupWrite($handle, "SET FOREIGN_KEY_CHECKS=0;\n");
        backupWrite($handle, "SET UNIQUE_CHECKS=0;\n");
        backupWrite($handle, "SET SQL_MODE='NO_AUTO_VALUE_ON_ZERO';\n\n");

        $backupDb->query("SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ");
        $backupDb->query("START TRANSACTION WITH CONSISTENT SNAPSHOT");

        $tables = [];
        $tableResult = $backupDb->query("
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = DATABASE()
              AND table_type = 'BASE TABLE'
            ORDER BY table_name
        ");
        while ($row = $tableResult->fetch_assoc()) {
            $tables[] = (string)$row['table_name'];
        }
        $tableResult->free();

        $views = [];
        $viewResult = $backupDb->query("
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = DATABASE()
              AND table_type = 'VIEW'
            ORDER BY table_name
        ");
        while ($row = $viewResult->fetch_assoc()) {
            $views[] = (string)$row['table_name'];
        }
        $viewResult->free();

        backupWrite($handle, "-- --------------------------------------------------------\n");
        backupWrite($handle, "-- TABLE STRUCTURES\n");
        backupWrite($handle, "-- --------------------------------------------------------\n\n");

        foreach ($tables as $table) {
            $quotedTable = backupSqlIdentifier($table);
            $createResult = $backupDb->query("SHOW CREATE TABLE {$quotedTable}");
            $createRow = $createResult->fetch_assoc() ?: [];
            $createResult->free();

            $createSql = (string)($createRow['Create Table'] ?? '');
            if ($createSql === '') {
                throw new RuntimeException('Could not read the structure for table ' . $table . '.');
            }

            backupWrite($handle, "-- Table: {$quotedTable}\n");
            backupWrite($handle, "DROP TABLE IF EXISTS {$quotedTable};\n");
            backupWrite($handle, $createSql . ";\n\n");
            $tableCount++;
        }

        backupWrite($handle, "-- --------------------------------------------------------\n");
        backupWrite($handle, "-- TABLE DATA\n");
        backupWrite($handle, "-- --------------------------------------------------------\n\n");

        foreach ($tables as $table) {
            $quotedTable = backupSqlIdentifier($table);
            $result = $backupDb->query("SELECT * FROM {$quotedTable}", MYSQLI_USE_RESULT);

            if (!($result instanceof mysqli_result)) {
                throw new RuntimeException('Could not read data from table ' . $table . '.');
            }

            $fields = $result->fetch_fields();
            $columns = array_map(
                static fn(object $field): string => backupSqlIdentifier((string)$field->name),
                $fields
            );
            $columnSql = implode(',', $columns);

            $batch = [];
            $batchBytes = 0;
            $batchLimit = 200;
            $batchByteLimit = 512 * 1024;
            $tableRows = 0;

            while ($row = $result->fetch_assoc()) {
                $values = [];
                foreach ($fields as $field) {
                    $name = (string)$field->name;
                    $values[] = backupSqlValue($backupDb, $row[$name] ?? null);
                }

                $tuple = '(' . implode(',', $values) . ')';
                $batch[] = $tuple;
                $batchBytes += strlen($tuple);
                $tableRows++;
                $rowCount++;

                if (count($batch) >= $batchLimit || $batchBytes >= $batchByteLimit) {
                    backupWrite(
                        $handle,
                        "INSERT INTO {$quotedTable} ({$columnSql}) VALUES\n"
                        . implode(",\n", $batch)
                        . ";\n"
                    );
                    $batch = [];
                    $batchBytes = 0;
                }
            }

            if ($batch) {
                backupWrite(
                    $handle,
                    "INSERT INTO {$quotedTable} ({$columnSql}) VALUES\n"
                    . implode(",\n", $batch)
                    . ";\n"
                );
            }

            $result->free();
            backupWrite($handle, "-- {$tableRows} row(s) exported from {$quotedTable}\n\n");
        }

        if ($views) {
            backupWrite($handle, "-- --------------------------------------------------------\n");
            backupWrite($handle, "-- VIEWS\n");
            backupWrite($handle, "-- --------------------------------------------------------\n\n");

            foreach ($views as $view) {
                $quotedView = backupSqlIdentifier($view);
                $createResult = $backupDb->query("SHOW CREATE VIEW {$quotedView}");
                $createRow = $createResult->fetch_assoc() ?: [];
                $createResult->free();

                $createSql = (string)($createRow['Create View'] ?? '');
                if ($createSql === '') continue;

                $createSql = preg_replace(
                    '/\s+DEFINER\s*=\s*`[^`]+`@`[^`]+`/i',
                    '',
                    $createSql
                ) ?? $createSql;

                backupWrite($handle, "DROP VIEW IF EXISTS {$quotedView};\n");
                backupWrite($handle, $createSql . ";\n\n");
                $viewCount++;
            }
        }

        backupWrite($handle, "COMMIT;\n");
        backupWrite($handle, "SET UNIQUE_CHECKS=1;\n");
        backupWrite($handle, "SET FOREIGN_KEY_CHECKS=1;\n");

        fflush($handle);
        fclose($handle);
        $handle = null;

        $backupDb->commit();
        $backupDb->close();
        $backupDb = null;

        if (!is_file($sqlPath) || (int)filesize($sqlPath) <= 0) {
            throw new RuntimeException('The PHP backup engine produced an empty file.');
        }

        $finalPath = $sqlPath;

        /*
         * Compress with PHP zlib if available. No system gzip binary required.
         */
        if (function_exists('gzopen')) {
            $gzPath = $sqlPath . '.gz';
            $source = @fopen($sqlPath, 'rb');
            $target = @gzopen($gzPath, 'wb6');

            if ($source !== false && $target !== false) {
                $gzipOk = true;

                while (!feof($source)) {
                    $chunk = fread($source, 1024 * 1024);
                    if ($chunk === false) {
                        $gzipOk = false;
                        break;
                    }
                    if ($chunk !== '' && gzwrite($target, $chunk) === false) {
                        $gzipOk = false;
                        break;
                    }
                }

                fclose($source);
                gzclose($target);

                if ($gzipOk && is_file($gzPath) && (int)filesize($gzPath) > 0) {
                    @unlink($sqlPath);
                    $finalPath = $gzPath;
                    @chmod($finalPath, 0600);
                } else {
                    @unlink($gzPath);
                }
            } else {
                if (is_resource($source)) fclose($source);
                if (is_resource($target)) gzclose($target);
                @unlink($gzPath);
            }
        }

        $checksum = hash_file('sha256', $finalPath);
        if ($checksum === false) {
            @unlink($finalPath);
            throw new RuntimeException('Backup was created but its checksum could not be calculated.');
        }

        if (@file_put_contents($finalPath . '.sha256', $checksum . PHP_EOL, LOCK_EX) === false) {
            @unlink($finalPath);
            throw new RuntimeException('Backup was created but its checksum file could not be written.');
        }

        @chmod($finalPath, 0600);
        @chmod($finalPath . '.sha256', 0600);

        return [
            'name' => basename($finalPath),
            'path' => $finalPath,
            'size' => (float)(filesize($finalPath) ?: 0),
            'checksum' => $checksum,
            'engine' => 'pure-php',
            'tables' => $tableCount,
            'views' => $viewCount,
            'rows' => $rowCount,
        ];
    } catch (Throwable $error) {
        if (is_resource($handle)) @fclose($handle);

        if ($backupDb instanceof mysqli) {
            try { $backupDb->rollback(); } catch (Throwable) {}
            try { $backupDb->close(); } catch (Throwable) {}
        }

        @unlink($sqlPath);
        @unlink($sqlPath . '.gz');
        @unlink($sqlPath . '.sha256');
        @unlink($sqlPath . '.gz.sha256');

        throw $error;
    }
}

function integrityCheck(
    mysqli $db,
    string $key,
    string $label,
    array $requirements,
    string $sql,
    string $severity = 'high'
): array {
    foreach ($requirements as $table => $columns) {
        if (!dashboardTableExists($db, $table)) {
            return ['key'=>$key,'label'=>$label,'status'=>'SKIPPED','count'=>0,'severity'=>$severity,'detail'=>"Missing table: {$table}"];
        }
        foreach ($columns as $column) {
            if (!dashboardColumnExists($db, $table, $column)) {
                return ['key'=>$key,'label'=>$label,'status'=>'SKIPPED','count'=>0,'severity'=>$severity,'detail'=>"Missing column: {$table}.{$column}"];
            }
        }
    }

    try {
        $row = $db->query($sql)->fetch_assoc() ?: [];
        $count = (int)($row['issue_count'] ?? 0);
        return [
            'key'=>$key,
            'label'=>$label,
            'status'=>$count > 0 ? 'ISSUES' : 'OK',
            'count'=>$count,
            'severity'=>$severity,
            'detail'=>$count > 0 ? "{$count} issue(s) detected" : 'No issue detected',
        ];
    } catch (Throwable $error) {
        return ['key'=>$key,'label'=>$label,'status'=>'ERROR','count'=>0,'severity'=>$severity,'detail'=>'Check failed: '.mb_substr($error->getMessage(),0,180)];
    }
}

function healthStatus(bool $ok, string $okText = 'OK', string $badText = 'Attention'): array
{
    return ['ok'=>$ok,'text'=>$ok ? $okText : $badText];
}

function dashboardDiagnosticHint(string $event, string $message, string $stage): string
{
    $haystack = strtolower($event . ' ' . $message . ' ' . $stage);
    if (str_contains($haystack, 'unknown column') || str_contains($haystack, 'missing column')) {
        return 'Backend/schema mismatch: inspect pending migrations and the endpoint query columns.';
    }
    if (str_contains($haystack, 'supplier_options') || str_contains($haystack, 'supplier options')) {
        return 'Check suppliers/options.php, suppliers table columns and supplier view permissions.';
    }
    if (str_contains($haystack, 'permission') || str_contains($haystack, 'not allowed') || str_contains($haystack, 'unauthorized')) {
        return 'Check the active company membership and the role permission matrix.';
    }
    if (str_contains($haystack, 'database connection') || str_contains($haystack, 'mysqli')) {
        return 'Check DB_* configuration, database reachability and MySQL account privileges.';
    }
    if (str_contains($haystack, 'duplicate') || str_contains($haystack, 'unique constraint')) {
        return 'Check the idempotency key or the unique record that already exists.';
    }
    if (str_contains($haystack, 'quantity') || str_contains($haystack, 'overdelivery')) {
        return 'Compare ordered, already received, accepted, damaged and rejected quantities.';
    }
    return 'Use the request ID to correlate this event with the failing API response.';
}

function recentApplicationLogStats(string $path): array
{
    $stats = [
        'readable' => false,
        'scanned_bytes' => 0,
        'errors_24h' => 0,
        'critical_24h' => 0,
        'warnings_24h' => 0,
        'document_email_failed_24h' => 0,
        'recent_errors' => [],
        'supplier_events' => [],
        'error_groups' => [],
    ];
    if (!is_readable($path)) return $stats;
    $handle = @fopen($path, 'rb');
    if ($handle === false) return $stats;
    $stats['readable'] = true;
    $size = (int)(@filesize($path) ?: 0);
    $maxBytes = 4 * 1024 * 1024;
    $stats['scanned_bytes'] = min($size, $maxBytes);
    if ($size > $maxBytes) {
        fseek($handle, $size - $maxBytes);
        fgets($handle);
    }
    $cutoff = time() - 86400;
    while (($line = fgets($handle)) !== false) {
        $record = json_decode($line, true);
        if (!is_array($record)) continue;
        $timestamp = strtotime((string)($record['timestamp'] ?? $record['created_at'] ?? ''));
        if ($timestamp === false) continue;
        $level = strtoupper((string)($record['level'] ?? ''));
        $event = strtoupper((string)($record['event'] ?? 'UNKNOWN'));
        $context = is_array($record['context'] ?? null) ? $record['context'] : [];
        $references = [];
        foreach (['user_id','company_id','supplier_id','supplier_order_id','supplier_reception_id','invoice_id','document_id','job_id'] as $referenceKey) {
            $referenceValue = (int)($context[$referenceKey] ?? 0);
            if ($referenceValue > 0) $references[] = $referenceKey . '=' . $referenceValue;
        }
        $safeEvent = [
            'timestamp' => (string)($record['timestamp'] ?? ''),
            'level' => $level,
            'event' => $event,
            'request_id' => (string)($record['request_id'] ?? ''),
            'endpoint' => (string)($record['endpoint'] ?? ''),
            'tenant_id' => (int)($record['tenant_id'] ?? 0),
            'actor_id' => (int)($record['actor_id'] ?? 0),
            'stage' => mb_substr((string)($context['stage'] ?? ''), 0, 80),
            'status' => mb_substr((string)($context['supplier_order_status'] ?? $context['status'] ?? ''), 0, 80),
            'references' => implode(' · ', $references),
            'exception' => mb_substr((string)($context['exception'] ?? ''), 0, 120),
            'message' => mb_substr((string)($context['message'] ?? ''), 0, 300),
        ];
        $safeEvent['hint'] = dashboardDiagnosticHint($event, $safeEvent['message'], $safeEvent['stage']);

        if (str_starts_with($event, 'SUPPLIER')) $stats['supplier_events'][] = $safeEvent;
        if (in_array($level, ['ERROR', 'CRITICAL'], true)) $stats['recent_errors'][] = $safeEvent;
        if ($timestamp < $cutoff) continue;

        if (in_array($level, ['ERROR', 'CRITICAL'], true)) {
            $stats['errors_24h']++;
            $stats['error_groups'][$event] = (int)($stats['error_groups'][$event] ?? 0) + 1;
        }
        if ($level === 'CRITICAL') $stats['critical_24h']++;
        if ($level === 'WARNING') $stats['warnings_24h']++;
        if ($event === 'DOCUMENT_EMAIL.FAILED') $stats['document_email_failed_24h']++;
    }
    fclose($handle);
    arsort($stats['error_groups']);
    $stats['recent_errors'] = array_reverse(array_slice($stats['recent_errors'], -100));
    $stats['supplier_events'] = array_reverse(array_slice($stats['supplier_events'], -100));
    return $stats;
}

function renderGate(string $nonce, string $message = '', bool $configurationError = false): never
{
    http_response_code($configurationError ? 503 : 200);
    $safeMessage = h($message);
    $disabled = $configurationError ? 'disabled' : '';
    $csrf = h((string)($_SESSION['super_admin_csrf'] ?? ''));
    echo <<<HTML
<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex,nofollow"><title>El Fatoura — Super Admin</title>
<style nonce="{$nonce}">:root{color-scheme:dark;--navy:#091426;--panel:#101f35;--line:#263a56;--blue:#3276f5;--text:#eef5ff;--muted:#9db0ca;--danger:#fb7185}*{box-sizing:border-box}body{margin:0;min-height:100vh;display:grid;place-items:center;padding:24px;background:radial-gradient(circle at 15% 0,rgba(50,118,245,.24),transparent 34%),var(--navy);font-family:Inter,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;color:var(--text)}.gate{width:min(470px,100%);padding:34px;border:1px solid var(--line);border-radius:26px;background:rgba(16,31,53,.96);box-shadow:0 30px 80px rgba(0,0,0,.35)}.brand{display:flex;align-items:center;gap:13px}.logo{display:grid;place-items:center;width:48px;height:48px;border-radius:15px;background:linear-gradient(135deg,#2563eb,#60a5fa);font-weight:900}.eyebrow{margin:0;color:#7db0ff;font-size:12px;font-weight:850;letter-spacing:.13em;text-transform:uppercase}h1{margin:5px 0 0;font-size:25px}p{color:var(--muted);line-height:1.6}.field{display:grid;gap:8px;margin-top:22px}.field span{font-size:13px;font-weight:800}.input{width:100%;min-height:48px;border:1px solid var(--line);border-radius:13px;padding:0 14px;background:#09172a;color:var(--text);font:inherit}.button{width:100%;min-height:48px;margin-top:14px;border:0;border-radius:13px;background:linear-gradient(135deg,#2563eb,#4f8cff);color:white;font-weight:900;cursor:pointer}.button:disabled{opacity:.45}.message{padding:11px 13px;border:1px solid rgba(251,113,133,.35);border-radius:12px;background:rgba(251,113,133,.1);color:#fecdd3;font-size:13px}</style></head><body><main class="gate"><div class="brand"><div class="logo">EF</div><div><p class="eyebrow">Restricted operations</p><h1>Super Admin</h1></div></div><p>Infrastructure, database migrations and direct SQL control for the application owner.</p>
<style nonce="{$nonce}">.logo{font-size:0;background-image:url('/el-fatoura-icon.svg');background-position:center;background-size:cover;background-repeat:no-repeat}</style>
HTML;
    if ($safeMessage !== '') echo '<div class="message">' . $safeMessage . '</div>';
    echo <<<HTML
<form method="post"><input type="hidden" name="action" value="login"><input type="hidden" name="csrf_token" value="{$csrf}"><label class="field"><span>Super Admin access key</span><input class="input" type="password" name="access_key" autocomplete="current-password" required {$disabled}></label><button class="button" type="submit" {$disabled}>Open control center</button></form></main></body></html>
HTML;
    exit;
}

if (BACKEND_DIRECTORY === '' || !is_file(BACKEND_DIRECTORY . '/config/env.php')) {
    http_response_code(503);
    exit('Backend configuration is unavailable. Place server_dashboard.php either beside the backend directory or directly inside it.');
}
require_once BACKEND_DIRECTORY . '/config/env.php';
try {
    loadEnv(ENV_FILE);
} catch (Throwable) {
    http_response_code(503);
    exit('Environment configuration is unavailable.');
}

if (envFlag('SERVER_DASHBOARD_REQUIRE_HTTPS', true) && !requestIsHttps()) {
    http_response_code(426);
    exit('HTTPS is required for the Super Admin portal.');
}

$allowedIps = array_values(array_filter(array_map('trim', explode(',', (string)($_ENV['SERVER_DASHBOARD_ALLOWED_IPS'] ?? '')))));
if ($allowedIps && !in_array((string)($_SERVER['REMOTE_ADDR'] ?? ''), $allowedIps, true)) {
    http_response_code(403);
    exit('Access denied.');
}

session_name('el_fatoura_super_admin');
session_set_cookie_params([
    'lifetime' => 0,
    'path' => '/',
    'secure' => requestIsHttps(),
    'httponly' => true,
    'samesite' => 'Strict',
]);
session_start();
$_SESSION['super_admin_csrf'] ??= bin2hex(random_bytes(32));

$accessKey = trim((string)($_ENV['SERVER_DASHBOARD_ACCESS_KEY'] ?? ''));
if (strlen($accessKey) < 24) {
    renderGate($cspNonce, 'Set SERVER_DASHBOARD_ACCESS_KEY in backend/.env to a random value of at least 24 characters.', true);
}

$action = (string)($_POST['action'] ?? '');
if ($action === 'login') {
    if (!csrfValid()) renderGate($cspNonce, 'The login request expired. Refresh and try again.');
    $attempts = (int)($_SESSION['super_admin_login_attempts'] ?? 0);
    $blockedUntil = (int)($_SESSION['super_admin_blocked_until'] ?? 0);
    if ($blockedUntil > time()) renderGate($cspNonce, 'Too many attempts. Try again in a few minutes.');
    if (!hash_equals($accessKey, (string)($_POST['access_key'] ?? ''))) {
        $attempts++;
        $_SESSION['super_admin_login_attempts'] = $attempts;
        if ($attempts >= 5) $_SESSION['super_admin_blocked_until'] = time() + 300;
        renderGate($cspNonce, 'Invalid Super Admin access key.');
    }
    session_regenerate_id(true);
    $_SESSION['super_admin_authenticated'] = true;
    $_SESSION['super_admin_last_activity'] = time();
    $_SESSION['super_admin_login_attempts'] = 0;
    $_SESSION['super_admin_csrf'] = bin2hex(random_bytes(32));
    header('Location: ' . strtok((string)($_SERVER['REQUEST_URI'] ?? '/server_dashboard.php'), '?'));
    exit;
}

if (empty($_SESSION['super_admin_authenticated'])) renderGate($cspNonce);
if (time() - (int)($_SESSION['super_admin_last_activity'] ?? 0) > SESSION_IDLE_SECONDS) {
    $_SESSION = [];
    session_regenerate_id(true);
    $_SESSION['super_admin_csrf'] = bin2hex(random_bytes(32));
    renderGate($cspNonce, 'The Super Admin session expired.');
}
$_SESSION['super_admin_last_activity'] = time();

if ($action === 'logout') {
    if (!csrfValid()) { http_response_code(403); exit('Invalid request.'); }
    session_unset();
    session_destroy();
    header('Location: ' . strtok((string)($_SERVER['REQUEST_URI'] ?? '/server_dashboard.php'), '?'));
    exit;
}

mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
$dbHost = envFirst(['SUPER_ADMIN_DB_HOST', 'DB_HOST']);
$dbPort = (int)envFirst(['SUPER_ADMIN_DB_PORT', 'DB_PORT'], '3306');
$dbName = envFirst(['SUPER_ADMIN_DB_NAME', 'DB_NAME']);
$dbUser = envFirst(['SUPER_ADMIN_DB_USER', 'DB_USER']);
$dbPass = envFirst(['SUPER_ADMIN_DB_PASS', 'DB_PASS']);
$db = null;
$connectionError = '';
$connectionLatency = 0.0;
try {
    $connectionStart = microtime(true);
    $db = new mysqli($dbHost, $dbUser, $dbPass, $dbName, $dbPort);
    $db->set_charset('utf8mb4');
    $connectionLatency = round((microtime(true) - $connectionStart) * 1000, 2);
} catch (Throwable $error) {
    $connectionError = $error->getMessage();
}

$sqlEnabled = envFlag('SERVER_DASHBOARD_SQL_ENABLED', false);
$sqlText = (string)($_POST['sql'] ?? 'SELECT VERSION() AS database_version, NOW() AS server_time;');
$sqlResults = [];
$operationMessage = '';
$operationError = '';
$activeTab = 'overview';

if ($db instanceof mysqli) {
    try {
        ensureSchemaMigrationsTable($db);
    } catch (Throwable $error) {
        $operationError = 'Migration tracking could not be initialized: ' . $error->getMessage();
    }
}

if ($action === 'load_migration') {
    $activeTab = 'sql';
    if (!csrfValid()) { http_response_code(403); exit('Invalid request.'); }
    $migration = basename((string)($_POST['migration'] ?? ''));
    $path = BACKEND_DIRECTORY . '/sql/' . $migration;
    if ($migration === '' || !str_ends_with($migration, '.sql') || !is_file($path)) $operationError = 'Migration file not found.';
    else {
        $sqlText = (string)file_get_contents($path);
        $operationMessage = 'Migration loaded into the SQL Console for inspection.';
    }
}

if ($action === 'run_migration') {
    $activeTab = 'migrations';
    $started = microtime(true);
    $migration = basename((string)($_POST['migration'] ?? ''));
    $path = BACKEND_DIRECTORY . '/sql/' . $migration;
    $checksumForAudit = is_file($path) ? (string)hash_file('sha256', $path) : '';
    try {
        if (!csrfValid()) throw new RuntimeException('The request expired. Refresh and try again.');
        if (!$sqlEnabled) throw new RuntimeException('SQL execution is disabled in backend/.env.');
        if (!($db instanceof mysqli)) throw new RuntimeException('Database connection is unavailable.');
        if ($migration === '' || !str_ends_with($migration, '.sql')) throw new RuntimeException('Invalid migration.');
        if (!is_file($path) || !is_readable($path)) throw new RuntimeException('Migration file not found.');
        if (empty($_POST['confirm_migration'])) throw new RuntimeException('Confirm that you reviewed the migration and have a current backup.');
        if (!hash_equals($dbName, trim((string)($_POST['confirm_database'] ?? '')))) throw new RuntimeException('Type the exact database name to run this migration.');

        $result = runMigration($db, $path, $migration);
        $operationMessage = 'Migration ' . $result['version'] . ' applied successfully in ' . number_format((float)$result['execution_ms'], 2) . ' ms.';
        migrationAudit($migration, (string)$result['checksum'], $dbName, $dbUser, true, (microtime(true) - $started) * 1000, null);
    } catch (Throwable $error) {
        $operationError = $error->getMessage();
        migrationAudit($migration, $checksumForAudit, $dbName, $dbUser, false, (microtime(true) - $started) * 1000, $operationError);
    }
}

if ($action === 'run_sql') {
    $activeTab = 'sql';
    $started = microtime(true);
    $isWrite = !sqlIsReadOnly($sqlText);
    try {
        if (!csrfValid()) throw new RuntimeException('The request expired. Refresh and try again.');
        if (!$sqlEnabled) throw new RuntimeException('SQL execution is disabled in backend/.env.');
        if (!($db instanceof mysqli)) throw new RuntimeException('The database connection is unavailable.');
        if (trim($sqlText) === '') throw new RuntimeException('Enter at least one SQL statement.');
        if (strlen($sqlText) > SQL_MAX_BYTES) throw new RuntimeException('The SQL request exceeds the 256 KB limit.');
        if ($isWrite) {
            if (empty($_POST['confirm_write'])) throw new RuntimeException('Confirm that this SQL can change data or schema.');
            if (!hash_equals($dbName, trim((string)($_POST['confirm_database'] ?? '')))) throw new RuntimeException('Type the exact database name to authorize write access.');
        }
        $sqlResults = executeSql($db, $sqlText);
        $operationMessage = count($sqlResults) . ' SQL result set(s) completed.';
        sqlAudit($sqlText, $dbName, $dbUser, $isWrite, true, (microtime(true) - $started) * 1000, null);
    } catch (Throwable $error) {
        $operationError = $error->getMessage();
        sqlAudit($sqlText, $dbName, $dbUser, $isWrite, false, (microtime(true) - $started) * 1000, $operationError);
    }
}


// -----------------------------------------------------------------------------
// Super Admin operational actions
// -----------------------------------------------------------------------------

if ($action === 'create_backup') {
    $activeTab = 'backups';
    try {
        if (!csrfValid()) throw new RuntimeException('The request expired. Refresh and try again.');
        if (!($db instanceof mysqli)) throw new RuntimeException('Database connection is unavailable.');
        if (!hash_equals($dbName, trim((string)($_POST['confirm_database'] ?? '')))) {
            throw new RuntimeException('Type the exact database name to create a backup.');
        }

        $backup = createDatabaseBackup($dbHost, $dbPort, $dbName, $dbUser, $dbPass);
        $operationMessage = 'Backup created: ' . $backup['name'] . ' (' . formatBytes((float)$backup['size']) . ') using ' . $backup['dump_binary'] . ($backup['fallback_level'] > 1 ? ' with compatibility fallback #' . $backup['fallback_level'] : '') . '.';
    } catch (Throwable $error) {
        $operationError = $error->getMessage();
    }
}

if ($action === 'verify_backup') {
    $activeTab = 'backups';
    try {
        if (!csrfValid()) throw new RuntimeException('The request expired. Refresh and try again.');
        $path = safeBackupFile((string)($_POST['backup'] ?? ''));
        if ($path === '') throw new RuntimeException('Backup file not found.');
        $expected = is_file($path . '.sha256') ? trim((string)file_get_contents($path . '.sha256')) : '';
        if ($expected === '') throw new RuntimeException('No checksum is stored for this backup.');
        $actual = hash_file('sha256', $path);
        if (!hash_equals($expected, $actual)) throw new RuntimeException('Backup checksum mismatch. Do not use this backup.');
        $operationMessage = 'Backup verified successfully: ' . basename($path) . '.';
    } catch (Throwable $error) {
        $operationError = $error->getMessage();
    }
}

if ($action === 'download_backup') {
    try {
        if (!csrfValid()) throw new RuntimeException('The request expired. Refresh and try again.');
        $path = safeBackupFile((string)($_POST['backup'] ?? ''));
        if ($path === '') throw new RuntimeException('Backup file not found.');

        header_remove('Content-Type');
        header('Content-Type: application/octet-stream');
        header('Content-Disposition: attachment; filename="' . basename($path) . '"');
        header('Content-Length: ' . (string)filesize($path));
        header('X-Content-Type-Options: nosniff');
        readfile($path);
        exit;
    } catch (Throwable $error) {
        $activeTab = 'backups';
        $operationError = $error->getMessage();
    }
}

if ($action === 'accept_user') {
    $activeTab = 'security';
    $targetUserId = (int)($_POST['user_id'] ?? 0);
    $transactionStarted = false;
    try {
        if (!csrfValid()) throw new RuntimeException('The request expired. Refresh and try again.');
        if (!($db instanceof mysqli)) throw new RuntimeException('Database connection is unavailable.');
        if (!dashboardColumnExists($db, 'users', 'account_status') || !dashboardColumnExists($db, 'users', 'approved_at')) {
            throw new RuntimeException('Run the 2026-09-08 user account approval migration first.');
        }
        $confirmUserId = (int)($_POST['confirm_user_id'] ?? 0);
        if ($targetUserId <= 0 || $confirmUserId !== $targetUserId) {
            throw new RuntimeException('Confirm the exact pending user before accepting it.');
        }

        $db->begin_transaction();
        $transactionStarted = true;
        $statement = $db->prepare('SELECT id,account_status FROM users WHERE id=? LIMIT 1 FOR UPDATE');
        $statement->bind_param('i', $targetUserId);
        $statement->execute();
        $targetUser = $statement->get_result()->fetch_assoc() ?: null;
        $statement->close();

        if (!$targetUser) throw new RuntimeException('User account not found.');
        if (strtoupper((string)$targetUser['account_status']) !== 'PENDING') {
            throw new RuntimeException('Only pending user accounts can be accepted.');
        }

        $statement = $db->prepare("UPDATE users SET account_status='ACTIVE',approved_at=NOW(),archived_at=NULL,archived_by=NULL,archive_reason=NULL WHERE id=? AND account_status='PENDING'");
        $statement->bind_param('i', $targetUserId);
        $statement->execute();
        $affected = $statement->affected_rows;
        $statement->close();
        if ($affected !== 1) throw new RuntimeException('The user account changed before it could be accepted.');

        $db->commit();
        $transactionStarted = false;
        $operationMessage = 'User #' . $targetUserId . ' accepted. The account can now sign in.';
        superAdminOperationAudit('SUPER_ADMIN.USER_ACCEPTED', $targetUserId, true);
    } catch (Throwable $error) {
        if ($transactionStarted && $db instanceof mysqli) {
            try { $db->rollback(); } catch (Throwable) {}
        }
        $operationError = $error->getMessage();
        superAdminOperationAudit('SUPER_ADMIN.USER_ACCEPT_FAILED', $targetUserId, false, $operationError);
    }
}

if ($action === 'set_user_approval_policy') {
    $activeTab = 'security';
    $approvalRequired = (string)($_POST['approval_required'] ?? '') === '1';
    try {
        if (!csrfValid()) throw new RuntimeException('The request expired. Refresh and try again.');
        if (!($db instanceof mysqli)) throw new RuntimeException('Database connection is unavailable.');
        if (!dashboardTableExists($db, 'erp_platform_settings')) {
            throw new RuntimeException('Run the 2026-09-09 new-user approval policy migration first.');
        }
        $settingKey = 'new_user_approval_required';
        $settingValue = $approvalRequired ? '1' : '0';
        $statement = $db->prepare('INSERT INTO erp_platform_settings(setting_key,setting_value) VALUES(?,?) ON DUPLICATE KEY UPDATE setting_value=VALUES(setting_value)');
        $statement->bind_param('ss', $settingKey, $settingValue);
        $statement->execute();
        $statement->close();
        $operationMessage = $approvalRequired
            ? 'Manual approval enabled. New users will remain pending until accepted.'
            : 'Automatic activation enabled. New users can sign in without Super Admin approval.';
        superAdminOperationAudit(
            $approvalRequired ? 'SUPER_ADMIN.USER_APPROVAL_REQUIRED' : 'SUPER_ADMIN.USER_AUTO_ACTIVATION_ENABLED',
            0,
            true
        );
    } catch (Throwable $error) {
        $operationError = $error->getMessage();
        superAdminOperationAudit('SUPER_ADMIN.USER_APPROVAL_POLICY_FAILED', 0, false, $operationError);
    }
}

if ($action === 'revoke_user_sessions') {
    $activeTab = 'security';
    try {
        if (!csrfValid()) throw new RuntimeException('The request expired. Refresh and try again.');
        if (!($db instanceof mysqli)) throw new RuntimeException('Database connection is unavailable.');
        if (!dashboardTableExists($db, 'auth_refresh_tokens')) throw new RuntimeException('Refresh-token table is unavailable.');
        if (!dashboardColumnExists($db, 'auth_refresh_tokens', 'user_id') || !dashboardColumnExists($db, 'auth_refresh_tokens', 'revoked_at')) {
            throw new RuntimeException('Refresh-token schema does not support session revocation.');
        }

        $targetUserId = (int)($_POST['user_id'] ?? 0);
        $confirmUserId = (int)($_POST['confirm_user_id'] ?? 0);
        if ($targetUserId <= 0 || $confirmUserId !== $targetUserId) {
            throw new RuntimeException('Type the exact user ID to revoke its sessions.');
        }

        $statement = $db->prepare("UPDATE auth_refresh_tokens SET revoked_at=NOW() WHERE user_id=? AND revoked_at IS NULL");
        $statement->bind_param('i', $targetUserId);
        $statement->execute();
        $affected = $statement->affected_rows;
        $statement->close();
        $operationMessage = $affected . ' active refresh-token session(s) revoked for user #' . $targetUserId . '.';
    } catch (Throwable $error) {
        $operationError = $error->getMessage();
    }
}

if ($action === 'inspect_tenant') {
    $activeTab = 'tenants';
}

if ($action === 'audit_filter') {
    $activeTab = 'audit';
}


$tableCount = 0;
$databaseSize = 0.0;
$largestTables = [];
$schemaTables = [];
$schemaRelations = [];
$schemaColumnCount = 0;
$schemaPrimaryKeyCount = 0;
$schemaForeignKeyCount = 0;
$appliedMigrations = [];
$databaseVersion = '-';
$configuredAppLogPath = trim((string)($_ENV['APP_LOG_PATH'] ?? ''));
$logStats = recentApplicationLogStats($configuredAppLogPath !== '' ? $configuredAppLogPath : BACKEND_DIRECTORY . '/storage/logs/app.jsonl');
$operations = [
    'email_sent_24h' => 0,
    'email_sent_7d' => 0,
    'email_failed_24h' => $logStats['document_email_failed_24h'],
    'login_success_24h' => 0,
    'login_failed_24h' => 0,
    'login_2fa_failed_24h' => 0,
    'audit_events_24h' => 0,
    'active_sessions' => 0,
    'total_users' => 0,
    'active_users' => 0,
    'pending_users' => 0,
    'archived_users' => 0,
    'verified_users' => 0,
    'twofa_users' => 0,
    'pending_invitations' => 0,
    'queued_jobs' => 0,
    'running_jobs' => 0,
    'failed_jobs' => 0,
];
$emailActivity = [];
$authenticationActivity = [];
$registrationActivity = [];
$recentActivity = [];
$jobActivity = [];
$applicationChecks = [];

$databaseHealth = [
    'tables_without_pk' => [],
    'non_innodb_tables' => [],
    'collations' => [],
    'auto_increment_risk' => [],
    'total_indexes' => 0,
];
$systemHealth = [];
$integrityChecks = [];
$companiesList = [];
$tenantInspection = null;
$tenantCounts = [];
$tenantMismatchCounts = [];
$securityUsers = [];
$securitySessions = [];
$securityInvitations = [];
$newUserApprovalRequired = true;
$userApprovalPolicyAvailable = false;
$auditExplorerRows = [];
$auditExplorerTotal = 0;
$auditPage = max(1, (int)($_POST['audit_page'] ?? $_GET['audit_page'] ?? 1));
$auditPageSize = 100;
$auditFilters = [
    'action' => trim((string)($_POST['audit_action'] ?? $_GET['audit_action'] ?? '')),
    'entity_type' => trim((string)($_POST['audit_entity_type'] ?? $_GET['audit_entity_type'] ?? '')),
    'actor_id' => trim((string)($_POST['audit_actor_id'] ?? $_GET['audit_actor_id'] ?? '')),
    'from' => trim((string)($_POST['audit_from'] ?? $_GET['audit_from'] ?? '')),
    'to' => trim((string)($_POST['audit_to'] ?? $_GET['audit_to'] ?? '')),
];
$backupList = backupFiles();

if ($db instanceof mysqli) {
    try {
        $status = $db->query("SELECT VERSION() version,(SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE() AND table_type='BASE TABLE') table_count,(SELECT COALESCE(SUM(data_length+index_length),0) FROM information_schema.tables WHERE table_schema=DATABASE()) database_size")->fetch_assoc();
        $databaseVersion = (string)($status['version'] ?? '-');
        $tableCount = (int)($status['table_count'] ?? 0);
        $databaseSize = (float)($status['database_size'] ?? 0);
        $largestTables = $db->query("SELECT table_name,table_rows,data_length+index_length total_bytes FROM information_schema.tables WHERE table_schema=DATABASE() AND table_type='BASE TABLE' ORDER BY total_bytes DESC LIMIT 8")->fetch_all(MYSQLI_ASSOC);

        // Database schema visualization data.
        $tableRows = $db->query("SELECT table_name,engine,table_rows,data_length+index_length total_bytes FROM information_schema.tables WHERE table_schema=DATABASE() AND table_type='BASE TABLE' ORDER BY table_name")->fetch_all(MYSQLI_ASSOC);
        foreach ($tableRows as $tableRow) {
            $tableName = (string)$tableRow['table_name'];
            $schemaTables[$tableName] = [
                'name' => $tableName,
                'engine' => (string)($tableRow['engine'] ?? ''),
                'rows' => (int)($tableRow['table_rows'] ?? 0),
                'bytes' => (float)($tableRow['total_bytes'] ?? 0),
                'columns' => [],
                'outgoing' => [],
                'incoming' => [],
            ];
        }

        $columnRows = $db->query("SELECT table_name,column_name,column_type,is_nullable,column_key,extra,column_default,ordinal_position FROM information_schema.columns WHERE table_schema=DATABASE() ORDER BY table_name,ordinal_position")->fetch_all(MYSQLI_ASSOC);
        foreach ($columnRows as $columnRow) {
            $tableName = (string)$columnRow['table_name'];
            if (!isset($schemaTables[$tableName])) continue;
            $isPrimary = strtoupper((string)$columnRow['column_key']) === 'PRI';
            $schemaTables[$tableName]['columns'][] = [
                'name' => (string)$columnRow['column_name'],
                'type' => (string)$columnRow['column_type'],
                'nullable' => strtoupper((string)$columnRow['is_nullable']) === 'YES',
                'key' => (string)$columnRow['column_key'],
                'extra' => (string)$columnRow['extra'],
                'default' => $columnRow['column_default'],
                'primary' => $isPrimary,
                'foreign' => false,
            ];
            $schemaColumnCount++;
            if ($isPrimary) $schemaPrimaryKeyCount++;
        }

        $relationRows = $db->query("SELECT kcu.constraint_name,kcu.table_name,kcu.column_name,kcu.referenced_table_name,kcu.referenced_column_name,rc.update_rule,rc.delete_rule FROM information_schema.key_column_usage kcu LEFT JOIN information_schema.referential_constraints rc ON rc.constraint_schema=kcu.constraint_schema AND rc.constraint_name=kcu.constraint_name WHERE kcu.constraint_schema=DATABASE() AND kcu.referenced_table_name IS NOT NULL ORDER BY kcu.table_name,kcu.constraint_name,kcu.ordinal_position")->fetch_all(MYSQLI_ASSOC);
        foreach ($relationRows as $relationRow) {
            $from = (string)$relationRow['table_name'];
            $to = (string)$relationRow['referenced_table_name'];
            $relation = [
                'constraint' => (string)$relationRow['constraint_name'],
                'from_table' => $from,
                'from_column' => (string)$relationRow['column_name'],
                'to_table' => $to,
                'to_column' => (string)$relationRow['referenced_column_name'],
                'update_rule' => (string)($relationRow['update_rule'] ?? ''),
                'delete_rule' => (string)($relationRow['delete_rule'] ?? ''),
            ];
            $schemaRelations[] = $relation;
            $schemaForeignKeyCount++;
            if (isset($schemaTables[$from])) {
                $schemaTables[$from]['outgoing'][] = $relation;
                foreach ($schemaTables[$from]['columns'] as &$column) {
                    if ($column['name'] === $relation['from_column']) $column['foreign'] = true;
                }
                unset($column);
            }
            if (isset($schemaTables[$to])) $schemaTables[$to]['incoming'][] = $relation;
        }
        if (dashboardTableExists($db, 'schema_migrations')) {
            foreach ($db->query("SELECT version,checksum,applied_at,execution_ms FROM schema_migrations ORDER BY version") as $row) {
                $appliedMigrations[(string)$row['version']] = [
                    'checksum' => trim((string)($row['checksum'] ?? '')),
                    'applied_at' => (string)($row['applied_at'] ?? ''),
                    'execution_ms' => $row['execution_ms'] !== null ? (float)$row['execution_ms'] : null,
                ];
            }
        }
    } catch (Throwable $error) {
        if ($operationError === '') $operationError = $error->getMessage();
    }

    if (dashboardTableExists($db, 'app_audit_log')) {
        $auditStats = dashboardRow($db, "SELECT
            COALESCE(SUM(created_at >= NOW() - INTERVAL 1 DAY),0) audit_events_24h,
            COALESCE(SUM(action IN ('DOCUMENT_EMAIL.SENT','EMAIL.SENT') AND created_at >= NOW() - INTERVAL 1 DAY),0) email_sent_24h,
            COALESCE(SUM(action IN ('DOCUMENT_EMAIL.SENT','EMAIL.SENT') AND created_at >= NOW() - INTERVAL 7 DAY),0) email_sent_7d,
            COALESCE(SUM(action='EMAIL.FAILED' AND created_at >= NOW() - INTERVAL 1 DAY),0) email_failed_24h,
            COALESCE(SUM(action='AUTH.LOGIN_SUCCEEDED' AND created_at >= NOW() - INTERVAL 1 DAY),0) login_success_24h,
            COALESCE(SUM(action IN ('AUTH.LOGIN_FAILED','AUTH.LOGIN_2FA_FAILED','AUTH.LOGIN_BLOCKED_ARCHIVED','AUTH.LOGIN_BLOCKED_PENDING') AND created_at >= NOW() - INTERVAL 1 DAY),0) login_failed_24h,
            COALESCE(SUM(action='AUTH.LOGIN_2FA_FAILED' AND created_at >= NOW() - INTERVAL 1 DAY),0) login_2fa_failed_24h
            FROM app_audit_log");
        foreach (['audit_events_24h', 'email_sent_24h', 'email_sent_7d', 'login_success_24h', 'login_failed_24h', 'login_2fa_failed_24h'] as $key) $operations[$key] = (int)($auditStats[$key] ?? 0);
        $operations['email_failed_24h'] += (int)($auditStats['email_failed_24h'] ?? 0);
        $emailActivity = dashboardRows($db, "SELECT entity_type channel,SUM(action IN ('DOCUMENT_EMAIL.SENT','EMAIL.SENT')) sent,SUM(action='EMAIL.FAILED') failed,MAX(created_at) last_activity FROM app_audit_log WHERE created_at >= NOW() - INTERVAL 30 DAY AND action IN ('DOCUMENT_EMAIL.SENT','EMAIL.SENT','EMAIL.FAILED') GROUP BY entity_type ORDER BY sent DESC, failed DESC");
        $authenticationActivity = dashboardRows($db, "SELECT DATE(created_at) activity_day,SUM(action='AUTH.LOGIN_SUCCEEDED') succeeded,SUM(action IN ('AUTH.LOGIN_FAILED','AUTH.LOGIN_2FA_FAILED','AUTH.LOGIN_BLOCKED_ARCHIVED','AUTH.LOGIN_BLOCKED_PENDING')) failed FROM app_audit_log WHERE created_at >= CURDATE() - INTERVAL 6 DAY AND action IN ('AUTH.LOGIN_SUCCEEDED','AUTH.LOGIN_FAILED','AUTH.LOGIN_2FA_FAILED','AUTH.LOGIN_BLOCKED_ARCHIVED','AUTH.LOGIN_BLOCKED_PENDING') GROUP BY DATE(created_at) ORDER BY activity_day DESC");
        $recentActivity = dashboardRows($db, "SELECT action,entity_type,entity_id,actor_id,created_at FROM app_audit_log ORDER BY created_at DESC LIMIT 30");
    }

    if (dashboardTableExists($db, 'users')) {
        $userStats = dashboardRow($db, "SELECT COUNT(*) total_users,SUM(COALESCE(account_status,'ACTIVE')='ACTIVE') active_users,SUM(account_status='PENDING') pending_users,SUM(account_status='ARCHIVED') archived_users,SUM(email_verified_at IS NOT NULL) verified_users,SUM(COALESCE(google2fa_enabled,0)=1) twofa_users FROM users");
        foreach (['total_users', 'active_users', 'pending_users', 'archived_users', 'verified_users', 'twofa_users'] as $key) $operations[$key] = (int)($userStats[$key] ?? 0);
        $registrationActivity = dashboardRows($db, "SELECT DATE(created_at) activity_day,COUNT(*) registered FROM users WHERE created_at >= CURDATE() - INTERVAL 13 DAY GROUP BY DATE(created_at) ORDER BY activity_day");
    }
    if (dashboardTableExists($db, 'auth_refresh_tokens')) {
        $sessionStats = dashboardRow($db, "SELECT COUNT(*) active_sessions FROM auth_refresh_tokens WHERE revoked_at IS NULL AND expires_at > NOW()");
        $operations['active_sessions'] = (int)($sessionStats['active_sessions'] ?? 0);
    }
    if (dashboardTableExists($db, 'company_invitations')) {
        $invitationStats = dashboardRow($db, "SELECT COUNT(*) pending_invitations FROM company_invitations WHERE status='PENDING' AND expires_at > NOW()");
        $operations['pending_invitations'] = (int)($invitationStats['pending_invitations'] ?? 0);
    }
    if (dashboardTableExists($db, 'erp_background_jobs')) {
        $jobActivity = dashboardRows($db, "SELECT status,COUNT(*) total,MAX(created_at) last_activity FROM erp_background_jobs GROUP BY status ORDER BY total DESC");
        foreach ($jobActivity as $jobRow) {
            $status = strtoupper((string)($jobRow['status'] ?? ''));
            $total = (int)($jobRow['total'] ?? 0);
            if (in_array($status, ['PENDING', 'QUEUED'], true)) $operations['queued_jobs'] += $total;
            if ($status === 'RUNNING') $operations['running_jobs'] += $total;
            if ($status === 'FAILED') $operations['failed_jobs'] += $total;
        }
    }

    // -------------------------------------------------------------------------
    // Application compatibility checks
    // -------------------------------------------------------------------------
    $supplierOptionsPath = BACKEND_DIRECTORY . '/suppliers/options.php';
    $supplierOptionsSource = is_file($supplierOptionsPath) ? (string)file_get_contents($supplierOptionsPath) : '';
    $invalidSupplierOptionColumns = [];
    foreach (['contact_person', 'payment_terms'] as $legacyColumn) {
        if (str_contains($supplierOptionsSource, $legacyColumn)
            && !dashboardColumnExists($db, 'suppliers', $legacyColumn)) {
            $invalidSupplierOptionColumns[] = $legacyColumn;
        }
    }
    $applicationChecks[] = [
        'label' => 'Supplier options endpoint',
        'status' => $supplierOptionsSource === '' ? 'ERROR' : ($invalidSupplierOptionColumns ? 'ISSUE' : 'OK'),
        'detail' => $supplierOptionsSource === ''
            ? 'backend/suppliers/options.php is missing.'
            : ($invalidSupplierOptionColumns
                ? 'Endpoint queries missing columns: ' . implode(', ', $invalidSupplierOptionColumns) . '.'
                : 'Endpoint query matches the installed suppliers schema.'),
        'hint' => $invalidSupplierOptionColumns
            ? 'Deploy the corrected suppliers/options.php endpoint.'
            : 'No action required.',
    ];

    $supplierWorkflowRequirements = [
        'products.selling_price_required' => ['products', 'selling_price_required'],
        'erp_supplier_receptions.confirmation_hash' => ['erp_supplier_receptions', 'confirmation_hash'],
        'erp_supplier_receptions.exception_type' => ['erp_supplier_receptions', 'exception_type'],
        'erp_supplier_reception_items.accepted_qty' => ['erp_supplier_reception_items', 'accepted_qty'],
        'erp_supplier_reception_items.selling_price' => ['erp_supplier_reception_items', 'selling_price'],
    ];
    $missingSupplierWorkflowSchema = [];
    foreach ($supplierWorkflowRequirements as $requirementLabel => [$requiredTable, $requiredColumn]) {
        if (!dashboardColumnExists($db, $requiredTable, $requiredColumn)) {
            $missingSupplierWorkflowSchema[] = $requirementLabel;
        }
    }
    $applicationChecks[] = [
        'label' => 'Supplier workflow schema',
        'status' => $missingSupplierWorkflowSchema ? 'ISSUE' : 'OK',
        'detail' => $missingSupplierWorkflowSchema
            ? 'Missing: ' . implode(', ', $missingSupplierWorkflowSchema) . '.'
            : 'Ordering, discrepancy, reception and pricing columns are installed.',
        'hint' => $missingSupplierWorkflowSchema
            ? 'Review and apply the pending supplier workflow migrations.'
            : 'No action required.',
    ];

    $supplierDiagnosticsEnabled = str_contains($supplierOptionsSource, 'SUPPLIER_OPTIONS.LOAD_FAILED')
        && is_file(BACKEND_DIRECTORY . '/supplier_orders/save_supplier_order.php')
        && is_file(BACKEND_DIRECTORY . '/supplier_receptions/save_supplier_reception.php');
    $applicationChecks[] = [
        'label' => 'Supplier diagnostics',
        'status' => $supplierDiagnosticsEnabled ? 'OK' : 'WARNING',
        'detail' => $supplierDiagnosticsEnabled
            ? 'Supplier endpoint failures include a stage and request ID.'
            : 'One or more diagnostic endpoint updates are not deployed.',
        'hint' => $supplierDiagnosticsEnabled
            ? 'Use the Supplier workflow table below during testing.'
            : 'Deploy the updated supplier workflow backend files.',
    ];

    // -------------------------------------------------------------------------
    // Database health
    // -------------------------------------------------------------------------
    $databaseHealth['tables_without_pk'] = dashboardRows($db, "
        SELECT t.table_name
        FROM information_schema.tables t
        WHERE t.table_schema=DATABASE()
          AND t.table_type='BASE TABLE'
          AND NOT EXISTS (
              SELECT 1
              FROM information_schema.table_constraints tc
              WHERE tc.table_schema=t.table_schema
                AND tc.table_name=t.table_name
                AND tc.constraint_type='PRIMARY KEY'
          )
        ORDER BY t.table_name
    ");

    $databaseHealth['non_innodb_tables'] = dashboardRows($db, "
        SELECT table_name,engine
        FROM information_schema.tables
        WHERE table_schema=DATABASE()
          AND table_type='BASE TABLE'
          AND COALESCE(engine,'') <> 'InnoDB'
        ORDER BY table_name
    ");

    $databaseHealth['collations'] = dashboardRows($db, "
        SELECT table_collation,COUNT(*) total
        FROM information_schema.tables
        WHERE table_schema=DATABASE()
          AND table_type='BASE TABLE'
        GROUP BY table_collation
        ORDER BY total DESC
    ");

    $indexRow = dashboardRow($db, "
        SELECT COUNT(DISTINCT CONCAT(table_name,':',index_name)) total_indexes
        FROM information_schema.statistics
        WHERE table_schema=DATABASE()
    ");
    $databaseHealth['total_indexes'] = (int)($indexRow['total_indexes'] ?? 0);

    $databaseHealth['auto_increment_risk'] = dashboardRows($db, "
        SELECT
            t.table_name,
            t.auto_increment,
            c.column_type,
            CASE
                WHEN c.column_type LIKE 'tinyint unsigned%' THEN 255
                WHEN c.column_type LIKE 'tinyint%' THEN 127
                WHEN c.column_type LIKE 'smallint unsigned%' THEN 65535
                WHEN c.column_type LIKE 'smallint%' THEN 32767
                WHEN c.column_type LIKE 'mediumint unsigned%' THEN 16777215
                WHEN c.column_type LIKE 'mediumint%' THEN 8388607
                WHEN c.column_type LIKE 'int unsigned%' THEN 4294967295
                WHEN c.column_type LIKE 'int%' THEN 2147483647
                WHEN c.column_type LIKE 'bigint unsigned%' THEN 18446744073709551615
                WHEN c.column_type LIKE 'bigint%' THEN 9223372036854775807
                ELSE NULL
            END max_value
        FROM information_schema.tables t
        JOIN information_schema.columns c
          ON c.table_schema=t.table_schema
         AND c.table_name=t.table_name
         AND c.extra LIKE '%auto_increment%'
        WHERE t.table_schema=DATABASE()
          AND t.auto_increment IS NOT NULL
        HAVING max_value IS NOT NULL
           AND (t.auto_increment / max_value) >= 0.70
        ORDER BY (t.auto_increment / max_value) DESC
    ");

    // -------------------------------------------------------------------------
    // System health
    // -------------------------------------------------------------------------
    $storagePath = BACKEND_DIRECTORY . '/storage';
    $diskFree = @disk_free_space(BACKEND_DIRECTORY);
    $diskTotal = @disk_total_space(BACKEND_DIRECTORY);
    $systemHealth = [
        ['name'=>'PHP runtime','ok'=>version_compare(PHP_VERSION,'8.1.0','>='),'value'=>PHP_VERSION,'detail'=>'Recommended: PHP 8.1+'],
        ['name'=>'mysqli extension','ok'=>extension_loaded('mysqli'),'value'=>extension_loaded('mysqli')?'Loaded':'Missing','detail'=>'Required for database access'],
        ['name'=>'OpenSSL extension','ok'=>extension_loaded('openssl'),'value'=>extension_loaded('openssl')?'Loaded':'Missing','detail'=>'Required for secure crypto/TLS helpers'],
        ['name'=>'mbstring extension','ok'=>extension_loaded('mbstring'),'value'=>extension_loaded('mbstring')?'Loaded':'Missing','detail'=>'Used by application text handling'],
        ['name'=>'Database connection','ok'=>$db instanceof mysqli,'value'=>$db instanceof mysqli ? number_format($connectionLatency,2).' ms' : 'Offline','detail'=>$databaseVersion],
        ['name'=>'Storage writable','ok'=>is_dir($storagePath) && is_writable($storagePath),'value'=>(is_dir($storagePath) && is_writable($storagePath))?'Writable':'Not writable','detail'=>$storagePath],
        ['name'=>'Backup directory','ok'=>ensureBackupDirectory(),'value'=>ensureBackupDirectory()?'Ready':'Unavailable','detail'=>backupDirectory()],
        ['name'=>'Application log','ok'=>is_readable($configuredAppLogPath !== '' ? $configuredAppLogPath : BACKEND_DIRECTORY . '/storage/logs/app.jsonl'),'value'=>is_readable($configuredAppLogPath !== '' ? $configuredAppLogPath : BACKEND_DIRECTORY . '/storage/logs/app.jsonl')?'Readable':'Unavailable','detail'=>'Structured application log'],
        ['name'=>'Mail configuration','ok'=>envFirst(['MAIL_HOST','SMTP_HOST']) !== '','value'=>envFirst(['MAIL_HOST','SMTP_HOST']) !== ''?'Configured':'Not detected','detail'=>'Host presence only; does not prove delivery'],
        ['name'=>'Worker script','ok'=>is_file(BACKEND_DIRECTORY . '/jobs/run_job_worker.php') || is_file(BACKEND_DIRECTORY . '/bin/run_job_worker.php'),'value'=>(is_file(BACKEND_DIRECTORY . '/jobs/run_job_worker.php') || is_file(BACKEND_DIRECTORY . '/bin/run_job_worker.php'))?'Present':'Not found','detail'=>'Does not prove cron/service is active'],
        ['name'=>'Free disk space','ok'=>$diskFree !== false && $diskTotal !== false && $diskTotal > 0 && ($diskFree/$diskTotal) >= 0.15,'value'=>$diskFree !== false ? formatBytes((float)$diskFree) : 'Unknown','detail'=>$diskTotal !== false ? 'of '.formatBytes((float)$diskTotal).' total' : 'Disk metrics unavailable'],
    ];

    // -------------------------------------------------------------------------
    // Data integrity scanner
    // -------------------------------------------------------------------------
    $integrityChecks[] = integrityCheck(
        $db, 'invoice_items_orphan', 'Orphan invoice lines',
        ['erp_invoice_items'=>['invoice_id'],'erp_invoices'=>['id']],
        "SELECT COUNT(*) issue_count FROM erp_invoice_items ii LEFT JOIN erp_invoices i ON i.id=ii.invoice_id WHERE i.id IS NULL",
        'critical'
    );
    $integrityChecks[] = integrityCheck(
        $db, 'invoice_client_orphan', 'Invoices with missing clients',
        ['erp_invoices'=>['client_id'],'clients'=>['id']],
        "SELECT COUNT(*) issue_count FROM erp_invoices i LEFT JOIN clients c ON c.id=i.client_id WHERE i.client_id IS NOT NULL AND i.client_id<>0 AND c.id IS NULL",
        'critical'
    );
    $integrityChecks[] = integrityCheck(
        $db, 'sales_order_items_orphan', 'Orphan sales-order lines',
        ['erp_sales_order_items'=>['sales_order_id'],'erp_sales_orders'=>['id']],
        "SELECT COUNT(*) issue_count FROM erp_sales_order_items x LEFT JOIN erp_sales_orders p ON p.id=x.sales_order_id WHERE p.id IS NULL",
        'high'
    );
    $integrityChecks[] = integrityCheck(
        $db, 'delivery_items_orphan', 'Orphan delivery-note lines',
        ['erp_delivery_note_items'=>['delivery_note_id'],'erp_delivery_notes'=>['id']],
        "SELECT COUNT(*) issue_count FROM erp_delivery_note_items x LEFT JOIN erp_delivery_notes p ON p.id=x.delivery_note_id WHERE p.id IS NULL",
        'high'
    );
    $integrityChecks[] = integrityCheck(
        $db, 'supplier_order_items_orphan', 'Orphan supplier-order lines',
        ['erp_supplier_order_items'=>['supplier_order_id'],'erp_supplier_orders'=>['id']],
        "SELECT COUNT(*) issue_count FROM erp_supplier_order_items x LEFT JOIN erp_supplier_orders p ON p.id=x.supplier_order_id WHERE p.id IS NULL",
        'high'
    );
    $integrityChecks[] = integrityCheck(
        $db, 'supplier_reception_items_orphan', 'Orphan supplier-reception lines',
        ['erp_supplier_reception_items'=>['reception_id'],'erp_supplier_receptions'=>['id']],
        "SELECT COUNT(*) issue_count FROM erp_supplier_reception_items x LEFT JOIN erp_supplier_receptions p ON p.id=x.reception_id WHERE p.id IS NULL",
        'high'
    );
    $integrityChecks[] = integrityCheck(
        $db, 'negative_stock', 'Products with negative stock',
        ['products'=>['stock_quantity']],
        "SELECT COUNT(*) issue_count FROM products WHERE item_type='PRODUCT' AND stock_quantity < 0",
        'high'
    );
    if (dashboardTableExists($db,'erp_invoices') && dashboardColumnExists($db,'erp_invoices','invoice') && dashboardColumnExists($db,'erp_invoices','user_id')) {
        $integrityChecks[] = integrityCheck(
            $db, 'duplicate_invoice_number', 'Duplicate document numbers in a tenant',
            ['erp_invoices'=>['invoice','user_id']],
            "SELECT COUNT(*) issue_count FROM (SELECT user_id,invoice FROM erp_invoices WHERE COALESCE(invoice,'')<>'' GROUP BY user_id,invoice HAVING COUNT(*)>1) q",
            'critical'
        );
    }

    // -------------------------------------------------------------------------
    // Tenant / company inspector
    // -------------------------------------------------------------------------
    if (dashboardTableExists($db, 'companies')) {
        $companiesList = dashboardRows($db, "
            SELECT id,owner_user_id,organization_name,fiscal_id,status
            FROM companies
            ORDER BY organization_name,id
            LIMIT 1000
        ");

        $requestedCompanyId = (int)($_POST['company_id'] ?? $_GET['company_id'] ?? 0);
        if ($requestedCompanyId > 0) {
            $statement = $db->prepare("SELECT id,owner_user_id,organization_name,fiscal_id,status,created_at FROM companies WHERE id=? LIMIT 1");
            $statement->bind_param('i', $requestedCompanyId);
            $statement->execute();
            $tenantInspection = $statement->get_result()->fetch_assoc() ?: null;
            $statement->close();

            if ($tenantInspection) {
                $companyId = (int)$tenantInspection['id'];
                $ownerId = (int)($tenantInspection['owner_user_id'] ?? 0);

                if (dashboardTableExists($db,'company_memberships')) {
                    $tenantInspection['members'] = dashboardRows($db, "
                        SELECT cm.user_id,cm.role,cm.status,cm.is_owner,u.email,u.display_name
                        FROM company_memberships cm
                        LEFT JOIN users u ON u.id=cm.user_id
                        WHERE cm.company_id=" . $companyId . "
                        ORDER BY cm.is_owner DESC,u.email
                    ");
                } else {
                    $tenantInspection['members'] = [];
                }

                $businessTables = [
                    'clients','products','suppliers','erp_invoices','erp_sales_orders',
                    'erp_delivery_notes','expense_notes','erp_supplier_orders',
                    'erp_supplier_receptions','product_stock_movements'
                ];

                foreach ($businessTables as $businessTable) {
                    if (!dashboardTableExists($db,$businessTable) || !dashboardColumnExists($db,$businessTable,'user_id')) continue;

                    $statement = $db->prepare("SELECT COUNT(*) total FROM `{$businessTable}` WHERE user_id=?");
                    $statement->bind_param('i',$companyId);
                    $statement->execute();
                    $tenantCounts[$businessTable] = (int)($statement->get_result()->fetch_assoc()['total'] ?? 0);
                    $statement->close();

                    if ($ownerId > 0 && $ownerId !== $companyId) {
                        $statement = $db->prepare("SELECT COUNT(*) total FROM `{$businessTable}` WHERE user_id=?");
                        $statement->bind_param('i',$ownerId);
                        $statement->execute();
                        $tenantMismatchCounts[$businessTable] = (int)($statement->get_result()->fetch_assoc()['total'] ?? 0);
                        $statement->close();
                    }
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // Security center
    // -------------------------------------------------------------------------
    if (dashboardTableExists($db,'users')) {
        $approvedAtSelect = dashboardColumnExists($db, 'users', 'approved_at')
            ? 'approved_at'
            : 'NULL AS approved_at';
        $securityUsers = dashboardRows($db, "
            SELECT id,email,display_name,organization_name,role,account_status,email_verified_at,google2fa_enabled,default_company_id,created_at,{$approvedAtSelect}
            FROM users
            ORDER BY (account_status='PENDING') DESC,id DESC
            LIMIT 250
        ");
    }
    if (dashboardTableExists($db, 'erp_platform_settings')) {
        $userApprovalPolicyAvailable = true;
        $policyRow = dashboardRow($db, "SELECT setting_value FROM erp_platform_settings WHERE setting_key='new_user_approval_required' LIMIT 1");
        $newUserApprovalRequired = !isset($policyRow['setting_value'])
            || in_array(strtolower(trim((string)$policyRow['setting_value'])), ['1', 'true', 'yes', 'on'], true);
    }

    if (dashboardTableExists($db,'auth_refresh_tokens')
        && dashboardColumnExists($db,'auth_refresh_tokens','user_id')
        && dashboardColumnExists($db,'auth_refresh_tokens','expires_at')) {
        $revokedExpr = dashboardColumnExists($db,'auth_refresh_tokens','revoked_at')
            ? "SUM(revoked_at IS NULL AND expires_at>NOW())"
            : "SUM(expires_at>NOW())";
        $securitySessions = dashboardRows($db, "
            SELECT user_id,
                   {$revokedExpr} active_sessions,
                   COUNT(*) total_tokens,
                   MAX(expires_at) latest_expiry
            FROM auth_refresh_tokens
            GROUP BY user_id
            ORDER BY active_sessions DESC,total_tokens DESC
            LIMIT 250
        ");
    }

    if (dashboardTableExists($db,'company_invitations')) {
        $securityInvitations = dashboardRows($db, "
            SELECT id,company_id,email,role,status,expires_at,created_at
            FROM company_invitations
            WHERE status='PENDING' OR expires_at > NOW() - INTERVAL 7 DAY
            ORDER BY created_at DESC
            LIMIT 100
        ");
    }

    // -------------------------------------------------------------------------
    // Audit explorer
    // -------------------------------------------------------------------------
    if (dashboardTableExists($db,'app_audit_log')) {
        $where = ['1=1'];
        $types = '';
        $args = [];

        if ($auditFilters['action'] !== '') {
            $where[] = 'action LIKE ?';
            $types .= 's';
            $args[] = '%' . $auditFilters['action'] . '%';
        }
        if ($auditFilters['entity_type'] !== '') {
            $where[] = 'entity_type LIKE ?';
            $types .= 's';
            $args[] = '%' . $auditFilters['entity_type'] . '%';
        }
        if ($auditFilters['actor_id'] !== '' && ctype_digit($auditFilters['actor_id'])) {
            $where[] = 'actor_id = ?';
            $types .= 'i';
            $args[] = (int)$auditFilters['actor_id'];
        }
        if ($auditFilters['from'] !== '') {
            $where[] = 'created_at >= ?';
            $types .= 's';
            $args[] = $auditFilters['from'] . ' 00:00:00';
        }
        if ($auditFilters['to'] !== '') {
            $where[] = 'created_at <= ?';
            $types .= 's';
            $args[] = $auditFilters['to'] . ' 23:59:59';
        }

        $whereSql = implode(' AND ', $where);

        $countStatement = $db->prepare("SELECT COUNT(*) total FROM app_audit_log WHERE {$whereSql}");
        if ($types !== '') $countStatement->bind_param($types, ...$args);
        $countStatement->execute();
        $auditExplorerTotal = (int)($countStatement->get_result()->fetch_assoc()['total'] ?? 0);
        $countStatement->close();

        $offset = ($auditPage - 1) * $auditPageSize;
        $query = "SELECT action,entity_type,entity_id,actor_id,created_at FROM app_audit_log WHERE {$whereSql} ORDER BY created_at DESC LIMIT ? OFFSET ?";
        $statement = $db->prepare($query);
        $queryTypes = $types . 'ii';
        $queryArgs = array_merge($args, [$auditPageSize, $offset]);
        $statement->bind_param($queryTypes, ...$queryArgs);
        $statement->execute();
        $auditExplorerRows = $statement->get_result()->fetch_all(MYSQLI_ASSOC);
        $statement->close();
    }
}

if (!($db instanceof mysqli)) {
    $applicationChecks[] = [
        'label' => 'Database-dependent detection',
        'status' => 'ERROR',
        'detail' => 'The database is offline, so endpoint/schema compatibility checks could not run.',
        'hint' => 'Restore the database connection, then refresh Error Center.',
    ];
}
$applicationChecks[] = [
    'label' => 'Structured application log',
    'status' => $logStats['readable'] ? 'OK' : 'ERROR',
    'detail' => $logStats['readable']
        ? 'Readable; scanned ' . formatBytes((float)$logStats['scanned_bytes']) . ' of recent events.'
        : 'The configured application log is unavailable or unreadable.',
    'hint' => $logStats['readable']
        ? 'No action required.'
        : 'Check APP_LOG_PATH and storage/logs permissions.',
];
$applicationIssueCount = count(array_filter(
    $applicationChecks,
    static fn(array $check): bool => in_array($check['status'], ['ISSUE', 'ERROR'], true)
));

$migrationFiles = glob(BACKEND_DIRECTORY . '/sql/*.sql') ?: [];
sort($migrationFiles, SORT_STRING);
$migrationInfo = [];
foreach ($migrationFiles as $file) {
    $version = basename($file);
    $checksum = (string)hash_file('sha256', $file);
    $applied = $appliedMigrations[$version] ?? null;
    $storedChecksum = trim((string)($applied['checksum'] ?? ''));
    $modified = $applied !== null && $storedChecksum !== '' && !hash_equals($storedChecksum, $checksum);
    $migrationInfo[] = [
        'file' => $file,
        'version' => $version,
        'checksum' => $checksum,
        'applied' => $applied !== null,
        'modified' => $modified,
        'applied_at' => $applied['applied_at'] ?? null,
        'execution_ms' => $applied['execution_ms'] ?? null,
        'stored_checksum' => $storedChecksum,
    ];
}
$pendingMigrations = array_values(array_filter($migrationInfo, static fn(array $m): bool => !$m['applied']));
$modifiedMigrations = array_values(array_filter($migrationInfo, static fn(array $m): bool => $m['modified']));

$authenticationByDay = [];
foreach ($authenticationActivity as $row) {
    $authenticationByDay[(string)($row['activity_day'] ?? '')] = $row;
}
$authenticationChart = [];
for ($daysAgo = 6; $daysAgo >= 0; $daysAgo--) {
    $date = (new DateTimeImmutable('today'))->modify("-{$daysAgo} days");
    $key = $date->format('Y-m-d');
    $row = $authenticationByDay[$key] ?? [];
    $authenticationChart[] = [
        'date' => $key,
        'label' => $date->format('D'),
        'succeeded' => (int)($row['succeeded'] ?? 0),
        'failed' => (int)($row['failed'] ?? 0),
    ];
}
$authenticationMaximum = max(1, ...array_map(
    static fn(array $row): int => max($row['succeeded'], $row['failed']),
    $authenticationChart
));
$chartPoints = static function (array $rows, string $key, int $maximum): string {
    $points = [];
    $count = count($rows);
    foreach ($rows as $index => $row) {
        $x = $count > 1 ? 22 + ($index * (576 / ($count - 1))) : 310;
        $y = 158 - (((int)$row[$key] / max(1, $maximum)) * 126);
        $points[] = number_format($x, 1, '.', '') . ',' . number_format($y, 1, '.', '');
    }
    return implode(' ', $points);
};
$authenticationSuccessPoints = $chartPoints($authenticationChart, 'succeeded', $authenticationMaximum);
$authenticationFailedPoints = $chartPoints($authenticationChart, 'failed', $authenticationMaximum);

$registrationsByDay = [];
foreach ($registrationActivity as $row) {
    $registrationsByDay[(string)($row['activity_day'] ?? '')] = (int)($row['registered'] ?? 0);
}
$registrationChart = [];
for ($daysAgo = 13; $daysAgo >= 0; $daysAgo--) {
    $date = (new DateTimeImmutable('today'))->modify("-{$daysAgo} days");
    $key = $date->format('Y-m-d');
    $registrationChart[] = [
        'date' => $key,
        'label' => $date->format('j'),
        'registered' => $registrationsByDay[$key] ?? 0,
    ];
}
$registrationMaximum = max(1, ...array_column($registrationChart, 'registered'));
$registrationsInPeriod = array_sum(array_column($registrationChart, 'registered'));

$accountTotal = $operations['total_users'];
$activeEnd = $accountTotal > 0 ? ($operations['active_users'] * 360 / $accountTotal) : 0;
$pendingEnd = $accountTotal > 0 ? (($operations['active_users'] + $operations['pending_users']) * 360 / $accountTotal) : 0;
$accountStatusBackground = $accountTotal > 0
    ? sprintf('conic-gradient(var(--green) 0 %.2fdeg,var(--amber) %.2fdeg %.2fdeg,var(--red) %.2fdeg 360deg)', $activeEnd, $activeEnd, $pendingEnd, $pendingEnd)
    : 'var(--line)';
$verifiedPercent = $accountTotal > 0 ? round($operations['verified_users'] * 100 / $accountTotal, 1) : 0.0;
$twoFactorPercent = $accountTotal > 0 ? round($operations['twofa_users'] * 100 / $accountTotal, 1) : 0.0;
$csrf = h((string)$_SESSION['super_admin_csrf']);
?>
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex,nofollow">
<title>El Fatoura — Super Admin</title>
<style nonce="<?= h($cspNonce) ?>">
:root{color-scheme:dark;--bg:#07111f;--sidebar:#0a1729;--panel:#0f2036;--panel2:#132841;--line:#263e5f;--text:#edf5ff;--muted:#94a9c4;--blue:#3b82f6;--green:#34d399;--amber:#fbbf24;--red:#fb7185;--shadow:0 24px 60px rgba(0,0,0,.22)}*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;background:radial-gradient(circle at 80% 0,rgba(59,130,246,.12),transparent 28%),var(--bg);color:var(--text);font-family:Inter,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}code{font-family:ui-monospace,SFMono-Regular,Menlo,monospace}.layout{display:grid;grid-template-columns:250px minmax(0,1fr);min-height:100vh}.sidebar{position:sticky;top:0;height:100vh;padding:24px 17px;border-right:1px solid var(--line);background:rgba(10,23,41,.95)}.brand{display:flex;align-items:center;gap:12px;padding:0 8px 25px}.logo{display:grid;place-items:center;width:43px;height:43px;border-radius:14px;background:linear-gradient(135deg,#2563eb,#60a5fa);font-weight:950}.brand strong{display:block}.brand small{color:var(--muted)}.nav{display:grid;gap:7px}.nav button{width:100%;display:flex;align-items:center;gap:10px;padding:12px;border:1px solid transparent;border-radius:12px;background:transparent;color:var(--muted);font:inherit;font-weight:800;text-align:left;cursor:pointer}.nav button:hover,.nav button.active{border-color:var(--line);background:var(--panel);color:var(--text)}.sideFoot{position:absolute;left:17px;right:17px;bottom:20px}.logout{width:100%;padding:11px;border:1px solid var(--line);border-radius:12px;background:transparent;color:var(--muted);font-weight:800;cursor:pointer}.main{min-width:0;padding:27px clamp(18px,3vw,42px) 60px}.topbar{display:flex;align-items:center;justify-content:space-between;gap:20px;margin-bottom:25px}.eyebrow{margin:0 0 5px;color:#75a9ff;font-size:11px;font-weight:900;letter-spacing:.14em;text-transform:uppercase}h1{margin:0;font-size:clamp(25px,3vw,34px)}.topMeta{display:flex;gap:9px;flex-wrap:wrap}.pill{padding:8px 11px;border:1px solid var(--line);border-radius:999px;background:var(--panel);color:var(--muted);font-size:12px;font-weight:800}.pill.good{color:#a7f3d0;border-color:rgba(52,211,153,.35)}.pill.bad{color:#fecdd3;border-color:rgba(251,113,133,.35)}.pill.warn{color:#fde68a;border-color:rgba(251,191,36,.35)}.section{display:none}.section.active{display:block}.metrics{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:14px}.card{padding:20px;border:1px solid var(--line);border-radius:19px;background:linear-gradient(180deg,rgba(255,255,255,.018),transparent),var(--panel);box-shadow:var(--shadow)}.metric span{color:var(--muted);font-size:12px;font-weight:800}.metric strong{display:block;margin-top:9px;font-size:25px}.metric small{display:block;margin-top:6px;color:var(--muted);font-size:10px}.metric.goodMetric strong{color:#a7f3d0}.metric.badMetric strong{color:#fecdd3}.grid2{display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-top:16px}.cardHead{display:flex;align-items:flex-start;justify-content:space-between;gap:20px;margin-bottom:16px}.cardHead h2{margin:0;font-size:17px}.cardHead p{margin:5px 0 0;color:var(--muted);font-size:12px}.notice{padding:13px 15px;margin-bottom:14px;border:1px solid rgba(251,191,36,.34);border-radius:13px;background:rgba(251,191,36,.08);color:#fde68a;font-size:13px;line-height:1.55}.notice.error{border-color:rgba(251,113,133,.35);background:rgba(251,113,133,.09);color:#fecdd3}.notice.success{border-color:rgba(52,211,153,.35);background:rgba(52,211,153,.08);color:#a7f3d0}.formGrid{display:grid;gap:13px}.field{display:grid;gap:7px}.field span{color:var(--muted);font-size:12px;font-weight:850}.input,.textarea{width:100%;border:1px solid var(--line);border-radius:13px;background:#08172a;color:var(--text);font:inherit}.input{min-height:44px;padding:0 13px}.textarea{min-height:300px;padding:15px;resize:vertical;font:13px/1.6 ui-monospace,SFMono-Regular,Menlo,monospace;tab-size:2}.confirm{display:grid;grid-template-columns:auto minmax(180px,330px) 1fr;align-items:center;gap:12px;padding:13px;border:1px solid var(--line);border-radius:13px;background:rgba(7,17,31,.55)}.confirm label{display:flex;gap:8px;color:#fde68a;font-size:12px;font-weight:800}.button{display:inline-flex;align-items:center;justify-content:center;min-height:43px;padding:0 15px;border:0;border-radius:12px;background:linear-gradient(135deg,#2563eb,#4f8cff);color:white;font:inherit;font-weight:900;cursor:pointer}.button.secondary{border:1px solid var(--line);background:var(--panel2);color:var(--text)}.button.danger{border:1px solid rgba(251,113,133,.4);background:rgba(251,113,133,.1);color:#fecdd3}.button.small{min-height:34px;padding:0 11px;font-size:12px}.button:disabled{opacity:.45;cursor:not-allowed}.tableWrap{overflow:auto;border:1px solid var(--line);border-radius:13px}table{width:100%;border-collapse:collapse;white-space:nowrap}th,td{padding:10px 12px;border-bottom:1px solid var(--line);text-align:left;font-size:12px}th{background:#0b1a2e;color:var(--muted);font-size:10px;letter-spacing:.08em;text-transform:uppercase}tr:last-child td{border-bottom:0}.status{padding:5px 8px;border-radius:999px;font-size:10px;font-weight:900}.status.applied{color:#a7f3d0;background:rgba(52,211,153,.1)}.status.pending{color:#fde68a;background:rgba(251,191,36,.1)}.status.modified{color:#fecdd3;background:rgba(251,113,133,.1)}.result{margin-top:15px}.result h3{font-size:14px}.empty{padding:25px;color:var(--muted);text-align:center}.mobileNav{display:none;margin-bottom:15px}.auditHelp{color:var(--muted);font-size:12px;line-height:1.6}.schemaToolbar{display:flex;gap:10px;align-items:center;flex-wrap:wrap;margin-bottom:14px}.schemaSearch{flex:1;min-width:220px}.schemaCanvasWrap{position:relative;overflow:auto;max-height:72vh;border:1px solid var(--line);border-radius:16px;background:radial-gradient(circle at 20% 10%,rgba(59,130,246,.08),transparent 26%),#081422;padding:18px}.schemaCanvas{position:relative;min-width:980px}.schemaLinks{position:absolute;inset:0;width:100%;height:100%;pointer-events:none;overflow:visible;z-index:1}.schemaGrid{position:relative;z-index:2;display:grid;grid-template-columns:repeat(4,minmax(240px,1fr));gap:18px}.schemaTable{border:1px solid var(--line);border-radius:15px;background:rgba(15,32,54,.97);box-shadow:0 15px 34px rgba(0,0,0,.18);overflow:hidden}.schemaTable.hidden{display:none}.schemaTableHead{display:flex;align-items:flex-start;justify-content:space-between;gap:10px;padding:13px 14px;border-bottom:1px solid var(--line);background:#0b1a2e}.schemaTableHead strong{font-size:13px}.schemaTableMeta{display:flex;gap:6px;flex-wrap:wrap;margin-top:5px;color:var(--muted);font-size:9px}.schemaColumns{max-height:260px;overflow:auto}.schemaColumn{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:10px;padding:8px 12px;border-bottom:1px solid rgba(38,62,95,.65);font-size:11px}.schemaColumn:last-child{border-bottom:0}.schemaColumnName{min-width:0;overflow:hidden;text-overflow:ellipsis}.schemaColumnType{color:var(--muted);font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:9px}.schemaBadges{display:flex;gap:4px}.schemaBadge{padding:2px 5px;border-radius:999px;font-size:8px;font-weight:900}.schemaBadge.pk{color:#fde68a;background:rgba(251,191,36,.12)}.schemaBadge.fk{color:#bfdbfe;background:rgba(59,130,246,.12)}.schemaTableFoot{display:flex;gap:7px;padding:10px;border-top:1px solid var(--line)}.schemaRelationPath{fill:none;stroke:rgba(96,165,250,.38);stroke-width:1.5}.schemaRelationPath.highlight{stroke:#60a5fa;stroke-width:2.5}.schemaRelationDot{fill:#60a5fa}.schemaRelationList{margin-top:16px}.schemaLegend{display:flex;gap:14px;flex-wrap:wrap;color:var(--muted);font-size:11px}.schemaLegend span{display:flex;align-items:center;gap:6px}.legendLine{display:inline-block;width:22px;height:2px;background:#60a5fa}.schemaStats{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:10px;margin-bottom:14px}.schemaStats .card{padding:14px}.schemaStats strong{display:block;font-size:20px;margin-top:5px}.schemaStats span{color:var(--muted);font-size:10px;font-weight:800}.migrationActions{display:flex;gap:8px;align-items:center;flex-wrap:wrap}.migrationConfirm{display:grid;grid-template-columns:minmax(220px,360px) auto;gap:12px;align-items:end;margin:0 0 16px;padding:15px;border:1px solid var(--line);border-radius:14px;background:rgba(7,17,31,.5)}.migrationConfirm .hint{grid-column:1/-1;margin:0;color:var(--muted);font-size:12px;line-height:1.5}.checksum{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;color:var(--muted)}@media(max-width:1300px){.schemaGrid{grid-template-columns:repeat(3,minmax(240px,1fr))}}@media(max-width:1050px){.layout{grid-template-columns:1fr}.sidebar{display:none}.mobileNav{display:flex;gap:7px;overflow:auto}.mobileNav button{white-space:nowrap;padding:9px 12px;border:1px solid var(--line);border-radius:10px;background:var(--panel);color:var(--muted)}.metrics{grid-template-columns:1fr 1fr}.schemaGrid{grid-template-columns:repeat(2,minmax(240px,1fr))}.schemaStats{grid-template-columns:repeat(3,1fr)}}@media(max-width:680px){.main{padding:18px 12px 45px}.topbar{align-items:flex-start;flex-direction:column}.metrics,.grid2{grid-template-columns:1fr}.confirm,.migrationConfirm{grid-template-columns:1fr}.textarea{min-height:240px}.schemaGrid{grid-template-columns:1fr}.schemaStats{grid-template-columns:1fr 1fr}.schemaCanvas{min-width:300px}}

.opsGrid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:14px}.healthItem{display:flex;align-items:flex-start;justify-content:space-between;gap:14px;padding:13px 0;border-bottom:1px solid var(--line)}.healthItem:last-child{border-bottom:0}.healthName{font-weight:850;font-size:12px}.healthDetail{margin-top:4px;color:var(--muted);font-size:10px;line-height:1.45}.dot{width:9px;height:9px;border-radius:50%;display:inline-block;margin-right:6px}.dot.good{background:var(--green)}.dot.bad{background:var(--red)}.dot.warn{background:var(--amber)}.integrityGrid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}.integrityCard{padding:15px;border:1px solid var(--line);border-radius:14px;background:#0b1a2e}.integrityCard.ok{border-color:rgba(52,211,153,.28)}.integrityCard.issues{border-color:rgba(251,113,133,.35)}.integrityCard.skipped{border-color:rgba(251,191,36,.25)}.integrityTop{display:flex;justify-content:space-between;gap:12px}.integrityTop strong{font-size:13px}.integrityCard p{margin:8px 0 0;color:var(--muted);font-size:11px}.tenantGrid{display:grid;grid-template-columns:340px minmax(0,1fr);gap:16px}.scrollList{max-height:68vh;overflow:auto}.tenantButton{display:block;width:100%;padding:12px;border:0;border-bottom:1px solid var(--line);background:transparent;color:var(--text);text-align:left;cursor:pointer}.tenantButton:hover{background:rgba(59,130,246,.07)}.tenantButton strong{display:block}.tenantButton small{color:var(--muted)}.countGrid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px}.countBox{padding:13px;border:1px solid var(--line);border-radius:12px;background:#0b1a2e}.countBox span{display:block;color:var(--muted);font-size:10px}.countBox strong{display:block;margin-top:5px;font-size:18px}.backupActions{display:flex;gap:8px;flex-wrap:wrap}.securityGrid{display:grid;grid-template-columns:1fr 1fr;gap:16px}.auditFilters{display:grid;grid-template-columns:repeat(5,minmax(140px,1fr)) auto;gap:10px;align-items:end}.paginationBar{display:flex;justify-content:space-between;gap:12px;align-items:center;margin-top:14px}.tiny{font-size:10px;color:var(--muted)}.mono{font-family:ui-monospace,SFMono-Regular,Menlo,monospace}.dangerText{color:#fecdd3}.warnText{color:#fde68a}.goodText{color:#a7f3d0}@media(max-width:1100px){.opsGrid{grid-template-columns:1fr 1fr}.tenantGrid,.securityGrid{grid-template-columns:1fr}.auditFilters{grid-template-columns:1fr 1fr}.countGrid{grid-template-columns:1fr 1fr}}@media(max-width:680px){.opsGrid,.integrityGrid,.auditFilters,.countGrid{grid-template-columns:1fr}}

</style>
<style nonce="<?= h($cspNonce) ?>">
.sidebar{display:flex;flex-direction:column;overflow:hidden}.nav{min-height:0;overflow:auto;padding-bottom:10px}.sideFoot{position:static;margin-top:auto;padding-top:12px}.section[data-section="errors"] table{min-width:1050px;white-space:normal}.section[data-section="errors"] th{white-space:nowrap}.section[data-section="errors"] td{line-height:1.45;max-width:360px;overflow-wrap:anywhere}.section[data-section="errors"] .mono{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:10px}.section[data-section="errors"] .tiny{color:var(--muted);font-size:10px}
.policyOptions{display:grid;grid-template-columns:1fr 1fr;gap:12px}.approvalPolicyForm{margin:0}.policyOption{width:100%;height:100%;padding:16px;border:1px solid var(--line);border-radius:14px;background:#08172a;color:var(--text);text-align:left;cursor:pointer}.policyOption:hover{border-color:var(--blue)}.policyOption.selected{border-color:var(--green);box-shadow:inset 0 0 0 1px var(--green);background:rgba(52,211,153,.07)}.policyOption strong,.policyOption span{display:block}.policyOption span{margin-top:5px;color:var(--muted);font-size:11px;line-height:1.5}@media(max-width:680px){.policyOptions{grid-template-columns:1fr}}
.logo{font-size:0;background-image:url('/el-fatoura-icon.svg');background-position:center;background-size:cover;background-repeat:no-repeat}
.overviewCharts{display:grid;grid-template-columns:minmax(0,1.45fr) minmax(320px,.75fr);gap:16px;margin-top:16px}.chartLegend{display:flex;align-items:center;gap:16px;flex-wrap:wrap;color:var(--muted);font-size:11px}.legendKey{display:inline-flex;align-items:center;gap:7px}.legendKey::before{content:"";width:18px;height:3px;border-radius:999px;background:var(--blue)}.legendKey.failed::before{background:var(--red)}.lineChart{position:relative;height:205px;border:1px solid var(--line);border-radius:14px;background:repeating-linear-gradient(to bottom,transparent 0,transparent 40px,rgba(148,169,196,.09) 41px);overflow:hidden}.lineChart svg{display:block;width:100%;height:175px}.chartLine{fill:none;stroke-width:4;stroke-linecap:round;stroke-linejoin:round;vector-effect:non-scaling-stroke}.chartLine.success{stroke:var(--blue)}.chartLine.failed{stroke:var(--red)}.chartArea{fill:rgba(59,130,246,.08)}.chartDays{display:grid;grid-template-columns:repeat(7,1fr);padding:0 13px;color:var(--muted);font-size:9px;text-align:center}.statusSummary{display:grid;grid-template-columns:150px minmax(0,1fr);align-items:center;gap:24px}.statusDonut{position:relative;width:150px;aspect-ratio:1;border-radius:50%;box-shadow:inset 0 0 0 1px rgba(255,255,255,.04)}.statusDonut::after{content:"";position:absolute;inset:24px;border-radius:50%;background:var(--panel);box-shadow:0 0 0 1px var(--line)}.statusDonutValue{position:absolute;z-index:1;inset:0;display:grid;place-content:center;text-align:center}.statusDonutValue strong{font-size:27px}.statusDonutValue span{color:var(--muted);font-size:10px}.statusList{display:grid;gap:12px}.statusRow{display:grid;grid-template-columns:auto 1fr auto;align-items:center;gap:9px;font-size:12px}.statusRow i{width:9px;height:9px;border-radius:50%}.statusRow span{color:var(--muted)}.statusRow strong{font-size:14px}.statusRow.active i{background:var(--green)}.statusRow.pending i{background:var(--amber)}.statusRow.archived i{background:var(--red)}.registrationChart{height:168px;display:grid;grid-template-columns:repeat(14,minmax(8px,1fr));align-items:end;gap:7px;padding:10px 2px 0}.registrationBar{position:relative;height:max(3px,var(--bar-height));min-height:3px;border-radius:7px 7px 2px 2px;background:linear-gradient(180deg,#60a5fa,#2563eb);transition:filter .15s ease}.registrationBar:hover{filter:brightness(1.25)}.registrationBar::before{content:attr(data-value);position:absolute;left:50%;bottom:calc(100% + 5px);transform:translateX(-50%);color:var(--text);font-size:9px;font-weight:900;opacity:0}.registrationBar:hover::before{opacity:1}.registrationLabels{display:grid;grid-template-columns:repeat(14,minmax(8px,1fr));gap:7px;margin-top:8px;color:var(--muted);font-size:8px;text-align:center}.quickAction{display:flex;align-items:center;justify-content:space-between;gap:16px;margin-top:14px;padding:13px 14px;border:1px solid rgba(251,191,36,.24);border-radius:13px;background:rgba(251,191,36,.06)}.quickAction p{margin:0;color:var(--muted);font-size:11px;line-height:1.5}.quickAction strong{display:block;color:var(--text);font-size:12px}.coverageList{display:grid;gap:14px}.coverageTop{display:flex;justify-content:space-between;gap:14px;margin-bottom:6px;color:var(--muted);font-size:11px}.coverageTop strong{color:var(--text)}.progressTrack{height:7px;border-radius:999px;background:#08172a;overflow:hidden}.progressFill{height:100%;border-radius:inherit;background:linear-gradient(90deg,#2563eb,#60a5fa)}.progressFill.secure{background:linear-gradient(90deg,#059669,#34d399)}@media(max-width:1100px){.overviewCharts{grid-template-columns:1fr}}@media(max-width:680px){.statusSummary{grid-template-columns:1fr;justify-items:center}.statusList{width:100%}.registrationChart,.registrationLabels{gap:3px}.chartLegend{gap:10px}}
</style>
</head>
<body>
<div class="layout">
<aside class="sidebar"><div class="brand"><div class="logo">EF</div><div><strong>El Fatoura</strong><small>Super Admin</small></div></div><nav class="nav"><button type="button" data-tab="overview">◫ Operations</button><button type="button" data-tab="health">♡ Health</button><button type="button" data-tab="errors">⚠ Error Center<?= ($logStats['errors_24h'] + $applicationIssueCount) > 0 ? ' (' . h($logStats['errors_24h'] + $applicationIssueCount) . ')' : '' ?></button><button type="button" data-tab="tenants">▦ Tenants</button><button type="button" data-tab="integrity">✓ Integrity</button><button type="button" data-tab="backups">⇩ Backups</button><button type="button" data-tab="security">⌾ Security</button><button type="button" data-tab="audit">◷ Audit Explorer</button><button type="button" data-tab="sql">⌘ SQL Console</button><button type="button" data-tab="migrations">⇧ Migrations</button><button type="button" data-tab="schema">⌘ Schema Map</button><button type="button" data-tab="storage">▤ Database</button></nav><form class="sideFoot" method="post"><input type="hidden" name="csrf_token" value="<?= $csrf ?>"><input type="hidden" name="action" value="logout"><button class="logout" type="submit">Sign out</button></form></aside>
<main class="main">
<div class="mobileNav"><button type="button" data-tab="overview">Operations</button><button type="button" data-tab="health">Health</button><button type="button" data-tab="errors">Errors <?= h($logStats['errors_24h'] + $applicationIssueCount) ?></button><button type="button" data-tab="tenants">Tenants</button><button type="button" data-tab="integrity">Integrity</button><button type="button" data-tab="backups">Backups</button><button type="button" data-tab="security">Security</button><button type="button" data-tab="audit">Audit</button><button type="button" data-tab="sql">SQL Console</button><button type="button" data-tab="migrations">Migrations</button><button type="button" data-tab="schema">Schema Map</button><button type="button" data-tab="storage">Database</button></div>
<header class="topbar"><div><p class="eyebrow">Restricted owner workspace</p><h1>Server Control Center</h1></div><div class="topMeta"><span class="pill <?= $db instanceof mysqli ? 'good' : 'bad' ?>"><?= $db instanceof mysqli ? '● Database connected' : '● Database offline' ?></span><span class="pill <?= ($logStats['errors_24h'] + $applicationIssueCount) > 0 ? 'bad' : 'good' ?>"><?= h($logStats['errors_24h'] + $applicationIssueCount) ?> detected error<?= ($logStats['errors_24h'] + $applicationIssueCount) === 1 ? '' : 's' ?></span><span class="pill <?= $sqlEnabled ? 'good' : 'bad' ?>">SQL <?= $sqlEnabled ? 'enabled' : 'disabled' ?></span><span class="pill <?= count($pendingMigrations) > 0 ? 'warn' : 'good' ?>"><?= h(count($pendingMigrations)) ?> pending migration<?= count($pendingMigrations) === 1 ? '' : 's' ?></span></div></header>

<?php if ($operationError !== ''): ?><div class="notice error"><?= h($operationError) ?></div><?php elseif ($operationMessage !== ''): ?><div class="notice success"><?= h($operationMessage) ?></div><?php endif; ?>
<?php if ($modifiedMigrations): ?><div class="notice error"><?= h(count($modifiedMigrations)) ?> applied migration file(s) have changed on disk. Execution is blocked for those versions until reviewed.</div><?php endif; ?>

<section class="section" data-section="overview">
<div class="metrics">
<article class="card metric goodMetric"><span>Emails sent</span><strong><?= h(number_format($operations['email_sent_24h'])) ?></strong><small>Last 24 hours · <?= h(number_format($operations['email_sent_7d'])) ?> in 7 days</small></article>
<article class="card metric <?= $operations['email_failed_24h'] > 0 ? 'badMetric' : '' ?>"><span>Email failures</span><strong><?= h(number_format($operations['email_failed_24h'])) ?></strong><small>Last 24 hours</small></article>
<article class="card metric goodMetric"><span>Successful logins</span><strong><?= h(number_format($operations['login_success_24h'])) ?></strong><small>Last 24 hours</small></article>
<article class="card metric <?= $operations['login_failed_24h'] > 0 ? 'badMetric' : '' ?>"><span>Failed logins</span><strong><?= h(number_format($operations['login_failed_24h'])) ?></strong><small><?= h(number_format($operations['login_2fa_failed_24h'])) ?> failed at 2FA · 24h</small></article>
<article class="card metric"><span>Active sessions</span><strong><?= h(number_format($operations['active_sessions'])) ?></strong><small>Unrevoked, unexpired refresh tokens</small></article>
<article class="card metric"><span>Total users</span><strong><?= h(number_format($operations['total_users'])) ?></strong><small><?= h(number_format($operations['active_users'])) ?> active accounts</small></article>
<article class="card metric <?= $operations['pending_users'] > 0 ? 'badMetric' : 'goodMetric' ?>"><span>Pending approvals</span><strong><?= h(number_format($operations['pending_users'])) ?></strong><small>Blocked until accepted in Security</small></article>
<article class="card metric <?= $logStats['errors_24h'] > 0 ? 'badMetric' : '' ?>"><span>Application errors</span><strong><?= h(number_format($logStats['errors_24h'])) ?></strong><small><?= h(number_format($logStats['critical_24h'])) ?> critical · application log · 24h</small></article>
</div>
<div class="overviewCharts">
<article class="card">
<div class="cardHead"><div><h2>Authentication trend</h2><p>Successful and rejected sign-ins during the last 7 days</p></div><div class="chartLegend"><span class="legendKey">Successful</span><span class="legendKey failed">Rejected</span></div></div>
<div class="lineChart" role="img" aria-label="Seven-day authentication activity chart">
<svg viewBox="0 0 620 175" preserveAspectRatio="none" aria-hidden="true"><polyline class="chartLine success" points="<?= h($authenticationSuccessPoints) ?>"></polyline><polyline class="chartLine failed" points="<?= h($authenticationFailedPoints) ?>"></polyline></svg>
<div class="chartDays"><?php foreach ($authenticationChart as $day): ?><span title="<?= h($day['date']) ?> · <?= h($day['succeeded']) ?> successful · <?= h($day['failed']) ?> rejected"><?= h($day['label']) ?></span><?php endforeach; ?></div>
</div>
</article>
<article class="card">
<div class="cardHead"><div><h2>Account status</h2><p>Current access distribution</p></div><span class="pill"><?= h(number_format($operations['audit_events_24h'])) ?> events · 24h</span></div>
<div class="statusSummary">
<div class="statusDonut" style="background:<?= h($accountStatusBackground) ?>" role="img" aria-label="<?= h($operations['active_users']) ?> active, <?= h($operations['pending_users']) ?> pending, <?= h($operations['archived_users']) ?> archived users"><div class="statusDonutValue"><strong><?= h(number_format($accountTotal)) ?></strong><span>Total users</span></div></div>
<div class="statusList"><div class="statusRow active"><i></i><span>Active</span><strong><?= h(number_format($operations['active_users'])) ?></strong></div><div class="statusRow pending"><i></i><span>Pending</span><strong><?= h(number_format($operations['pending_users'])) ?></strong></div><div class="statusRow archived"><i></i><span>Archived</span><strong><?= h(number_format($operations['archived_users'])) ?></strong></div></div>
</div>
<?php if ($operations['pending_users'] > 0): ?><div class="quickAction"><p><strong><?= h(number_format($operations['pending_users'])) ?> account<?= $operations['pending_users'] === 1 ? '' : 's' ?> need approval</strong>Pending accounts remain blocked until reviewed.</p><button class="button small" type="button" data-open-section="security">Review users</button></div><?php endif; ?>
</article>
</div>
<div class="grid2">
<article class="card"><div class="cardHead"><div><h2>New registrations</h2><p>Daily account creation over the last 14 days</p></div><span class="pill good"><?= h(number_format($registrationsInPeriod)) ?> total</span></div><div class="registrationChart" role="img" aria-label="Fourteen-day user registration bar chart"><?php foreach ($registrationChart as $day): $height=max(2,round($day['registered']*100/$registrationMaximum)); ?><div class="registrationBar" style="--bar-height:<?= h($height) ?>%" data-value="<?= h($day['registered']) ?>" title="<?= h($day['date']) ?>: <?= h($day['registered']) ?> registration<?= $day['registered'] === 1 ? '' : 's' ?>"></div><?php endforeach; ?></div><div class="registrationLabels"><?php foreach ($registrationChart as $day): ?><span title="<?= h($day['date']) ?>"><?= h($day['label']) ?></span><?php endforeach; ?></div></article>
<article class="card"><div class="cardHead"><div><h2>Account protection</h2><p>Verification and two-factor authentication coverage</p></div><span class="pill <?= $verifiedPercent >= 80 ? 'good' : 'warn' ?>"><?= h(number_format($verifiedPercent,1)) ?>% verified</span></div><div class="coverageList"><div><div class="coverageTop"><span>Email verified</span><strong><?= h(number_format($operations['verified_users'])) ?>/<?= h(number_format($accountTotal)) ?></strong></div><div class="progressTrack"><div class="progressFill secure" style="width:<?= h($verifiedPercent) ?>%"></div></div></div><div><div class="coverageTop"><span>2FA enabled</span><strong><?= h(number_format($operations['twofa_users'])) ?>/<?= h(number_format($accountTotal)) ?></strong></div><div class="progressTrack"><div class="progressFill" style="width:<?= h($twoFactorPercent) ?>%"></div></div></div><div><div class="coverageTop"><span>Pending invitations</span><strong><?= h(number_format($operations['pending_invitations'])) ?></strong></div><div class="progressTrack"><div class="progressFill" style="width:<?= h(min(100,$operations['pending_invitations']*10)) ?>%"></div></div></div></div></article>
</div>
<div class="grid2">
<article class="card"><div class="cardHead"><div><h2>Email delivery — 30 days</h2><p>Aggregated by document or message type; recipients stay private</p></div></div><?php if (!$emailActivity): ?><div class="empty">No standardized email events recorded yet.</div><?php else: ?><div class="tableWrap"><table><thead><tr><th>Channel</th><th>Sent</th><th>Failed</th><th>Last activity</th></tr></thead><tbody><?php foreach ($emailActivity as $emailRow): ?><tr><td><?= h($emailRow['channel'] ?: 'OTHER') ?></td><td><?= h(number_format((int)$emailRow['sent'])) ?></td><td><?= h(number_format((int)$emailRow['failed'])) ?></td><td><?= h($emailRow['last_activity']) ?></td></tr><?php endforeach; ?></tbody></table></div><?php endif; ?></article>
<article class="card"><div class="cardHead"><div><h2>Background jobs</h2><p>Current queue health</p></div><span class="pill <?= $operations['failed_jobs'] > 0 ? 'bad' : 'good' ?>"><?= h(number_format($operations['failed_jobs'])) ?> failed</span></div><?php if (!$jobActivity): ?><div class="empty">No background jobs recorded.</div><?php else: ?><div class="tableWrap"><table><thead><tr><th>Status</th><th>Total</th><th>Last activity</th></tr></thead><tbody><?php foreach ($jobActivity as $jobRow): ?><tr><td><?= h($jobRow['status']) ?></td><td><?= h(number_format((int)$jobRow['total'])) ?></td><td><?= h($jobRow['last_activity']) ?></td></tr><?php endforeach; ?></tbody></table></div><?php endif; ?></article>
</div>
</section>


<section class="section" data-section="health">
<div class="grid2">
<article class="card">
<div class="cardHead"><div><h2>System health</h2><p>Runtime, storage and operational readiness checks</p></div></div>
<?php foreach ($systemHealth as $health): ?>
<div class="healthItem"><div><div class="healthName"><span class="dot <?= $health['ok'] ? 'good' : 'bad' ?>"></span><?= h($health['name']) ?></div><div class="healthDetail"><?= h($health['detail']) ?></div></div><strong class="<?= $health['ok'] ? 'goodText' : 'dangerText' ?>"><?= h($health['value']) ?></strong></div>
<?php endforeach; ?>
</article>
<article class="card">
<div class="cardHead"><div><h2>Database health</h2><p>Schema posture and capacity warnings</p></div></div>
<div class="tableWrap"><table><tbody>
<tr><th>Tables without primary key</th><td class="<?= count($databaseHealth['tables_without_pk']) ? 'dangerText' : 'goodText' ?>"><?= h(count($databaseHealth['tables_without_pk'])) ?></td></tr>
<tr><th>Non-InnoDB tables</th><td class="<?= count($databaseHealth['non_innodb_tables']) ? 'warnText' : 'goodText' ?>"><?= h(count($databaseHealth['non_innodb_tables'])) ?></td></tr>
<tr><th>Indexes</th><td><?= h(number_format((int)$databaseHealth['total_indexes'])) ?></td></tr>
<tr><th>High AUTO_INCREMENT usage</th><td class="<?= count($databaseHealth['auto_increment_risk']) ? 'warnText' : 'goodText' ?>"><?= h(count($databaseHealth['auto_increment_risk'])) ?></td></tr>
<tr><th>Collations in use</th><td><?= h(count($databaseHealth['collations'])) ?></td></tr>
</tbody></table></div>
<?php if ($databaseHealth['tables_without_pk']): ?><div class="notice error" style="margin-top:14px">No primary key: <?= h(implode(', ', array_column($databaseHealth['tables_without_pk'],'table_name'))) ?></div><?php endif; ?>
<?php if ($databaseHealth['non_innodb_tables']): ?><div class="notice" style="margin-top:14px">Non-InnoDB tables detected. Review transactional and foreign-key expectations.</div><?php endif; ?>
</article>
</div>
<div class="grid2">
<article class="card"><div class="cardHead"><div><h2>Collation distribution</h2><p>Useful for spotting inconsistent character sets</p></div></div><div class="tableWrap"><table><thead><tr><th>Collation</th><th>Tables</th></tr></thead><tbody><?php foreach ($databaseHealth['collations'] as $row): ?><tr><td><?= h($row['table_collation'] ?? '-') ?></td><td><?= h($row['total']) ?></td></tr><?php endforeach; ?></tbody></table></div></article>
<article class="card"><div class="cardHead"><div><h2>AUTO_INCREMENT headroom</h2><p>Only tables at or above 70% of the integer range are listed</p></div></div><?php if (!$databaseHealth['auto_increment_risk']): ?><div class="empty">No high-risk AUTO_INCREMENT columns detected.</div><?php else: ?><div class="tableWrap"><table><thead><tr><th>Table</th><th>Next ID</th><th>Type</th><th>Max</th></tr></thead><tbody><?php foreach ($databaseHealth['auto_increment_risk'] as $row): ?><tr><td><?= h($row['table_name']) ?></td><td><?= h($row['auto_increment']) ?></td><td><?= h($row['column_type']) ?></td><td><?= h($row['max_value']) ?></td></tr><?php endforeach; ?></tbody></table></div><?php endif; ?></article>
</div>
</section>

<section class="section" data-section="errors">
<div class="metrics">
<article class="card metric <?= $logStats['errors_24h'] > 0 ? 'badMetric' : '' ?>"><span>Errors</span><strong><?= h(number_format($logStats['errors_24h'])) ?></strong><small>ERROR + CRITICAL · last 24 hours</small></article>
<article class="card metric <?= $logStats['critical_24h'] > 0 ? 'badMetric' : '' ?>"><span>Critical</span><strong><?= h(number_format($logStats['critical_24h'])) ?></strong><small>Last 24 hours</small></article>
<article class="card metric"><span>Warnings</span><strong><?= h(number_format($logStats['warnings_24h'])) ?></strong><small>Last 24 hours</small></article>
<article class="card metric <?= $applicationIssueCount > 0 ? 'badMetric' : 'goodMetric' ?>"><span>Detected compatibility issues</span><strong><?= h(number_format($applicationIssueCount)) ?></strong><small>Code, schema and logging checks</small></article>
</div>

<div class="grid2">
<article class="card"><div class="cardHead"><div><h2>Automatic compatibility checks</h2><p>Detects backend/schema mismatches before they break an application page</p></div><span class="pill <?= $applicationIssueCount > 0 ? 'bad' : 'good' ?>"><?= h($applicationIssueCount) ?> issue<?= $applicationIssueCount === 1 ? '' : 's' ?></span></div><div class="tableWrap"><table><thead><tr><th>Check</th><th>Status</th><th>Detection</th><th>Suggested action</th></tr></thead><tbody><?php foreach ($applicationChecks as $check): $checkStatus=(string)$check['status']; ?><tr><td><?= h($check['label']) ?></td><td><span class="status <?= $checkStatus === 'OK' ? 'applied' : ($checkStatus === 'WARNING' ? 'pending' : 'modified') ?>"><?= h($checkStatus) ?></span></td><td><?= h($check['detail']) ?></td><td><?= h($check['hint']) ?></td></tr><?php endforeach; ?></tbody></table></div></article>
<article class="card"><div class="cardHead"><div><h2>Error groups — 24 hours</h2><p>Repeated errors grouped by structured event name</p></div><span class="pill"><?= h(count($logStats['error_groups'])) ?> types</span></div><?php if (!$logStats['error_groups']): ?><div class="empty">No ERROR or CRITICAL event was detected in the current log window.</div><?php else: ?><div class="tableWrap"><table><thead><tr><th>Event</th><th>Occurrences</th></tr></thead><tbody><?php foreach ($logStats['error_groups'] as $errorEvent => $errorCount): ?><tr><td><?= h($errorEvent) ?></td><td class="dangerText"><?= h(number_format((int)$errorCount)) ?></td></tr><?php endforeach; ?></tbody></table></div><?php endif; ?><p class="auditHelp">Source: <code><?= h($configuredAppLogPath !== '' ? $configuredAppLogPath : BACKEND_DIRECTORY . '/storage/logs/app.jsonl') ?></code><br>Recent window scanned: <?= h(formatBytes((float)$logStats['scanned_bytes'])) ?></p></article>
</div>

<article class="card" style="margin-top:16px"><div class="cardHead"><div><h2>Recent application errors</h2><p>Safe structured details only; sensitive values remain redacted by the application logger</p></div><span class="pill <?= $logStats['recent_errors'] ? 'bad' : 'good' ?>"><?= h(count($logStats['recent_errors'])) ?> shown</span></div><?php if (!$logStats['recent_errors']): ?><div class="empty">No recent application errors are available.</div><?php else: ?><div class="tableWrap"><table><thead><tr><th>Time</th><th>Level</th><th>Event / endpoint</th><th>Stage</th><th>References</th><th>Request ID</th><th>Diagnostic</th><th>Suggested check</th></tr></thead><tbody><?php foreach ($logStats['recent_errors'] as $errorEvent): ?><tr><td><?= h($errorEvent['timestamp']) ?></td><td class="dangerText"><?= h($errorEvent['level']) ?></td><td><strong><?= h($errorEvent['event']) ?></strong><br><span class="tiny"><?= h($errorEvent['endpoint'] ?: '-') ?></span></td><td><?= h($errorEvent['stage'] ?: $errorEvent['status'] ?: '-') ?></td><td><?= h($errorEvent['references'] ?: '-') ?></td><td class="mono"><?= h($errorEvent['request_id'] ?: '-') ?></td><td><?= h($errorEvent['message'] ?: $errorEvent['exception'] ?: '-') ?></td><td><?= h($errorEvent['hint']) ?></td></tr><?php endforeach; ?></tbody></table></div><?php endif; ?></article>

<article class="card" style="margin-top:16px"><div class="cardHead"><div><h2>Supplier workflow diagnostics</h2><p>Supplier selection, purchase-order and reception events, including successful checkpoints</p></div><span class="pill"><?= h(count($logStats['supplier_events'])) ?> events</span></div><?php if (!$logStats['supplier_events']): ?><div class="empty">No supplier event has been recorded yet. Run the workflow once, then refresh Error Center.</div><?php else: ?><div class="tableWrap"><table><thead><tr><th>Time</th><th>Level</th><th>Event</th><th>Stage/status</th><th>References</th><th>Request ID</th><th>Diagnostic</th></tr></thead><tbody><?php foreach ($logStats['supplier_events'] as $supplierEvent): ?><tr><td><?= h($supplierEvent['timestamp']) ?></td><td class="<?= in_array($supplierEvent['level'], ['ERROR','CRITICAL'], true) ? 'dangerText' : ($supplierEvent['level'] === 'WARNING' ? 'warnText' : 'goodText') ?>"><?= h($supplierEvent['level']) ?></td><td><?= h($supplierEvent['event']) ?></td><td><?= h($supplierEvent['stage'] ?: $supplierEvent['status'] ?: '-') ?></td><td><?= h($supplierEvent['references'] ?: '-') ?></td><td class="mono"><?= h($supplierEvent['request_id'] ?: '-') ?></td><td><?= h($supplierEvent['message'] ?: $supplierEvent['exception'] ?: $supplierEvent['hint']) ?></td></tr><?php endforeach; ?></tbody></table></div><?php endif; ?></article>
</section>

<section class="section" data-section="tenants">
<div class="tenantGrid">
<article class="card">
<div class="cardHead"><div><h2>Companies</h2><p>Select a tenant to inspect its ownership and data</p></div><span class="pill"><?= h(count($companiesList)) ?></span></div>
<div class="scrollList">
<?php foreach ($companiesList as $company): ?>
<form method="post"><input type="hidden" name="csrf_token" value="<?= $csrf ?>"><input type="hidden" name="action" value="inspect_tenant"><input type="hidden" name="company_id" value="<?= h($company['id']) ?>"><button class="tenantButton" type="submit"><strong><?= h($company['organization_name'] ?: ('Company #'.$company['id'])) ?></strong><small>#<?= h($company['id']) ?> · owner <?= h($company['owner_user_id']) ?> · <?= h($company['status']) ?></small></button></form>
<?php endforeach; ?>
</div>
</article>
<article class="card">
<?php if (!$tenantInspection): ?>
<div class="empty">Choose a company to inspect its members, records and ownership alignment.</div>
<?php else: ?>
<div class="cardHead"><div><h2><?= h($tenantInspection['organization_name']) ?></h2><p>Tenant #<?= h($tenantInspection['id']) ?> · owner user #<?= h($tenantInspection['owner_user_id']) ?> · <?= h($tenantInspection['status']) ?></p></div><span class="pill"><?= h($tenantInspection['fiscal_id'] ?? '-') ?></span></div>
<div class="countGrid">
<?php foreach ($tenantCounts as $table=>$count): ?><div class="countBox"><span><?= h($table) ?></span><strong><?= h(number_format($count)) ?></strong></div><?php endforeach; ?>
</div>
<?php $mismatchTotal=array_sum($tenantMismatchCounts); ?>
<?php if ($mismatchTotal > 0): ?><div class="notice error" style="margin-top:16px">Potential ownership mismatch: <?= h(number_format($mismatchTotal)) ?> business row(s) are stored under the owner user ID instead of the selected company ID. Inspect before changing anything.</div><?php else: ?><div class="notice success" style="margin-top:16px">No owner-vs-company data mismatch was detected in the checked business tables.</div><?php endif; ?>
<?php if ($tenantMismatchCounts): ?><div class="tableWrap"><table><thead><tr><th>Business table</th><th>Tenant ID rows</th><th>Owner-user rows</th></tr></thead><tbody><?php foreach ($tenantMismatchCounts as $table=>$ownerCount): ?><tr><td><?= h($table) ?></td><td><?= h(number_format((int)($tenantCounts[$table] ?? 0))) ?></td><td class="<?= $ownerCount>0?'dangerText':'' ?>"><?= h(number_format($ownerCount)) ?></td></tr><?php endforeach; ?></tbody></table></div><?php endif; ?>
<div class="cardHead" style="margin-top:18px"><div><h2>Members</h2><p>Company membership and roles</p></div></div>
<div class="tableWrap"><table><thead><tr><th>User</th><th>Email</th><th>Role</th><th>Status</th><th>Owner</th></tr></thead><tbody><?php foreach (($tenantInspection['members'] ?? []) as $member): ?><tr><td>#<?= h($member['user_id']) ?> <?= h($member['display_name'] ?? '') ?></td><td><?= h($member['email'] ?? '-') ?></td><td><?= h($member['role']) ?></td><td><?= h($member['status']) ?></td><td><?= (int)$member['is_owner']===1?'Yes':'No' ?></td></tr><?php endforeach; ?></tbody></table></div>
<?php endif; ?>
</article>
</div>
</section>

<section class="section" data-section="integrity">
<article class="card">
<div class="cardHead"><div><h2>Data integrity scanner</h2><p>Read-only consistency checks across sales, purchasing and stock</p></div><span class="pill"><?= h(count($integrityChecks)) ?> checks</span></div>
<div class="notice">This scanner reports possible problems only. It never repairs or deletes records automatically.</div>
<div class="integrityGrid">
<?php foreach ($integrityChecks as $check): $cls=$check['status']==='OK'?'ok':($check['status']==='ISSUES'?'issues':'skipped'); ?>
<div class="integrityCard <?= h($cls) ?>"><div class="integrityTop"><strong><?= h($check['label']) ?></strong><span class="status <?= $check['status']==='OK'?'applied':($check['status']==='ISSUES'?'modified':'pending') ?>"><?= h($check['status']) ?></span></div><p><?= h($check['detail']) ?></p><?php if ($check['count']>0): ?><strong class="dangerText"><?= h(number_format($check['count'])) ?></strong><?php endif; ?></div>
<?php endforeach; ?>
</div>
</article>
</section>

<section class="section" data-section="backups">
<div class="grid2">
<article class="card">
<div class="cardHead"><div><h2>Create database backup</h2><p>Pure PHP schema + data export; no mysqldump binary required</p></div></div>
<div class="notice">This creates a database backup only. It exports base-table structures, rows and views using mysqli, then stores a SHA-256 checksum. Attachments/files, stored procedures, events and triggers are not included in this temporary PHP backup mode. Production restore is intentionally not exposed here.</div>
<form method="post" class="formGrid"><input type="hidden" name="csrf_token" value="<?= $csrf ?>"><input type="hidden" name="action" value="create_backup"><label class="field"><span>Type the database name to confirm</span><input class="input" name="confirm_database" placeholder="<?= h($dbName) ?>" autocomplete="off"></label><button class="button" type="submit">Create backup</button></form>
</article>
<article class="card">
<div class="cardHead"><div><h2>Backup readiness</h2><p>Server-side requirements</p></div></div>
<div class="tableWrap"><table><tbody><tr><th>Backup directory</th><td><?= h(backupDirectory()) ?></td></tr><tr><th>Writable</th><td><?= ensureBackupDirectory()?'Yes':'No' ?></td></tr><tr><th>Stored backups</th><td><?= h(count($backupList)) ?></td></tr><tr><th>Database</th><td><?= h($dbName) ?></td></tr></tbody></table></div>
</article>
</div>
<article class="card" style="margin-top:16px">
<div class="cardHead"><div><h2>Stored backups</h2><p>Verify checksums before using a backup</p></div><span class="pill"><?= h(count($backupList)) ?></span></div>
<?php if (!$backupList): ?><div class="empty">No Super Admin backups have been created yet.</div><?php else: ?><div class="tableWrap"><table><thead><tr><th>File</th><th>Created</th><th>Size</th><th>Checksum</th><th>Actions</th></tr></thead><tbody><?php foreach ($backupList as $backup): ?><tr><td><?= h($backup['name']) ?></td><td><?= h($backup['modified_at']) ?></td><td><?= h(formatBytes((float)$backup['size'])) ?></td><td class="mono"><?= h(shortChecksum((string)$backup['checksum'])) ?></td><td><div class="backupActions"><form method="post"><input type="hidden" name="csrf_token" value="<?= $csrf ?>"><input type="hidden" name="action" value="verify_backup"><input type="hidden" name="backup" value="<?= h($backup['name']) ?>"><button class="button secondary small" type="submit">Verify</button></form><form method="post"><input type="hidden" name="csrf_token" value="<?= $csrf ?>"><input type="hidden" name="action" value="download_backup"><input type="hidden" name="backup" value="<?= h($backup['name']) ?>"><button class="button secondary small" type="submit">Download</button></form></div></td></tr><?php endforeach; ?></tbody></table></div><?php endif; ?>
</article>
</section>

<section class="section" data-section="security">
<article class="card" style="margin-bottom:16px">
<div class="cardHead"><div><h2>New user activation</h2><p>Choose whether newly registered accounts require manual approval. Existing users are never changed by this setting.</p></div><span class="pill <?= $newUserApprovalRequired ? 'warn' : 'good' ?>"><?= $newUserApprovalRequired ? 'Manual approval' : 'Automatic activation' ?></span></div>
<?php if (!$userApprovalPolicyAvailable): ?><div class="notice error">Run the <code>2026-09-09-new-user-approval-policy.sql</code> migration to manage this setting.</div><?php else: ?>
<div class="policyOptions">
<form method="post" class="approvalPolicyForm" data-mode="manual"><input type="hidden" name="csrf_token" value="<?= $csrf ?>"><input type="hidden" name="action" value="set_user_approval_policy"><input type="hidden" name="approval_required" value="1"><button class="policyOption <?= $newUserApprovalRequired ? 'selected' : '' ?>" type="submit"><strong>Require manual approval</strong><span>New users remain pending. Accept them from the user list below.</span></button></form>
<form method="post" class="approvalPolicyForm" data-mode="automatic"><input type="hidden" name="csrf_token" value="<?= $csrf ?>"><input type="hidden" name="action" value="set_user_approval_policy"><input type="hidden" name="approval_required" value="0"><button class="policyOption <?= !$newUserApprovalRequired ? 'selected' : '' ?>" type="submit"><strong>Activate automatically</strong><span>New users become active immediately after registration.</span></button></form>
</div>
<?php endif; ?>
</article>
<div class="securityGrid">
<article class="card">
<div class="cardHead"><div><h2>User security</h2><p>Pending users cannot sign in or call authenticated APIs until accepted</p></div><span class="pill <?= $operations['pending_users'] > 0 ? 'warn' : 'good' ?>"><?= h(number_format($operations['pending_users'])) ?> pending</span></div>
<div class="tableWrap"><table><thead><tr><th>ID</th><th>User</th><th>Organization</th><th>Status</th><th>Verified</th><th>2FA</th><th>Created</th><th>Approved</th><th>Action</th></tr></thead><tbody><?php foreach ($securityUsers as $user): $accountStatus=strtoupper((string)($user['account_status'] ?? '')); $statusClass=$accountStatus==='ACTIVE'?'applied':($accountStatus==='PENDING'?'pending':'modified'); ?><tr><td><?= h($user['id']) ?></td><td><?= h($user['email']) ?><br><span class="tiny"><?= h($user['display_name'] ?? '') ?></span></td><td><?= h($user['organization_name'] ?? '-') ?></td><td><span class="status <?= h($statusClass) ?>"><?= h($accountStatus ?: '-') ?></span></td><td><?= !empty($user['email_verified_at'])?'Yes':'No' ?></td><td><?= (int)($user['google2fa_enabled'] ?? 0)===1?'Enabled':'Off' ?></td><td><?= h($user['created_at'] ?? '-') ?></td><td><?= h($user['approved_at'] ?? '-') ?></td><td><?php if ($accountStatus==='PENDING'): ?><form method="post" class="acceptUserForm" data-user="<?= h($user['id']) ?>" data-label="<?= h($user['organization_name'] ?: $user['email']) ?>"><input type="hidden" name="csrf_token" value="<?= $csrf ?>"><input type="hidden" name="action" value="accept_user"><input type="hidden" name="user_id" value="<?= h($user['id']) ?>"><input type="hidden" name="confirm_user_id" value=""><button class="button small" type="submit">Accept user</button></form><?php else: ?>-<?php endif; ?></td></tr><?php endforeach; ?></tbody></table></div>
</article>
<article class="card">
<div class="cardHead"><div><h2>Active sessions</h2><p>Refresh-token sessions grouped by user</p></div></div>
<?php if (!$securitySessions): ?><div class="empty">No refresh-token session data available.</div><?php else: ?><div class="tableWrap"><table><thead><tr><th>User ID</th><th>Active</th><th>Total tokens</th><th>Latest expiry</th><th>Action</th></tr></thead><tbody><?php foreach ($securitySessions as $session): ?><tr><td><?= h($session['user_id']) ?></td><td><?= h($session['active_sessions']) ?></td><td><?= h($session['total_tokens']) ?></td><td><?= h($session['latest_expiry']) ?></td><td><?php if ((int)$session['active_sessions']>0): ?><form method="post" class="revokeSessionsForm" data-user="<?= h($session['user_id']) ?>"><input type="hidden" name="csrf_token" value="<?= $csrf ?>"><input type="hidden" name="action" value="revoke_user_sessions"><input type="hidden" name="user_id" value="<?= h($session['user_id']) ?>"><input type="hidden" name="confirm_user_id" value=""><button class="button danger small" type="submit">Revoke sessions</button></form><?php else: ?>-<?php endif; ?></td></tr><?php endforeach; ?></tbody></table></div><?php endif; ?>
</article>
</div>
<article class="card" style="margin-top:16px">
<div class="cardHead"><div><h2>Recent invitations</h2><p>Pending or recently expiring company access links</p></div><span class="pill"><?= h(count($securityInvitations)) ?></span></div>
<?php if (!$securityInvitations): ?><div class="empty">No recent invitations.</div><?php else: ?><div class="tableWrap"><table><thead><tr><th>ID</th><th>Company</th><th>Email</th><th>Role</th><th>Status</th><th>Expires</th></tr></thead><tbody><?php foreach ($securityInvitations as $invite): ?><tr><td><?= h($invite['id']) ?></td><td><?= h($invite['company_id']) ?></td><td><?= h($invite['email']) ?></td><td><?= h($invite['role']) ?></td><td><?= h($invite['status']) ?></td><td><?= h($invite['expires_at']) ?></td></tr><?php endforeach; ?></tbody></table></div><?php endif; ?>
</article>
</section>

<section class="section" data-section="audit">
<article class="card">
<div class="cardHead"><div><h2>Audit Explorer</h2><p>Search application audit events without exposing tokens or IP addresses</p></div><span class="pill"><?= h(number_format($auditExplorerTotal)) ?> matches</span></div>
<form method="post" class="auditFilters"><input type="hidden" name="csrf_token" value="<?= $csrf ?>"><input type="hidden" name="action" value="audit_filter"><label class="field"><span>Action</span><input class="input" name="audit_action" value="<?= h($auditFilters['action']) ?>" placeholder="AUTH., EMAIL., INVOICE..."></label><label class="field"><span>Entity type</span><input class="input" name="audit_entity_type" value="<?= h($auditFilters['entity_type']) ?>" placeholder="INVOICE"></label><label class="field"><span>Actor ID</span><input class="input" name="audit_actor_id" value="<?= h($auditFilters['actor_id']) ?>" inputmode="numeric"></label><label class="field"><span>From</span><input class="input" type="date" name="audit_from" value="<?= h($auditFilters['from']) ?>"></label><label class="field"><span>To</span><input class="input" type="date" name="audit_to" value="<?= h($auditFilters['to']) ?>"></label><button class="button" type="submit">Search</button></form>
<div style="margin-top:16px" class="tableWrap"><table><thead><tr><th>Time</th><th>Action</th><th>Entity</th><th>Entity ID</th><th>Actor</th></tr></thead><tbody><?php foreach ($auditExplorerRows as $row): ?><tr><td><?= h($row['created_at']) ?></td><td><?= h($row['action']) ?></td><td><?= h($row['entity_type']) ?></td><td><?= h($row['entity_id'] ?? '-') ?></td><td><?= h($row['actor_id'] ?? 'system') ?></td></tr><?php endforeach; ?></tbody></table></div>
<?php $auditPages=max(1,(int)ceil($auditExplorerTotal/$auditPageSize)); ?>
<div class="paginationBar"><span class="tiny">Page <?= h($auditPage) ?> / <?= h($auditPages) ?> · <?= h($auditPageSize) ?> rows per page</span><div class="backupActions"><?php if ($auditPage>1): ?><form method="post"><input type="hidden" name="csrf_token" value="<?= $csrf ?>"><input type="hidden" name="action" value="audit_filter"><input type="hidden" name="audit_page" value="<?= h($auditPage-1) ?>"><?php foreach ($auditFilters as $k=>$v): ?><input type="hidden" name="audit_<?= h($k) ?>" value="<?= h($v) ?>"><?php endforeach; ?><button class="button secondary small" type="submit">Previous</button></form><?php endif; ?><?php if ($auditPage<$auditPages): ?><form method="post"><input type="hidden" name="csrf_token" value="<?= $csrf ?>"><input type="hidden" name="action" value="audit_filter"><input type="hidden" name="audit_page" value="<?= h($auditPage+1) ?>"><?php foreach ($auditFilters as $k=>$v): ?><input type="hidden" name="audit_<?= h($k) ?>" value="<?= h($v) ?>"><?php endforeach; ?><button class="button secondary small" type="submit">Next</button></form><?php endif; ?></div></div>
</article>
</section>

<section class="section" data-section="sql"><article class="card"><div class="cardHead"><div><h2>SQL Console</h2><p>Direct query and schema control — multiple statements supported</p></div><button class="button secondary small" type="button" id="pricingMigrationTemplate">Load pricing fix</button></div><?php if (!$sqlEnabled): ?><div class="notice error">Set <code>SERVER_DASHBOARD_SQL_ENABLED=true</code> in <code>backend/.env</code> to enable execution.</div><?php endif; ?><form method="post" class="formGrid"><input type="hidden" name="action" value="run_sql"><input type="hidden" name="csrf_token" value="<?= $csrf ?>"><label class="field"><span>SQL commands</span><textarea class="textarea" id="sqlEditor" name="sql" spellcheck="false"><?= h($sqlText) ?></textarea></label><div class="confirm"><label><input type="checkbox" name="confirm_write" value="1"> I authorize data/schema changes</label><label class="field"><span>Database confirmation</span><input class="input" name="confirm_database" placeholder="Type <?= h($dbName) ?> for writes" autocomplete="off"></label><button class="button" type="submit" <?= (!$sqlEnabled || !($db instanceof mysqli)) ? 'disabled' : '' ?>>Execute SQL</button></div></form><?php foreach ($sqlResults as $index => $result): ?><div class="result"><h3>Result <?= h($index + 1) ?></h3><?php if ($result['affected'] !== null): ?><div class="notice success"><?= h($result['affected']) ?> row(s) affected.</div><?php elseif (!$result['rows']): ?><div class="empty">Query completed with no returned rows.</div><?php else: ?><div class="tableWrap"><table><thead><tr><?php foreach ($result['columns'] as $column): ?><th><?= h($column) ?></th><?php endforeach; ?></tr></thead><tbody><?php foreach ($result['rows'] as $row): ?><tr><?php foreach ($result['columns'] as $column): ?><td><?= h($row[$column] ?? 'NULL') ?></td><?php endforeach; ?></tr><?php endforeach; ?></tbody></table></div><?php if ($result['truncated']): ?><div class="notice">Display limited to <?= SQL_RESULT_ROW_LIMIT ?> rows.</div><?php endif; ?><?php endif; ?></div><?php endforeach; ?></article></section>

<section class="section" data-section="migrations"><article class="card"><div class="cardHead"><div><h2>Repository migrations</h2><p>Inspect and apply reviewed SQL files from <code>backend/sql/</code></p></div><div class="topMeta"><span class="pill"><?= h(count($migrationFiles)) ?> files</span><span class="pill <?= count($pendingMigrations) > 0 ? 'warn' : 'good' ?>"><?= h(count($pendingMigrations)) ?> pending</span><?php if ($modifiedMigrations): ?><span class="pill bad"><?= h(count($modifiedMigrations)) ?> modified</span><?php endif; ?></div></div><div class="notice">Schema migrations can permanently modify production data. Review the SQL first and verify that a current backup exists before execution. MySQL/MariaDB DDL can implicitly commit, so a failed migration is not automatically guaranteed to roll back.</div><?php if (!$sqlEnabled): ?><div class="notice error">Migration execution is disabled because <code>SERVER_DASHBOARD_SQL_ENABLED=false</code>.</div><?php endif; ?><div class="migrationConfirm"><label class="field"><span>Database confirmation for migration execution</span><input class="input" id="migrationDatabaseConfirmation" placeholder="Type <?= h($dbName) ?>" autocomplete="off"></label><div><span class="pill">Target: <?= h($dbName) ?></span></div><p class="hint">The typed database name is copied into the selected migration form only when you click Run Migration.</p></div><?php if (!$migrationInfo): ?><div class="empty">No SQL migration files found in backend/sql/.</div><?php else: ?><div class="tableWrap"><table><thead><tr><th>Migration</th><th>Status</th><th>Applied at</th><th>Duration</th><th>Checksum</th><th>Actions</th></tr></thead><tbody><?php foreach (array_reverse($migrationInfo) as $migration): $version=$migration['version']; $applied=(bool)$migration['applied']; $modified=(bool)$migration['modified']; ?><tr><td><?= h($version) ?></td><td><?php if ($modified): ?><span class="status modified">MODIFIED</span><?php elseif ($applied): ?><span class="status applied">APPLIED</span><?php else: ?><span class="status pending">PENDING</span><?php endif; ?></td><td><?= h($migration['applied_at'] ?? '-') ?></td><td><?= $migration['execution_ms'] !== null ? h(number_format((float)$migration['execution_ms'],2)).' ms' : '-' ?></td><td class="checksum" title="<?= h($migration['checksum']) ?>"><?= h(shortChecksum((string)$migration['checksum'])) ?><?php if ($modified): ?><br><small style="color:#fecdd3">stored <?= h(shortChecksum((string)$migration['stored_checksum'])) ?></small><?php endif; ?></td><td><div class="migrationActions"><form method="post"><input type="hidden" name="csrf_token" value="<?= $csrf ?>"><input type="hidden" name="action" value="load_migration"><input type="hidden" name="migration" value="<?= h($version) ?>"><button class="button secondary small" type="submit">Inspect SQL</button></form><?php if (!$applied && !$modified): ?><form method="post" class="runMigrationForm" data-migration="<?= h($version) ?>"><input type="hidden" name="csrf_token" value="<?= $csrf ?>"><input type="hidden" name="action" value="run_migration"><input type="hidden" name="migration" value="<?= h($version) ?>"><input type="hidden" name="confirm_database" value=""><input type="hidden" name="confirm_migration" value="1"><button class="button small" type="submit" <?= (!$sqlEnabled || !($db instanceof mysqli)) ? 'disabled' : '' ?>>Run Migration</button></form><?php elseif ($modified): ?><button class="button danger small" type="button" disabled>Execution blocked</button><?php else: ?><button class="button secondary small" type="button" disabled>Already applied</button><?php endif; ?></div></td></tr><?php endforeach; ?></tbody></table></div><?php endif; ?></article></section>

<section class="section" data-section="schema">
<article class="card">
<div class="cardHead"><div><h2>Database schema map</h2><p>Live visualization of tables, columns, primary keys and foreign-key relationships from <code>information_schema</code>.</p></div><span class="pill"><?= h(count($schemaRelations)) ?> relationships</span></div>
<div class="schemaStats">
<article class="card"><span>Tables</span><strong><?= h(number_format(count($schemaTables))) ?></strong></article>
<article class="card"><span>Columns</span><strong><?= h(number_format($schemaColumnCount)) ?></strong></article>
<article class="card"><span>Primary keys</span><strong><?= h(number_format($schemaPrimaryKeyCount)) ?></strong></article>
<article class="card"><span>Foreign keys</span><strong><?= h(number_format($schemaForeignKeyCount)) ?></strong></article>
<article class="card"><span>Database size</span><strong><?= h(formatBytes($databaseSize)) ?></strong></article>
</div>
<div class="schemaToolbar">
<input class="input schemaSearch" id="schemaSearch" type="search" placeholder="Search table or column..." autocomplete="off">
<label class="pill"><input type="checkbox" id="schemaRelatedOnly"> Related tables only</label>
<button class="button secondary small" type="button" id="schemaReset">Reset view</button>
</div>
<div class="schemaLegend"><span><i class="schemaBadge pk">PK</i> Primary key</span><span><i class="schemaBadge fk">FK</i> Foreign key</span><span><i class="legendLine"></i> Foreign-key relationship</span><span>Click a table to highlight its links</span></div>
<div class="schemaCanvasWrap" id="schemaCanvasWrap">
<div class="schemaCanvas" id="schemaCanvas">
<svg class="schemaLinks" id="schemaLinks" aria-hidden="true"></svg>
<div class="schemaGrid" id="schemaGrid">
<?php foreach ($schemaTables as $schemaTable): ?>
<article class="schemaTable" data-schema-table="<?= h($schemaTable['name']) ?>" tabindex="0">
<div class="schemaTableHead"><div><strong><?= h($schemaTable['name']) ?></strong><div class="schemaTableMeta"><span><?= h($schemaTable['engine'] ?: '-') ?></span><span>≈ <?= h(number_format((int)$schemaTable['rows'])) ?> rows</span><span><?= h(formatBytes((float)$schemaTable['bytes'])) ?></span><span><?= h(count($schemaTable['columns'])) ?> cols</span></div></div><span class="pill"><?= h(count($schemaTable['outgoing']) + count($schemaTable['incoming'])) ?> links</span></div>
<div class="schemaColumns">
<?php foreach ($schemaTable['columns'] as $column): ?>
<div class="schemaColumn" data-schema-column="<?= h($column['name']) ?>"><div class="schemaColumnName"><div><?= h($column['name']) ?></div><div class="schemaColumnType"><?= h($column['type']) ?><?= $column['nullable'] ? ' · NULL' : '' ?><?= $column['extra'] !== '' ? ' · ' . h($column['extra']) : '' ?></div></div><div class="schemaBadges"><?php if ($column['primary']): ?><span class="schemaBadge pk">PK</span><?php endif; ?><?php if ($column['foreign']): ?><span class="schemaBadge fk">FK</span><?php endif; ?></div></div>
<?php endforeach; ?>
</div>
<div class="schemaTableFoot"><button type="button" class="button secondary small schemaRowsButton" data-table="<?= h($schemaTable['name']) ?>">Inspect rows</button><button type="button" class="button secondary small schemaDescribeButton" data-table="<?= h($schemaTable['name']) ?>">Describe</button></div>
</article>
<?php endforeach; ?>
</div>
</div>
</div>
<div class="schemaRelationList">
<div class="cardHead"><div><h2>Foreign-key links</h2><p>Exact database relationships, including update and delete behavior.</p></div></div>
<?php if (!$schemaRelations): ?><div class="empty">No foreign-key relationships were detected.</div><?php else: ?><div class="tableWrap"><table><thead><tr><th>Constraint</th><th>From</th><th>To</th><th>On update</th><th>On delete</th></tr></thead><tbody><?php foreach ($schemaRelations as $relation): ?><tr><td><?= h($relation['constraint']) ?></td><td><?= h($relation['from_table']) ?>.<?= h($relation['from_column']) ?></td><td><?= h($relation['to_table']) ?>.<?= h($relation['to_column']) ?></td><td><?= h($relation['update_rule'] ?: '-') ?></td><td><?= h($relation['delete_rule'] ?: '-') ?></td></tr><?php endforeach; ?></tbody></table></div><?php endif; ?>
</div>
</article>
</section>

<section class="section" data-section="storage"><article class="card"><div class="cardHead"><div><h2>Largest tables</h2><p>Estimated rows and allocated database storage</p></div><span class="pill"><?= h(formatBytes($databaseSize)) ?></span></div><div class="grid2"><div class="tableWrap"><table><tbody><tr><th>Database</th><td><?= h($dbName) ?></td></tr><tr><th>Version</th><td><?= h($databaseVersion) ?></td></tr><tr><th>Connection</th><td><?= h(number_format($connectionLatency,2)) ?> ms</td></tr><tr><th>Tables</th><td><?= h(number_format($tableCount)) ?></td></tr><tr><th>Allocated size</th><td><?= h(formatBytes($databaseSize)) ?></td></tr></tbody></table></div><div><p class="auditHelp">SQL audit log: <code>backend/storage/logs/super-admin-sql.jsonl</code><br>Migration audit log: <code>backend/storage/logs/super-admin-migrations.jsonl</code></p></div></div><div style="margin-top:16px" class="tableWrap"><table><thead><tr><th>Table</th><th>Estimated rows</th><th>Total size</th></tr></thead><tbody><?php foreach ($largestTables as $table): ?><tr><td><?= h($table['table_name']) ?></td><td><?= h(number_format((int)$table['table_rows'])) ?></td><td><?= h(formatBytes((float)$table['total_bytes'])) ?></td></tr><?php endforeach; ?></tbody></table></div></article></section>
</main></div>
<script nonce="<?= h($cspNonce) ?>">
const tabs=[...document.querySelectorAll('[data-tab]')];const sections=[...document.querySelectorAll('[data-section]')];function openTab(name){tabs.forEach(tab=>tab.classList.toggle('active',tab.dataset.tab===name));sections.forEach(section=>section.classList.toggle('active',section.dataset.section===name));history.replaceState(null,'','#'+name);if(name==='schema')requestAnimationFrame(()=>requestAnimationFrame(drawSchemaLinks))}tabs.forEach(tab=>tab.addEventListener('click',()=>openTab(tab.dataset.tab)));document.querySelectorAll('[data-open-section]').forEach(button=>button.addEventListener('click',()=>{openTab(button.dataset.openSection);window.scrollTo({top:0,behavior:'smooth'})}));const serverActiveTab=<?= json_encode($activeTab, JSON_UNESCAPED_SLASHES) ?>;const initial=location.hash.slice(1);if(sections.some(section=>section.dataset.section===initial))openTab(initial);else openTab(serverActiveTab||'overview');const schemaRelations=<?= json_encode($schemaRelations, JSON_HEX_TAG|JSON_HEX_AMP|JSON_HEX_APOS|JSON_HEX_QUOT|JSON_UNESCAPED_SLASHES) ?>;
const schemaCanvas=document.getElementById('schemaCanvas');
const schemaLinks=document.getElementById('schemaLinks');
const schemaSearch=document.getElementById('schemaSearch');
const schemaRelatedOnly=document.getElementById('schemaRelatedOnly');
const schemaCards=[...document.querySelectorAll('[data-schema-table]')];
let selectedSchemaTable='';
function schemaVisibleCards(){return schemaCards.filter(card=>!card.classList.contains('hidden'))}
function drawSchemaLinks(){
  if(!schemaCanvas||!schemaLinks)return;
  const cards=new Map(schemaVisibleCards().map(card=>[card.dataset.schemaTable,card]));
  const base=schemaCanvas.getBoundingClientRect();
  const width=Math.max(schemaCanvas.scrollWidth,schemaCanvas.clientWidth);
  const height=Math.max(schemaCanvas.scrollHeight,schemaCanvas.clientHeight);
  schemaLinks.setAttribute('viewBox',`0 0 ${width} ${height}`);
  schemaLinks.setAttribute('width',width);schemaLinks.setAttribute('height',height);
  schemaLinks.innerHTML='';
  schemaRelations.forEach(rel=>{
    const from=cards.get(rel.from_table),to=cards.get(rel.to_table);if(!from||!to)return;
    const a=from.getBoundingClientRect(),b=to.getBoundingClientRect();
    const x1=a.left-base.left+a.width/2,y1=a.top-base.top+a.height/2;
    const x2=b.left-base.left+b.width/2,y2=b.top-base.top+b.height/2;
    const bend=Math.max(55,Math.abs(x2-x1)*.35);
    const ns='http://www.w3.org/2000/svg';
    const path=document.createElementNS(ns,'path');
    const dir=x2>=x1?1:-1;
    path.setAttribute('d',`M ${x1} ${y1} C ${x1+bend*dir} ${y1}, ${x2-bend*dir} ${y2}, ${x2} ${y2}`);
    path.setAttribute('class','schemaRelationPath'+((selectedSchemaTable===rel.from_table||selectedSchemaTable===rel.to_table)?' highlight':''));
    path.dataset.from=rel.from_table;path.dataset.to=rel.to_table;schemaLinks.appendChild(path);
    const dot=document.createElementNS(ns,'circle');dot.setAttribute('cx',x2);dot.setAttribute('cy',y2);dot.setAttribute('r','3');dot.setAttribute('class','schemaRelationDot');schemaLinks.appendChild(dot);
  });
}
function filterSchema(){
  const q=(schemaSearch?.value||'').trim().toLowerCase();
  const relatedOnly=!!schemaRelatedOnly?.checked;
  const related=new Set();schemaRelations.forEach(r=>{related.add(r.from_table);related.add(r.to_table)});
  schemaCards.forEach(card=>{
    const table=(card.dataset.schemaTable||'').toLowerCase();
    const columns=[...card.querySelectorAll('[data-schema-column]')].map(el=>(el.dataset.schemaColumn||'').toLowerCase());
    const matches=!q||table.includes(q)||columns.some(c=>c.includes(q));
    const show=matches&&(!relatedOnly||related.has(card.dataset.schemaTable));
    card.classList.toggle('hidden',!show);
  });
  requestAnimationFrame(drawSchemaLinks);
}
schemaSearch?.addEventListener('input',filterSchema);schemaRelatedOnly?.addEventListener('change',filterSchema);
document.getElementById('schemaReset')?.addEventListener('click',()=>{if(schemaSearch)schemaSearch.value='';if(schemaRelatedOnly)schemaRelatedOnly.checked=false;selectedSchemaTable='';filterSchema()});
schemaCards.forEach(card=>{const choose=()=>{selectedSchemaTable=selectedSchemaTable===card.dataset.schemaTable?'':card.dataset.schemaTable;drawSchemaLinks()};card.addEventListener('click',e=>{if(e.target.closest('button'))return;choose()});card.addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();choose()}})});
function quoteTableName(name){return '`'+String(name).replaceAll('`','``')+'`'}
document.querySelectorAll('.schemaRowsButton').forEach(button=>button.addEventListener('click',()=>{const name=button.dataset.table||'';const editor=document.getElementById('sqlEditor');if(editor)editor.value=`SELECT * FROM ${quoteTableName(name)} LIMIT 100;`;openTab('sql')}));
document.querySelectorAll('.schemaDescribeButton').forEach(button=>button.addEventListener('click',()=>{const name=button.dataset.table||'';const editor=document.getElementById('sqlEditor');if(editor)editor.value=`SHOW CREATE TABLE ${quoteTableName(name)};`;openTab('sql')}));
window.addEventListener('resize',()=>requestAnimationFrame(drawSchemaLinks));
const schemaSection=document.querySelector('[data-section="schema"]');if(schemaSection){new ResizeObserver(()=>drawSchemaLinks()).observe(schemaSection)}
document.getElementById('pricingMigrationTemplate')?.addEventListener('click',()=>{document.getElementById('sqlEditor').value=`ALTER TABLE products\nADD COLUMN IF NOT EXISTS selling_price_required TINYINT(1) NOT NULL DEFAULT 0 AFTER price;\n\nUPDATE products\nSET selling_price_required = 1\nWHERE item_type = 'PRODUCT' AND price <= 0;\n\nCREATE INDEX IF NOT EXISTS idx_products_company_pricing_required\nON products (user_id, item_type, selling_price_required, id);`;openTab('sql')});const migrationDbInput=document.getElementById('migrationDatabaseConfirmation');document.querySelectorAll('.runMigrationForm').forEach(form=>{form.addEventListener('submit',event=>{const migration=form.dataset.migration||'migration';const typed=(migrationDbInput?.value||'').trim();if(!typed){event.preventDefault();alert('Type the exact database name before running this migration.');migrationDbInput?.focus();return}const confirmed=window.confirm(`Run ${migration} on database ${typed}?\n\nConfirm only if you reviewed the SQL and have a current backup.`);if(!confirmed){event.preventDefault();return}form.querySelector('input[name="confirm_database"]').value=typed})});

document.querySelectorAll('.revokeSessionsForm').forEach(form=>{
  form.addEventListener('submit',event=>{
    const userId=form.dataset.user||'';
    const typed=window.prompt(`Type user ID ${userId} to revoke all active refresh-token sessions for this account.`);
    if(typed===null || typed.trim()!==userId){
      event.preventDefault();
      return;
    }
    if(!window.confirm(`Revoke all active sessions for user #${userId}?`)){
      event.preventDefault();
      return;
    }
    form.querySelector('input[name="confirm_user_id"]').value=typed.trim();
  });
});

document.querySelectorAll('.acceptUserForm').forEach(form=>{
  form.addEventListener('submit',event=>{
    const userId=form.dataset.user||'';
    const label=form.dataset.label||`user #${userId}`;
    if(!window.confirm(`Accept ${label}?\n\nThis user will immediately be allowed to sign in and access the company workspace.`)){
      event.preventDefault();
      return;
    }
    form.querySelector('input[name="confirm_user_id"]').value=userId;
  });
});

document.querySelectorAll('.approvalPolicyForm').forEach(form=>{
  form.addEventListener('submit',event=>{
    if(form.dataset.mode!=='automatic')return;
    if(!window.confirm('Enable automatic activation?\n\nFuture users will be able to sign in without being reviewed by a Super Admin.'))event.preventDefault();
  });
});

</script>
</body></html>

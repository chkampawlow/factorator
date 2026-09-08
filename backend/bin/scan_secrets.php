<?php

if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
require_once __DIR__ . '/../config/env.php';
loadEnv(__DIR__ . '/../.env');

$repositoryRoot = realpath((string)($argv[1] ?? dirname(__DIR__, 2)));
if ($repositoryRoot === false || !is_dir($repositoryRoot . '/.git')) {
    fwrite(STDERR, "FAIL repository root is required\n");
    exit(2);
}

$pipes = [];
$process = proc_open(['git','-C',$repositoryRoot,'ls-files','-z'], [0=>['file','/dev/null','r'],1=>['pipe','w'],2=>['pipe','w']], $pipes);
if (!is_resource($process)) throw new RuntimeException('Could not list tracked files');
$trackedOutput = stream_get_contents($pipes[1]);
$errorOutput = stream_get_contents($pipes[2]);
fclose($pipes[1]); fclose($pipes[2]);
if (proc_close($process) !== 0) throw new RuntimeException(trim($errorOutput));

$sensitiveKeys = ['DB_PASS','JWT_SECRET','TWO_FACTOR_ENCRYPTION_KEY','MAIL_PASSWORD','ERROR_MONITOR_WEBHOOK_SECRET','BACKUP_ENCRYPTION_KEY'];
$secretValues = [];
foreach ($sensitiveKeys as $key) {
    $value = (string)($_ENV[$key] ?? '');
    if (strlen($value) >= 8) $secretValues[$key] = $value;
}
$signaturePattern = '/-----BEGIN (?:[A-Z ]+)?PRIVATE KEY|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{30,}|ghp_[0-9A-Za-z]{30,}|xox[baprs]-[0-9A-Za-z-]{20,}/';
$leaks = [];
$files = array_values(array_filter(explode("\0", (string)$trackedOutput), static fn(string $file): bool =>
    !str_starts_with($file, 'backend/vendor/') && !str_starts_with($file, 'extractor/.venv/')
));
$distFiles = [];
if (is_dir($repositoryRoot . '/dist')) {
    foreach (new RecursiveIteratorIterator(new RecursiveDirectoryIterator($repositoryRoot . '/dist', FilesystemIterator::SKIP_DOTS)) as $item) {
        if ($item->isFile() && strtolower($item->getExtension()) === 'js') $distFiles[] = $item->getPathname();
    }
}
foreach ([...array_map(fn(string $file): string => $repositoryRoot . '/' . $file, $files), ...$distFiles] as $file) {
    if (!is_file($file) || filesize($file) > 10 * 1024 * 1024) continue;
    $contents = file_get_contents($file);
    if ($contents === false) continue;
    foreach ($secretValues as $key => $secret) if (str_contains($contents, $secret)) $leaks[] = basename($file) . ':' . $key;
    if (preg_match($signaturePattern, $contents) === 1) $leaks[] = basename($file) . ':credential-signature';
}

if ($leaks !== []) {
    foreach (array_unique($leaks) as $leak) fwrite(STDERR, 'FAIL ' . $leak . PHP_EOL);
    exit(1);
}
echo 'PASS no configured secrets or private credential signatures found in ' . count($files) . " tracked files or built JavaScript\n";

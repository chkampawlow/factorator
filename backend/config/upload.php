<?php

require_once __DIR__ . '/env.php';

function privateStorageRoot(): string
{
    if (!isset($_ENV['PRIVATE_STORAGE_DIR'])) {
        $envPath = dirname(__DIR__) . '/.env';
        if (is_file($envPath)) loadEnv($envPath);
    }
    $configured = trim((string)($_ENV['PRIVATE_STORAGE_DIR'] ?? getenv('PRIVATE_STORAGE_DIR') ?: ''));
    return rtrim($configured !== '' ? $configured : dirname(__DIR__, 3) . '/el-fatoura-private', DIRECTORY_SEPARATOR);
}

function validatedUpload(array $file, array $allowedMimeExtensions, int $maxBytes, bool $requireHttpUpload = true): array
{
    if ((int)($file['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_OK) {
        throw new InvalidArgumentException('File upload failed.');
    }
    $temporaryPath = (string)($file['tmp_name'] ?? '');
    if ($temporaryPath === '' || ($requireHttpUpload ? !is_uploaded_file($temporaryPath) : !is_file($temporaryPath))) {
        throw new InvalidArgumentException('Invalid uploaded file.');
    }
    $actualSize = filesize($temporaryPath);
    if ($actualSize === false || $actualSize <= 0 || $actualSize > $maxBytes) {
        throw new InvalidArgumentException('Uploaded file is empty or exceeds the allowed size.');
    }
    $mime = (new finfo(FILEINFO_MIME_TYPE))->file($temporaryPath);
    if (!is_string($mime) || !isset($allowedMimeExtensions[$mime])) {
        throw new InvalidArgumentException('Unsupported uploaded file type.');
    }
    assertPassiveDocument($temporaryPath, $mime, (int)$actualSize);
    $extension = strtolower(pathinfo((string)($file['name'] ?? ''), PATHINFO_EXTENSION));
    $allowedExtensions = (array)$allowedMimeExtensions[$mime];
    if (!in_array($extension, $allowedExtensions, true)) {
        throw new InvalidArgumentException('The file extension does not match its contents.');
    }
    $displayName = preg_replace('/[\x00-\x1F\x7F]/u', '', basename((string)$file['name'])) ?: 'document.' . $allowedExtensions[0];
    return [
        'tmp_name' => $temporaryPath,
        'size' => (int)$actualSize,
        'mime' => $mime,
        'extension' => $allowedExtensions[0],
        'display_name' => function_exists('mb_substr') ? mb_substr($displayName, 0, 255) : substr($displayName, 0, 255),
        'stored_name' => bin2hex(random_bytes(24)) . '.' . $allowedExtensions[0],
    ];
}

function assertPassiveDocument(string $path, string $mime, int $size): void
{
    $contents = file_get_contents($path);
    if ($contents === false || strlen($contents) !== $size) throw new InvalidArgumentException('Could not inspect uploaded file.');
    if (preg_match('/<\?(?:php|=)|<script\b|^#!|^MZ|^\x7FELF/is', $contents) === 1) {
        throw new InvalidArgumentException('Executable or active file content is not allowed.');
    }
    if ($mime === 'application/pdf') {
        if (!str_starts_with($contents, '%PDF-') || preg_match('/\/(?:JavaScript|JS|Launch|EmbeddedFile)\b/i', $contents) === 1) {
            throw new InvalidArgumentException('Active or malformed PDF content is not allowed.');
        }
        return;
    }
    if (str_starts_with($mime, 'image/') && @getimagesize($path) === false) {
        throw new InvalidArgumentException('Malformed image content is not allowed.');
    }
    if ($mime === 'image/png' && !str_ends_with($contents, "\x00\x00\x00\x00IEND\xAE\x42\x60\x82")) {
        throw new InvalidArgumentException('Trailing content after a PNG image is not allowed.');
    }
    if ($mime === 'image/jpeg' && !str_ends_with(rtrim($contents), "\xFF\xD9")) {
        throw new InvalidArgumentException('Trailing content after a JPEG image is not allowed.');
    }
    if ($mime === 'image/webp' && ($size < 12 || substr($contents, 0, 4) !== 'RIFF' || substr($contents, 8, 4) !== 'WEBP'
        || (unpack('Vsize', substr($contents, 4, 4))['size'] ?? -1) + 8 !== $size)) {
        throw new InvalidArgumentException('Malformed WEBP content is not allowed.');
    }
}

function ensurePrivateDirectory(string $relativePath): string
{
    $safeSegments = array_filter(explode('/', trim($relativePath, '/')), static fn(string $segment): bool => preg_match('/^[A-Za-z0-9_-]+$/', $segment) === 1);
    if (implode('/', $safeSegments) !== trim($relativePath, '/')) throw new InvalidArgumentException('Invalid private storage path.');
    $directory = privateStorageRoot() . DIRECTORY_SEPARATOR . implode(DIRECTORY_SEPARATOR, $safeSegments);
    if (!is_dir($directory) && !mkdir($directory, 0770, true) && !is_dir($directory)) {
        throw new RuntimeException('Could not create private storage directory.');
    }
    return $directory;
}

<?php

require_once __DIR__ . '/../config/upload.php';

function expectUpload(string $name, callable $test, bool $shouldPass): void
{
    try {
        $test();
        $passed = true;
    } catch (Throwable) {
        $passed = false;
    }
    if ($passed !== $shouldPass) throw new RuntimeException('FAIL ' . $name);
    echo 'PASS ' . $name . "\n";
}

$temporary = tempnam(sys_get_temp_dir(), 'ef-upload-');
if ($temporary === false) throw new RuntimeException('Unable to create test fixture');
file_put_contents($temporary, "%PDF-1.4\n%%EOF\n");
$allowed = ['application/pdf' => ['pdf']];

try {
    $valid = validatedUpload(['error'=>UPLOAD_ERR_OK,'tmp_name'=>$temporary,'name'=>'invoice.pdf'], $allowed, 1024, false);
    expectUpload('real MIME and matching extension accepted', fn() => validatedUpload(['error'=>UPLOAD_ERR_OK,'tmp_name'=>$temporary,'name'=>'invoice.pdf'], $allowed, 1024, false), true);
    expectUpload('MIME and extension mismatch rejected', fn() => validatedUpload(['error'=>UPLOAD_ERR_OK,'tmp_name'=>$temporary,'name'=>'invoice.jpg'], $allowed, 1024, false), false);
    expectUpload('actual file size limit enforced', fn() => validatedUpload(['error'=>UPLOAD_ERR_OK,'tmp_name'=>$temporary,'name'=>'invoice.pdf'], $allowed, 4, false), false);
    file_put_contents($temporary, "#!/bin/sh\necho compromised\n");
    expectUpload('executable disguised as PDF rejected', fn() => validatedUpload(['error'=>UPLOAD_ERR_OK,'tmp_name'=>$temporary,'name'=>'invoice.pdf'], $allowed, 1024, false), false);
    file_put_contents($temporary, "%PDF-1.4\n1 0 obj <<>> endobj\n%%EOF\n<?php system(\$_GET['cmd']); ?>");
    expectUpload('PDF executable polyglot rejected', fn() => validatedUpload(['error'=>UPLOAD_ERR_OK,'tmp_name'=>$temporary,'name'=>'invoice.pdf'], $allowed, 1024, false), false);
    file_put_contents($temporary, "%PDF-1.4\n1 0 obj <</OpenAction <</S /JavaScript>>>> endobj\n%%EOF\n");
    expectUpload('active JavaScript PDF rejected', fn() => validatedUpload(['error'=>UPLOAD_ERR_OK,'tmp_name'=>$temporary,'name'=>'invoice.pdf'], $allowed, 1024, false), false);
    expectUpload('path traversal in private directory rejected', fn() => ensurePrivateDirectory('../public'), false);
    if (!preg_match('/^[a-f0-9]{48}\.pdf$/', $valid['stored_name'])) throw new RuntimeException('FAIL generated filename is not random');
    echo "PASS generated filename is random and server-controlled\n";
    $documentRoot = realpath((string)($_SERVER['DOCUMENT_ROOT'] ?? dirname(__DIR__)));
    $storageRoot = privateStorageRoot();
    if ($documentRoot !== false && str_starts_with($storageRoot, $documentRoot . DIRECTORY_SEPARATOR)) throw new RuntimeException('FAIL default storage is under the web root');
    echo "PASS private storage is outside the web root\n";
} finally {
    @unlink($temporary);
}

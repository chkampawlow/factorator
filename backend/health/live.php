<?php

header('Content-Type: application/json; charset=UTF-8');
header('Cache-Control: no-store');

echo json_encode([
    'status'=>'UP',
    'service'=>'el-fatoura-api',
    'timestamp'=>(new DateTimeImmutable('now',new DateTimeZone('UTC')))->format(DateTimeInterface::ATOM),
], JSON_UNESCAPED_SLASHES);

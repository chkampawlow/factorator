<?php
declare(strict_types=1);

http_response_code(404);
header('Content-Type: application/json; charset=UTF-8');
header('Cache-Control: no-store');
echo json_encode(['success' => false, 'message' => 'Not found']);

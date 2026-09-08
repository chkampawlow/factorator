<?php
http_response_code(404);
header('Content-Type: application/json; charset=UTF-8');
echo json_encode(['success'=>false,'message'=>'Not found']);

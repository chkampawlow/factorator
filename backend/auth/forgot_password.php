<?php

ini_set('display_errors', '0');
ini_set('display_startup_errors', '0');
ini_set('log_errors', '1');
error_reporting(E_ALL);

header('Content-Type: application/json');

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/audit.php';

require_once __DIR__ . '/../mailer/mailer.php';
require_once __DIR__ . '/../config/rate_limit.php';



try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        jsonResponse([
            'success' => false,
            'message' => 'Method not allowed. Use POST.'
        ], 405);
        exit;
    }

    $data = json_decode(file_get_contents('php://input'), true);

    if (!is_array($data)) {
        throw new Exception('Invalid JSON body.');
    }

    $email = strtolower(trim($data['email'] ?? ''));
    $language = trim($data['language'] ?? 'en');

    if ($email === '' || filter_var($email, FILTER_VALIDATE_EMAIL) === false) {
        throw new DomainException('A valid email is required.');
    }
    enforceRateLimit('forgot_password', $email, 5, 60 * 60);

    $conn = db();

    $stmt = $conn->prepare('SELECT id, email FROM users WHERE email = ? LIMIT 1');

    if (!$stmt) {
        throw new Exception('Prepare failed (select user): ' . $conn->error);
    }

    $stmt->bind_param('s', $email);
    $stmt->execute();
    $user = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    // Always return success for security
    if (!$user) {
        jsonResponse([
            'success' => true,
            'message' => 'If email exists, code sent'
        ]);
        exit;
    }

    $userId = (int) $user['id'];

    $code = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
    $hash = hash('sha256', $code);
    $expires = date('Y-m-d H:i:s', time() + 600);
    $type = 'password_reset';

    $conn->begin_transaction();
    $del = $conn->prepare('DELETE FROM user_tokens WHERE user_id = ? AND type = ?');

    if (!$del) {
        throw new Exception('Prepare failed (delete old tokens): ' . $conn->error);
    }

    $del->bind_param('is', $userId, $type);
    $del->execute();
    $del->close();

    $ins = $conn->prepare(
        'INSERT INTO user_tokens (user_id, token_hash, expires_at, type, attempts)
         VALUES (?, ?, ?, ?, 0)'
    );

    if (!$ins) {
        throw new Exception('Prepare failed (insert token): ' . $conn->error);
    }

    $ins->bind_param('isss', $userId, $hash, $expires, $type);
    $ins->execute();
    $ins->close();
    $conn->commit();

    try {
        sendResetCode($user['email'], $code, $language);
    } catch (Throwable $mailError) {
        try {
            auditLog($conn, null, null, 'EMAIL.FAILED', 'PASSWORD_RESET', $userId, null, [
                'channel' => 'PASSWORD_RESET',
                'recipient_hash' => hash('sha256', (string)$user['email']),
                'language' => $language,
                'error_class' => get_class($mailError),
            ], 'MAILER');
        } catch (Throwable $ignored) {
        }
        throw $mailError;
    }

    try {
        auditLog($conn, null, null, 'EMAIL.SENT', 'PASSWORD_RESET', $userId, null, [
            'channel' => 'PASSWORD_RESET',
            'recipient_hash' => hash('sha256', (string)$user['email']),
            'language' => $language,
        ], 'MAILER');
    } catch (Throwable $ignored) {
    }

    jsonResponse([
        'success' => true,
        'message' => 'If email exists, code sent'
    ]);
} catch (DomainException $e) {
    jsonResponse(['success' => false, 'message' => $e->getMessage()], 422);
} catch (Throwable $e) {
    if (isset($conn) && $conn instanceof mysqli) {
        try { $conn->rollback(); } catch (Throwable $ignored) {}
    }
    structuredLog('ERROR','AUTH.PASSWORD_RESET_REQUEST_ERROR',['exception'=>get_class($e),'message'=>$e->getMessage()]);
    jsonResponse([
        'success' => false,
        'message' => 'Unable to process the password reset request right now.'
    ], 500);
}

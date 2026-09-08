<?php

declare(strict_types=1);

ini_set('display_errors', '0');
ini_set('display_startup_errors', '0');
ini_set('log_errors', '1');
error_reporting(E_ALL);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, private');

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/rate_limit.php';
require_once __DIR__ . '/../config/audit.php';

require_once __DIR__ . '/auth_required.php';
require_once __DIR__ . '/role_helper.php';

require_once __DIR__ . '/../mailer/mailer.php';

try {

    /*
    |--------------------------------------------------------------------------
    | Method
    |--------------------------------------------------------------------------
    */

    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {

        jsonResponse([
            'success' => false,
            'message' => 'Method not allowed. Use POST.',
            'code' => 'METHOD_NOT_ALLOWED',
        ], 405);
    }


    /*
    |--------------------------------------------------------------------------
    | Authentication
    |--------------------------------------------------------------------------
    |
    | true allows an authenticated account that has not verified its
    | email yet to access this endpoint.
    |--------------------------------------------------------------------------
    */

    $authUser = requireAuth(true);

    $userId = authActorId($authUser);
    $companyId = authTenantId($authUser);

    if ($userId <= 0) {
        throw new RuntimeException(
            'Authenticated user ID is invalid.'
        );
    }


    /*
    |--------------------------------------------------------------------------
    | Rate limit
    |--------------------------------------------------------------------------
    */

    enforceRateLimit(
        'send_verification_email',
        (string)$userId,
        50,
        60 * 60
    );


    /*
    |--------------------------------------------------------------------------
    | Request
    |--------------------------------------------------------------------------
    */

    $rawBody = file_get_contents('php://input');

    $data = json_decode(
        $rawBody ?: '{}',
        true
    );

    if (!is_array($data)) {
        $data = [];
    }


    /*
    |--------------------------------------------------------------------------
    | Language
    |--------------------------------------------------------------------------
    */

    $language = strtolower(
        trim(
            (string)(
                $data['language']
                ?? 'en'
            )
        )
    );

    if (!in_array(
        $language,
        ['en', 'fr', 'ar'],
        true
    )) {
        $language = 'en';
    }


    /*
    |--------------------------------------------------------------------------
    | Database
    |--------------------------------------------------------------------------
    */

    $conn = db();


    /*
    |--------------------------------------------------------------------------
    | Find current user
    |--------------------------------------------------------------------------
    */

    $stmt = $conn->prepare(
        '
        SELECT
            id,
            email,
            email_verified_at
        FROM users
        WHERE id = ?
        LIMIT 1
        '
    );

    if (!$stmt) {
        throw new RuntimeException(
            'Prepare failed while loading user: '
            . $conn->error
        );
    }

    $stmt->bind_param(
        'i',
        $userId
    );

    $stmt->execute();

    $user = $stmt
        ->get_result()
        ->fetch_assoc();

    $stmt->close();


    if (!$user) {
        throw new RuntimeException(
            'User not found.'
        );
    }


    /*
    |--------------------------------------------------------------------------
    | Validate email
    |--------------------------------------------------------------------------
    */

    $email = strtolower(
        trim(
            (string)(
                $user['email']
                ?? ''
            )
        )
    );

    if (!filter_var(
        $email,
        FILTER_VALIDATE_EMAIL
    )) {
        throw new RuntimeException(
            'The account does not have a valid email address.'
        );
    }


    /*
    |--------------------------------------------------------------------------
    | Already verified
    |--------------------------------------------------------------------------
    */

    if (!empty(
        $user['email_verified_at']
    )) {

        jsonResponse([
            'success' => true,
            'message' => 'Email already verified.',
            'verified' => true,
        ], 200);
    }


    /*
    |--------------------------------------------------------------------------
    | Generate code
    |--------------------------------------------------------------------------
    */

    $code = str_pad(
        (string)random_int(
            0,
            999999
        ),
        6,
        '0',
        STR_PAD_LEFT
    );

    /*
     * Never store the real verification code.
     */
    $tokenHash = hash(
        'sha256',
        $code
    );

    $expiresAt = date(
        'Y-m-d H:i:s',
        time() + 600
    );

    $type =
        'email_verification';


    /*
    |--------------------------------------------------------------------------
    | Transaction
    |--------------------------------------------------------------------------
    */

    $conn->begin_transaction();

    try {

        /*
        |--------------------------------------------------------------------------
        | Delete previous verification codes
        |--------------------------------------------------------------------------
        */

        $deleteStmt = $conn->prepare(
            '
            DELETE FROM user_tokens
            WHERE
                user_id = ?
                AND type = ?
            '
        );

        if (!$deleteStmt) {
            throw new RuntimeException(
                'Prepare failed while deleting previous verification code: '
                . $conn->error
            );
        }

        $deleteStmt->bind_param(
            'is',
            $userId,
            $type
        );

        $deleteStmt->execute();

        $deleteStmt->close();


        /*
        |--------------------------------------------------------------------------
        | Insert new verification code
        |--------------------------------------------------------------------------
        */

        $insertStmt = $conn->prepare(
            '
            INSERT INTO user_tokens
            (
                user_id,
                token_hash,
                expires_at,
                type,
                attempts
            )
            VALUES
            (
                ?,
                ?,
                ?,
                ?,
                0
            )
            '
        );

        if (!$insertStmt) {
            throw new RuntimeException(
                'Prepare failed while creating verification code: '
                . $conn->error
            );
        }

        $insertStmt->bind_param(
            'isss',
            $userId,
            $tokenHash,
            $expiresAt,
            $type
        );

        $insertStmt->execute();

        $insertStmt->close();


        /*
         * Save token before sending email.
         */
        $conn->commit();

    } catch (Throwable $databaseError) {

        try {
            $conn->rollback();
        } catch (Throwable $ignored) {
        }

        throw $databaseError;
    }


    /*
    |--------------------------------------------------------------------------
    | Verify mailer
    |--------------------------------------------------------------------------
    */

    if (!function_exists(
        'sendVerificationCode'
    )) {
        throw new RuntimeException(
            'sendVerificationCode() is not available from mailer.php.'
        );
    }


    /*
    |--------------------------------------------------------------------------
    | Send verification email
    |--------------------------------------------------------------------------
    |
    | This uses the SAME mailer.php / PHPMailer configuration that already
    | works for your PDF and invitation emails.
    |--------------------------------------------------------------------------
    */

    try {

        sendVerificationCode(
            $email,
            $code,
            $language
        );

    } catch (Throwable $mailError) {

        try {
            auditLog($conn, $companyId, $userId, 'EMAIL.FAILED', 'EMAIL', $userId, null, [
                'channel' => 'EMAIL_VERIFICATION',
                'recipient_hash' => hash('sha256', $email),
                'language' => $language,
                'error_class' => get_class($mailError),
            ], 'MAILER');
        } catch (Throwable $ignored) {
        }

        if (function_exists(
            'structuredLog'
        )) {

            structuredLog(
                'ERROR',
                'AUTH.VERIFICATION_EMAIL_MAILER_ERROR',
                [
                    'user_id' =>
                        $userId,

                    'exception' =>
                        get_class(
                            $mailError
                        ),

                    'message' =>
                        $mailError
                            ->getMessage(),
                ]
            );
        }


        jsonResponse([
            'success' => false,

            'message' =>
                'The verification code was created, but the email could not be sent.',

            'code' =>
                'VERIFICATION_EMAIL_SEND_FAILED',

        ], 502);
    }

    try {
        auditLog($conn, $companyId, $userId, 'EMAIL.SENT', 'EMAIL', $userId, null, [
            'channel' => 'EMAIL_VERIFICATION',
            'recipient_hash' => hash('sha256', $email),
            'language' => $language,
        ], 'MAILER');
    } catch (Throwable $ignored) {
    }


    /*
    |--------------------------------------------------------------------------
    | Success
    |--------------------------------------------------------------------------
    */

    jsonResponse([
        'success' => true,

        'message' =>
            'Verification email sent.',

        'verified' =>
            false,

        'expires_in_seconds' =>
            600,

    ], 200);


} catch (Throwable $e) {

    /*
    |--------------------------------------------------------------------------
    | Logging
    |--------------------------------------------------------------------------
    */

    if (function_exists(
        'structuredLog'
    )) {

        structuredLog(
            'ERROR',
            'AUTH.VERIFICATION_EMAIL_ERROR',
            [
                'exception' =>
                    get_class($e),

                'message' =>
                    $e->getMessage(),

                'file' =>
                    basename(
                        $e->getFile()
                    ),

                'line' =>
                    $e->getLine(),
            ]
        );
    }


    /*
    |--------------------------------------------------------------------------
    | Error response
    |--------------------------------------------------------------------------
    |
    | Keep debug/file/line while we are fixing the backend.
    | Remove them afterward.
    |--------------------------------------------------------------------------
    */

    jsonResponse([
        'success' => false,

        'message' =>
            'Unable to send the verification email right now.',

        'code' =>
            'VERIFICATION_EMAIL_FAILED',

    ], 500);
}

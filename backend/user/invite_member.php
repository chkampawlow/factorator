<?php

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, private');

ini_set('display_errors', '0');
ini_set('display_startup_errors', '0');
ini_set('log_errors', '1');
error_reporting(E_ALL);

/*
|--------------------------------------------------------------------------
| Dependencies
|--------------------------------------------------------------------------
*/

require_once __DIR__ . '/../config/env.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/audit.php';
require_once __DIR__ . '/../config/validator.php';
require_once __DIR__ . '/../config/rate_limit.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../mailer/mailer.php';
require_once __DIR__ . '/invitation_service.php';

/*
|--------------------------------------------------------------------------
| Load backend/.env
|--------------------------------------------------------------------------
|
| invite_member.php is located in:
|
| backend/user/invite_member.php
|
| Therefore:
|
| __DIR__ . '/../.env'
|
| resolves to:
|
| backend/.env
|--------------------------------------------------------------------------
*/

if (
    empty($_ENV['APP_URL'])
    || empty($_ENV['MAIL_HOST'])
) {
    loadEnv(__DIR__ . '/../.env');
}


/*
|--------------------------------------------------------------------------
| Build application URL
|--------------------------------------------------------------------------
*/

function invitationAppUrl(): string
{
    $appUrl = trim(
        (string)(
            $_ENV['APP_URL']
            ?? getenv('APP_URL')
            ?: 'https://facture.myenv.digital/web'
        )
    );

    if ($appUrl === '') {
        $appUrl = 'https://facture.myenv.digital/web';
    }

    return rtrim($appUrl, '/');
}


/*
|--------------------------------------------------------------------------
| Build invitation acceptance URL
|--------------------------------------------------------------------------
*/

function buildInvitationAcceptanceUrl(string $token): string
{
    $token = trim($token);

    return invitationAppUrl()
        . '/accept-invitation?token='
        . rawurlencode($token);
}


/*
|--------------------------------------------------------------------------
| Send invitation email
|--------------------------------------------------------------------------
*/

function sendCompanyInvitationEmail(
    string $to,
    string $displayName,
    string $role,
    string $acceptanceUrl,
    string $expiresAt,
    string $language = 'en'
): void {

    $language = strtolower(trim($language));

    if (!in_array($language, ['en', 'fr', 'ar'], true)) {
        $language = 'en';
    }

    /*
    |--------------------------------------------------------------------------
    | Make sure existing mailer functions are available
    |--------------------------------------------------------------------------
    */

    if (!function_exists('sendMailMessage')) {
        throw new RuntimeException(
            'sendMailMessage() is missing from mailer.php.'
        );
    }

    if (!function_exists('buildMailTemplate')) {
        throw new RuntimeException(
            'buildMailTemplate() is missing from mailer.php.'
        );
    }

    if (!function_exists('mailTheme')) {
        throw new RuntimeException(
            'mailTheme() is missing from mailer.php.'
        );
    }

    $theme = mailTheme();

    /*
    |--------------------------------------------------------------------------
    | Safe output
    |--------------------------------------------------------------------------
    */

    $safeName = htmlspecialchars(
        $displayName !== ''
            ? $displayName
            : $to,
        ENT_QUOTES | ENT_SUBSTITUTE,
        'UTF-8'
    );

    $safeRole = htmlspecialchars(
        $role,
        ENT_QUOTES | ENT_SUBSTITUTE,
        'UTF-8'
    );

    $safeUrl = htmlspecialchars(
        $acceptanceUrl,
        ENT_QUOTES | ENT_SUBSTITUTE,
        'UTF-8'
    );

    $safeExpires = htmlspecialchars(
        $expiresAt,
        ENT_QUOTES | ENT_SUBSTITUTE,
        'UTF-8'
    );


    /*
    |--------------------------------------------------------------------------
    | French
    |--------------------------------------------------------------------------
    */

    if ($language === 'fr') {

        $title = 'Invitation à rejoindre Factorator';

        $subject =
            'Invitation à rejoindre votre entreprise sur Factorator';

        $intro =
            'Vous avez été invité à rejoindre une entreprise sur Factorator.';

        $nameLabel = 'Nom';
        $roleLabel = 'Rôle';
        $expiresLabel = 'Expiration';

        $buttonText = 'Accepter l’invitation';

        $ignoreText =
            'Si vous ne vous attendiez pas à recevoir cette invitation, vous pouvez ignorer cet email.';


    /*
    |--------------------------------------------------------------------------
    | Arabic
    |--------------------------------------------------------------------------
    */

    } elseif ($language === 'ar') {

        $title = 'دعوة للانضمام إلى Factorator';

        $subject =
            'دعوة للانضمام إلى Factorator';

        $intro =
            'لقد تمت دعوتك للانضمام إلى شركة على Factorator.';

        $nameLabel = 'الاسم';
        $roleLabel = 'الدور';
        $expiresLabel = 'انتهاء الدعوة';

        $buttonText = 'قبول الدعوة';

        $ignoreText =
            'إذا لم تكن تتوقع هذه الدعوة، يمكنك تجاهل هذا البريد الإلكتروني.';


    /*
    |--------------------------------------------------------------------------
    | English
    |--------------------------------------------------------------------------
    */

    } else {

        $title =
            'Invitation to join Factorator';

        $subject =
            'You have been invited to join Factorator';

        $intro =
            'You have been invited to join a company workspace on Factorator.';

        $nameLabel = 'Name';
        $roleLabel = 'Role';
        $expiresLabel = 'Expires';

        $buttonText =
            'Accept invitation';

        $ignoreText =
            'If you were not expecting this invitation, you can safely ignore this email.';
    }


    /*
    |--------------------------------------------------------------------------
    | Email body
    |--------------------------------------------------------------------------
    */

    $bodyHtml = "

        <p style=\"
            margin:0 0 20px 0;
            font-size:15px;
            line-height:1.8;
        \">
            {$intro}
        </p>


        <div style=\"
            margin:20px 0;
            padding:20px;
            background:{$theme['soft']};
            border:1px solid {$theme['border']};
            border-radius:18px;
        \">

            <div style=\"
                margin-bottom:6px;
                color:{$theme['muted']};
                font-size:13px;
            \">
                {$nameLabel}
            </div>

            <div style=\"
                margin-bottom:18px;
                color:{$theme['text']};
                font-size:18px;
                font-weight:800;
            \">
                {$safeName}
            </div>


            <div style=\"
                margin-bottom:6px;
                color:{$theme['muted']};
                font-size:13px;
            \">
                {$roleLabel}
            </div>

            <div style=\"
                margin-bottom:18px;
                color:{$theme['text']};
                font-size:16px;
                font-weight:700;
            \">
                {$safeRole}
            </div>


            <div style=\"
                margin-bottom:6px;
                color:{$theme['muted']};
                font-size:13px;
            \">
                {$expiresLabel}
            </div>

            <div style=\"
                color:{$theme['text']};
                font-size:15px;
            \">
                {$safeExpires}
            </div>

        </div>


        <div style=\"
            margin:30px 0;
            text-align:center;
        \">

            <a
                href=\"{$safeUrl}\"
                style=\"
                    display:inline-block;
                    padding:15px 28px;
                    background:{$theme['primary']};
                    color:#ffffff;
                    text-decoration:none;
                    border-radius:12px;
                    font-size:15px;
                    font-weight:800;
                \"
            >
                {$buttonText}
            </a>

        </div>


        <div style=\"
            margin:22px 0;
            padding:14px;
            background:{$theme['soft']};
            border:1px solid {$theme['border']};
            border-radius:12px;
            word-break:break-all;
            font-size:12px;
            color:{$theme['muted']};
        \">
            {$safeUrl}
        </div>


        <p style=\"
            margin:20px 0 0 0;
            color:{$theme['muted']};
            font-size:13px;
            line-height:1.7;
        \">
            {$ignoreText}
        </p>

    ";


    /*
    |--------------------------------------------------------------------------
    | Send using existing PHPMailer service
    |--------------------------------------------------------------------------
    */

    sendMailMessage(
        $to,
        $subject,
        buildMailTemplate(
            $language,
            $title,
            $bodyHtml
        )
    );
}


/*
|--------------------------------------------------------------------------
| Main endpoint
|--------------------------------------------------------------------------
*/

try {

    /*
    |--------------------------------------------------------------------------
    | Request method
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
    */

    $auth = requireAuth();

    $conn = db();

    $companyId = authTenantId($auth);
    $actorId = authActorId($auth);

    requireAdministratorRole(
        $conn,
        $companyId
    );


    /*
    |--------------------------------------------------------------------------
    | Request body
    |--------------------------------------------------------------------------
    */

    $data = requireJsonBody();


    /*
    |--------------------------------------------------------------------------
    | Email
    |--------------------------------------------------------------------------
    */

    $email = normalizeInvitationEmail(
        (string)($data['email'] ?? '')
    );


    /*
    |--------------------------------------------------------------------------
    | Employee name
    |--------------------------------------------------------------------------
    */

    $displayName = trim(
        (string)(
            $data['display_name']
            ?? $data['name']
            ?? ''
        )
    );


    /*
    |--------------------------------------------------------------------------
    | Role
    |--------------------------------------------------------------------------
    */

    $role = strtoupper(
        trim(
            (string)($data['role'] ?? '')
        )
    );


    /*
    |--------------------------------------------------------------------------
    | Expiration
    |--------------------------------------------------------------------------
    */

    $expiresInHours = array_key_exists(
        'expires_in_hours',
        $data
    )
        ? (int)$data['expires_in_hours']
        : 72;


    /*
    |--------------------------------------------------------------------------
    | Language
    |--------------------------------------------------------------------------
    */

    $language = strtolower(
        trim(
            (string)($data['language'] ?? 'en')
        )
    );

    if (
        !in_array(
            $language,
            ['en', 'fr', 'ar'],
            true
        )
    ) {
        $language = 'en';
    }


    /*
    |--------------------------------------------------------------------------
    | Rate limiting
    |--------------------------------------------------------------------------
    */

    enforceRateLimit(
        'invite_member_company',
        (string)$companyId,
        30,
        60 * 60
    );

    enforceRateLimit(
        'invite_member_address',
        $companyId . '|' . $email,
        10,
        60 * 60
    );


    /*
    |--------------------------------------------------------------------------
    | Create invitation
    |--------------------------------------------------------------------------
    */

    $conn->begin_transaction();

    $invitation = createCompanyInvitation(
        $conn,
        $companyId,
        $actorId,
        $email,
        $displayName,
        $role,
        $expiresInHours
    );

    $conn->commit();


    /*
    |--------------------------------------------------------------------------
    | Build acceptance URL
    |--------------------------------------------------------------------------
    */

    $acceptanceUrl =
        buildInvitationAcceptanceUrl(
            (string)$invitation['token']
        );


    /*
    |--------------------------------------------------------------------------
    | Send invitation email
    |--------------------------------------------------------------------------
    */

    try {

        sendCompanyInvitationEmail(
            $email,
            $displayName,
            normalizeUserRole(
                $invitation['role']
                ?? null
            ),
            $acceptanceUrl,
            (string)$invitation['expires_at'],
            $language
        );

    } catch (Throwable $mailError) {

        try {
            auditLog($conn, $companyId, $actorId, 'EMAIL.FAILED', 'COMPANY_INVITATION', (int)$invitation['id'], null, [
                'channel' => 'COMPANY_INVITATION',
                'recipient_hash' => hash('sha256', $email),
                'language' => $language,
                'error_class' => get_class($mailError),
            ], 'MAILER');
        } catch (Throwable $ignored) {
        }

        /*
         * The invitation has already been committed.
         * Do NOT roll it back here.
         */

        if (function_exists('structuredLog')) {

            structuredLog(
                'ERROR',
                'MEMBERSHIP.INVITATION_EMAIL_ERROR',
                [
                    'company_id' =>
                        $companyId,

                    'actor_id' =>
                        $actorId,

                    'invitation_id' =>
                        (int)$invitation['id'],

                    'email_hash' =>
                        hash(
                            'sha256',
                            $email
                        ),

                    'exception' =>
                        get_class($mailError),

                    'message' =>
                        $mailError->getMessage(),
                ]
            );
        }

        jsonResponse([
            'success' => false,

            'message' =>
                'The invitation was created, but the email could not be sent.',

            'code' =>
                'INVITATION_EMAIL_FAILED',

            'invitation' => [
                'id' =>
                    (int)$invitation['id'],

                'email' =>
                    (string)$invitation['email'],

                'status' =>
                    'PENDING',

                'expires_at' =>
                    $invitation['expires_at'],
            ],

        ], 502);
    }

    try {
        auditLog($conn, $companyId, $actorId, 'EMAIL.SENT', 'COMPANY_INVITATION', (int)$invitation['id'], null, [
            'channel' => 'COMPANY_INVITATION',
            'recipient_hash' => hash('sha256', $email),
            'language' => $language,
        ], 'MAILER');
    } catch (Throwable $ignored) {
    }


    /*
    |--------------------------------------------------------------------------
    | Response
    |--------------------------------------------------------------------------
    */

    $payload = [

        'success' =>
            true,

        'message' =>
            'Employee invitation created and email sent successfully.',

        'invitation' => [

            'id' =>
                (int)$invitation['id'],

            'email' =>
                (string)$invitation['email'],

            'display_name' =>
                (string)(
                    $invitation['display_name']
                    ?? ''
                ),

            'role' =>
                normalizeUserRole(
                    $invitation['role']
                    ?? null
                ),

            'status' =>
                'PENDING',

            'expires_at' =>
                $invitation['expires_at'],

            'created_at' =>
                $invitation['created_at'],
        ],

        'delivery' => [

            'status' =>
                'EMAIL_SENT',

            'message' =>
                'Invitation email sent successfully.',
        ],
    ];


    /*
    |--------------------------------------------------------------------------
    | Development information
    |--------------------------------------------------------------------------
    |
    | Never expose this token in production.
    |--------------------------------------------------------------------------
    */

    if (
        function_exists('invitationEnvironment')
        && invitationEnvironment() === 'development'
    ) {

        $payload['development'] = [

            'acceptance_token' =>
                (string)$invitation['token'],

            'acceptance_url' =>
                $acceptanceUrl,

            'expires_at' =>
                $invitation['expires_at'],
        ];
    }


    /*
    |--------------------------------------------------------------------------
    | Successful response
    |--------------------------------------------------------------------------
    */

    jsonResponse(
        $payload,
        201
    );


/*
|--------------------------------------------------------------------------
| Invitation-specific errors
|--------------------------------------------------------------------------
*/

} catch (CompanyInvitationException $e) {

    if (
        isset($conn)
        && $conn instanceof mysqli
    ) {

        try {
            $conn->rollback();
        } catch (Throwable $ignored) {
        }
    }

    jsonResponse([
        'success' =>
            false,

        'message' =>
            $e->getMessage(),

        'code' =>
            $e->errorCode,

    ], $e->httpStatus);


/*
|--------------------------------------------------------------------------
| Input errors
|--------------------------------------------------------------------------
*/

} catch (InvalidArgumentException $e) {

    if (
        isset($conn)
        && $conn instanceof mysqli
    ) {

        try {
            $conn->rollback();
        } catch (Throwable $ignored) {
        }
    }

    jsonResponse([
        'success' =>
            false,

        'message' =>
            $e->getMessage(),

        'code' =>
            'INVALID_INVITATION_DATA',

    ], 422);


/*
|--------------------------------------------------------------------------
| Everything else
|--------------------------------------------------------------------------
*/

} catch (Throwable $e) {

    if (
        isset($conn)
        && $conn instanceof mysqli
    ) {

        try {
            $conn->rollback();
        } catch (Throwable $ignored) {
        }
    }

    if (function_exists('structuredLog')) {

        structuredLog(
            'ERROR',
            'MEMBERSHIP.INVITATION_CREATE_ERROR',
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

    jsonResponse([
        'success' =>
            false,

        'message' =>
            'Unable to create the invitation right now.',

        'code' =>
            'INVITATION_CREATE_FAILED',

    ], 500);
}

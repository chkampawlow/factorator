<?php

declare(strict_types=1);

final class BackgroundJobIdempotencyConflict extends RuntimeException
{
}

/**
 * Make sure the background jobs table exists and is reachable.
 */
function ensureBackgroundJobSchema(mysqli $conn): void
{
    $conn->query(
        'SELECT id,status FROM erp_background_jobs LIMIT 0'
    );
}


/**
 * List of background job types accepted by the application.
 */
function backgroundJobTypeAllowed(string $jobType): bool
{
    $jobType = strtoupper(trim($jobType));

    return in_array(
        $jobType,
        [
            'EMAIL_DOCUMENT',
            'EMAIL_INVITATION',
            'REPORT_EXPORT',
            'REPORT_RECONCILIATION',
            'SYSTEM_TEST',
        ],
        true
    );
}


/**
 * XAMPP/local development has no process supervisor.
 *
 * During development, an HTTP request can start a short-lived worker.
 *
 * On staging/production this should normally be replaced by a managed
 * long-running worker using Supervisor, systemd, Docker, etc.
 */
function kickDevelopmentBackgroundWorker(): bool
{
    $environment = strtolower(
        trim(
            (string)(
                $_ENV['APP_ENV']
                ?? getenv('APP_ENV')
                ?: ''
            )
        )
    );

    /*
     * Only automatically start workers during local development.
     *
     * Also don't start another worker from inside a CLI worker.
     */
    if (
        $environment !== 'development'
        || PHP_SAPI === 'cli'
    ) {
        return false;
    }


    /*
     * Find PHP binary.
     */
    $php =
        PHP_BINDIR
        . DIRECTORY_SEPARATOR
        . 'php';


    /*
     * Worker script.
     */
    $worker =
        dirname(__DIR__)
        . DIRECTORY_SEPARATOR
        . 'bin'
        . DIRECTORY_SEPARATOR
        . 'run_job_worker.php';


    /*
     * Validate requirements.
     */
    if (
        !is_file($php)
        || !is_executable($php)
        || !is_file($worker)
        || !function_exists('exec')
    ) {
        return false;
    }


    /*
     * exec() may be disabled by hosting configuration.
     */
    $disabled = array_filter(
        array_map(
            'trim',
            explode(
                ',',
                (string)ini_get('disable_functions')
            )
        )
    );

    if (
        in_array(
            'exec',
            $disabled,
            true
        )
    ) {
        return false;
    }


    /*
     * Start worker in background.
     *
     * It stops automatically after 60 seconds of inactivity.
     */
    $command =
        escapeshellarg($php)
        . ' '
        . escapeshellarg($worker)
        . ' --idle-timeout=60 > /dev/null 2>&1 &';


    exec($command);

    return true;
}


/**
 * Queue a new background job.
 *
 * The idempotency key prevents duplicate jobs.
 */
function queueBackgroundJob(
    mysqli $conn,
    int $userId,
    int $actorId,
    string $jobType,
    array $payload,
    string $idempotencyKey,
    int $maxAttempts = 3
): array {

    ensureBackgroundJobSchema($conn);


    /*
     * Normalize.
     */
    $jobType = strtoupper(
        trim($jobType)
    );

    $idempotencyKey = trim(
        $idempotencyKey
    );


    /*
     * Validate basic arguments.
     */
    if (
        $userId <= 0
        || $actorId <= 0
        || !backgroundJobTypeAllowed($jobType)
    ) {
        throw new InvalidArgumentException(
            'Invalid background job request.'
        );
    }


    /*
     * Validate idempotency key.
     */
    if (
        !preg_match(
            '/^[A-Za-z0-9._:-]{8,128}$/',
            $idempotencyKey
        )
    ) {
        throw new InvalidArgumentException(
            'A valid idempotency key is required.'
        );
    }


    /*
     * Encode job payload.
     */
    $payloadJson = json_encode(
        $payload,
        JSON_UNESCAPED_UNICODE
        | JSON_UNESCAPED_SLASHES
        | JSON_THROW_ON_ERROR
    );


    /*
     * Protect the job table from oversized payloads.
     */
    if (
        strlen($payloadJson) > 65535
    ) {
        throw new InvalidArgumentException(
            'Background job payload is too large.'
        );
    }


    /*
     * Hash the payload.
     *
     * This allows us to verify that the same idempotency key
     * hasn't been reused for a completely different request.
     */
    $requestHash = hash(
        'sha256',
        $payloadJson
    );


    /*
     * Limit retry attempts.
     */
    $maxAttempts = min(
        5,
        max(
            1,
            $maxAttempts
        )
    );


    /*
     * Insert job.
     *
     * If idempotency_key already exists:
     * LAST_INSERT_ID(id) gives us the existing job ID.
     */
    $stmt = $conn->prepare(
        '
        INSERT INTO erp_background_jobs(
            user_id,
            created_by,
            job_type,
            payload_json,
            request_hash,
            idempotency_key,
            max_attempts
        )
        VALUES(
            ?,?,?,?,?,?,?
        )
        ON DUPLICATE KEY UPDATE
            id = LAST_INSERT_ID(id)
        '
    );


    $stmt->bind_param(
        'iissssi',
        $userId,
        $actorId,
        $jobType,
        $payloadJson,
        $requestHash,
        $idempotencyKey,
        $maxAttempts
    );


    $stmt->execute();


    $jobId = (int)$conn->insert_id;


    $stmt->close();


    /*
     * Fetch resulting job.
     */
    $stmt = $conn->prepare(
        '
        SELECT
            id,
            user_id,
            job_type,
            status,
            request_hash,
            attempts,
            max_attempts,
            progress,
            created_at
        FROM erp_background_jobs
        WHERE
            id = ?
            AND user_id = ?
        LIMIT 1
        '
    );


    $stmt->bind_param(
        'ii',
        $jobId,
        $userId
    );


    $stmt->execute();


    $job =
        $stmt
            ->get_result()
            ->fetch_assoc();


    $stmt->close();


    /*
     * Validate idempotency consistency.
     */
    if (
        !$job
        || !hash_equals(
            (string)$job['request_hash'],
            $requestHash
        )
    ) {
        throw new BackgroundJobIdempotencyConflict(
            'The idempotency key was already used for a different job request.'
        );
    }


    return $job;
}


/**
 * Get a background job belonging to one tenant/company.
 */
function backgroundJobForTenant(
    mysqli $conn,
    int $userId,
    int $jobId
): ?array {

    $stmt = $conn->prepare(
        '
        SELECT
            id,
            created_by,
            job_type,
            status,
            attempts,
            max_attempts,
            progress,
            available_at,
            started_at,
            completed_at,
            error_code,
            error_message,
            result_json,
            created_at,
            updated_at
        FROM erp_background_jobs
        WHERE
            id = ?
            AND user_id = ?
        LIMIT 1
        '
    );


    $stmt->bind_param(
        'ii',
        $jobId,
        $userId
    );


    $stmt->execute();


    $job =
        $stmt
            ->get_result()
            ->fetch_assoc()
        ?: null;


    $stmt->close();


    if (!$job) {
        return null;
    }


    /*
     * Decode job result.
     */
    $result = json_decode(
        (string)($job['result_json'] ?? ''),
        true
    );


    /*
     * Never expose raw result_json.
     */
    unset(
        $job['result_json']
    );


    /*
     * REPORT EXPORT
     */
    if (
        (string)$job['job_type']
            === 'REPORT_EXPORT'
        && (string)$job['status']
            === 'COMPLETED'
        && is_array($result)
    ) {

        $job['download_ready'] = true;

        $job['filename'] = basename(
            (string)(
                $result['filename']
                ?? 'report.csv'
            )
        );

        $job['row_count'] = max(
            0,
            (int)(
                $result['row_count']
                ?? 0
            )
        );

        $job['file_size'] = max(
            0,
            (int)(
                $result['size']
                ?? 0
            )
        );

    /*
     * REPORT RECONCILIATION
     */
    } elseif (
        (string)$job['job_type']
            === 'REPORT_RECONCILIATION'
        && (string)$job['status']
            === 'COMPLETED'
        && is_array($result)
    ) {

        $safeChecks = [];


        foreach (
            (array)(
                $result['checks']
                ?? []
            )
            as $check
        ) {

            if (
                !is_array($check)
            ) {
                continue;
            }


            $safeChecks[] = [

                'key' => preg_replace(
                    '/[^a-z0-9_]/',
                    '',
                    strtolower(
                        (string)(
                            $check['key']
                            ?? ''
                        )
                    )
                ),

                'label' => mb_substr(
                    trim(
                        (string)(
                            $check['label']
                            ?? ''
                        )
                    ),
                    0,
                    120
                ),

                'issues' => max(
                    0,
                    (int)(
                        $check['issues']
                        ?? 0
                    )
                ),

                'matches' =>
                    (bool)(
                        $check['matches']
                        ?? false
                    ),
            ];
        }


        $job['reconciliation'] = [

            'checked_at' =>
                (string)(
                    $result['checked_at']
                    ?? ''
                ),

            'checks' =>
                $safeChecks,

            'from' =>
                (string)(
                    $result['from']
                    ?? ''
                ),

            'issue_count' =>
                max(
                    0,
                    (int)(
                        $result['issue_count']
                        ?? 0
                    )
                ),

            'matches' =>
                (bool)(
                    $result['matches']
                    ?? false
                ),

            'to' =>
                (string)(
                    $result['to']
                    ?? ''
                ),
        ];


        $job['download_ready'] = false;


    /*
     * EMAIL INVITATION
     */
    } elseif (
        (string)$job['job_type']
            === 'EMAIL_INVITATION'
        && (string)$job['status']
            === 'COMPLETED'
        && is_array($result)
    ) {

        /*
         * Only expose harmless delivery information.
         *
         * Never expose invitation token from job results.
         */
        $job['delivery'] = [

            'sent' =>
                (bool)(
                    $result['sent']
                    ?? true
                ),

            'email' =>
                (string)(
                    $result['email']
                    ?? ''
                ),

            'sent_at' =>
                (string)(
                    $result['sent_at']
                    ?? ''
                ),
        ];


        $job['download_ready'] = false;


    /*
     * All other job types.
     */
    } else {

        $job['download_ready'] = false;
    }


    return $job;
}


/**
 * Update progress for a running background job.
 */
function updateBackgroundJobProgress(
    mysqli $conn,
    int $jobId,
    int $progress
): void {

    /*
     * 100 is reserved for completed jobs.
     */
    $progress = min(
        99,
        max(
            1,
            $progress
        )
    );


    $stmt = $conn->prepare(
        "
        UPDATE erp_background_jobs
        SET progress = ?
        WHERE
            id = ?
            AND status = 'RUNNING'
        "
    );


    $stmt->bind_param(
        'ii',
        $progress,
        $jobId
    );


    $stmt->execute();

    $stmt->close();
}


/**
 * Claim the next available queued job.
 */
function claimBackgroundJob(
    mysqli $conn,
    string $workerId
): ?array {

    ensureBackgroundJobSchema($conn);


    $conn->begin_transaction();


    try {

        /*
         * Lock one queued job so multiple workers don't process
         * the same job.
         */
        $result = $conn->query(
            "
            SELECT *
            FROM erp_background_jobs
            WHERE
                status = 'QUEUED'
                AND available_at <= NOW()
                AND attempts < max_attempts
            ORDER BY id
            LIMIT 1
            FOR UPDATE
            "
        );


        $job =
            $result->fetch_assoc()
            ?: null;


        $result->close();


        /*
         * Nothing available.
         */
        if (!$job) {

            $conn->commit();

            return null;
        }


        $jobId =
            (int)$job['id'];


        /*
         * Claim the job.
         */
        $stmt = $conn->prepare(
            "
            UPDATE erp_background_jobs
            SET
                status = 'RUNNING',
                attempts = attempts + 1,
                progress = 1,
                locked_at = NOW(),
                locked_by = ?,
                started_at = COALESCE(
                    started_at,
                    NOW()
                ),
                error_code = NULL,
                error_message = NULL
            WHERE
                id = ?
                AND status = 'QUEUED'
            "
        );


        $stmt->bind_param(
            'si',
            $workerId,
            $jobId
        );


        $stmt->execute();


        if (
            $stmt->affected_rows !== 1
        ) {
            throw new RuntimeException(
                'Could not claim background job.'
            );
        }


        $stmt->close();


        $conn->commit();


        /*
         * Update attempt count locally.
         */
        $job['attempts'] =
            (int)$job['attempts']
            + 1;


        /*
         * Decode job payload.
         */
        $job['payload'] = json_decode(
            (string)$job['payload_json'],
            true,
            512,
            JSON_THROW_ON_ERROR
        );


        return $job;


    } catch (Throwable $e) {

        $conn->rollback();

        throw $e;
    }
}


/**
 * Mark a job as completed.
 */
function completeBackgroundJob(
    mysqli $conn,
    int $jobId,
    array $result = []
): void {

    $resultJson = json_encode(
        $result,
        JSON_UNESCAPED_UNICODE
        | JSON_UNESCAPED_SLASHES
        | JSON_THROW_ON_ERROR
    );


    $stmt = $conn->prepare(
        "
        UPDATE erp_background_jobs
        SET
            status = 'COMPLETED',
            progress = 100,
            result_json = ?,
            completed_at = NOW(),
            locked_at = NULL,
            locked_by = NULL
        WHERE
            id = ?
            AND status = 'RUNNING'
        "
    );


    $stmt->bind_param(
        'si',
        $resultJson,
        $jobId
    );


    $stmt->execute();

    $stmt->close();
}


/**
 * Retry or permanently fail a background job.
 */
function failBackgroundJob(
    mysqli $conn,
    array $job,
    Throwable $error
): void {

    $jobId =
        (int)$job['id'];


    $attempts =
        (int)$job['attempts'];


    $maxAttempts =
        (int)$job['max_attempts'];


    /*
     * Safe error message.
     */
    $message = mb_substr(
        trim(
            $error->getMessage()
        )
        ?: 'Background job failed.',
        0,
        500
    );


    /*
     * Job error code.
     */
    $code = preg_replace(
        '/[^A-Z0-9_]/',
        '_',
        strtoupper(
            $error
                instanceof InvalidArgumentException
                    ? 'INVALID_JOB_PAYLOAD'
                    : 'JOB_EXECUTION_FAILED'
        )
    );


    /*
     * Retry if attempts remain.
     */
    if (
        $attempts < $maxAttempts
    ) {

        /*
         * Exponential backoff:
         *
         * attempt 1 -> 15 sec
         * attempt 2 -> 30 sec
         * attempt 3 -> 60 sec
         *
         * max 15 minutes.
         */
        $delaySeconds = min(
            900,
            15 * (
                2 **
                max(
                    0,
                    $attempts - 1
                )
            )
        );


        $stmt = $conn->prepare(
            "
            UPDATE erp_background_jobs
            SET
                status = 'QUEUED',
                progress = 0,
                available_at =
                    DATE_ADD(
                        NOW(),
                        INTERVAL ? SECOND
                    ),
                locked_at = NULL,
                locked_by = NULL,
                error_code = ?,
                error_message = ?
            WHERE
                id = ?
                AND status = 'RUNNING'
            "
        );


        $stmt->bind_param(
            'issi',
            $delaySeconds,
            $code,
            $message,
            $jobId
        );


    /*
     * No retry attempts remain.
     */
    } else {

        $stmt = $conn->prepare(
            "
            UPDATE erp_background_jobs
            SET
                status = 'FAILED',
                progress = 100,
                completed_at = NOW(),
                locked_at = NULL,
                locked_by = NULL,
                error_code = ?,
                error_message = ?
            WHERE
                id = ?
                AND status = 'RUNNING'
            "
        );


        $stmt->bind_param(
            'ssi',
            $code,
            $message,
            $jobId
        );
    }


    $stmt->execute();

    $stmt->close();
}


/**
 * Recover jobs abandoned by a crashed worker.
 */
function recoverStaleBackgroundJobs(
    mysqli $conn,
    int $minutes = 15
): int {

    /*
     * Minimum 5 minutes.
     * Maximum 120 minutes.
     */
    $minutes = min(
        120,
        max(
            5,
            $minutes
        )
    );


    $stmt = $conn->prepare(
        "
        UPDATE erp_background_jobs
        SET
            status =
                IF(
                    attempts < max_attempts,
                    'QUEUED',
                    'FAILED'
                ),

            available_at = NOW(),

            locked_at = NULL,

            locked_by = NULL,

            error_code = 'WORKER_TIMEOUT',

            error_message =
                'The worker stopped before completing this job.'

        WHERE
            status = 'RUNNING'
            AND locked_at <
                DATE_SUB(
                    NOW(),
                    INTERVAL ? MINUTE
                )
        "
    );


    $stmt->bind_param(
        'i',
        $minutes
    );


    $stmt->execute();


    $count =
        $stmt->affected_rows;


    $stmt->close();


    return $count;
}

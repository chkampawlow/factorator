<?php

function runBoundedProcess(array $command, int $timeoutSeconds, int $maxOutputBytes): array
{
    if ($command === [] || $timeoutSeconds < 1 || $maxOutputBytes < 1024) {
        throw new InvalidArgumentException('Invalid process limits.');
    }
    $pipes = [];
    $process = proc_open($command, [
        0 => ['pipe', 'r'], 1 => ['pipe', 'w'], 2 => ['pipe', 'w'],
    ], $pipes, null, null, ['bypass_shell' => true]);
    if (!is_resource($process)) throw new RuntimeException('Could not start the process.');
    fclose($pipes[0]);
    stream_set_blocking($pipes[1], false);
    stream_set_blocking($pipes[2], false);

    $started = microtime(true);
    $output = '';
    $timedOut = false;
    $outputExceeded = false;
    $exitCode = -1;
    try {
        while (true) {
            $status = proc_get_status($process);
            $output .= (string)stream_get_contents($pipes[1]);
            $output .= (string)stream_get_contents($pipes[2]);
            if (strlen($output) > $maxOutputBytes) {
                $outputExceeded = true;
                break;
            }
            if (!$status['running']) {
                $exitCode = (int)$status['exitcode'];
                break;
            }
            if ((microtime(true) - $started) >= $timeoutSeconds) {
                $timedOut = true;
                break;
            }
            usleep(10000);
        }
        if ($timedOut || $outputExceeded) {
            proc_terminate($process);
            usleep(100000);
            $status = proc_get_status($process);
            if ($status['running']) proc_terminate($process, 9);
        }
        $output .= (string)stream_get_contents($pipes[1]);
        $output .= (string)stream_get_contents($pipes[2]);
    } finally {
        foreach ($pipes as $pipe) if (is_resource($pipe)) fclose($pipe);
        $closedCode = proc_close($process);
        if ($exitCode < 0 && $closedCode >= 0) $exitCode = $closedCode;
    }

    return [
        'exitCode' => $timedOut ? 124 : ($outputExceeded ? 125 : $exitCode),
        'output' => substr($output, 0, $maxOutputBytes),
        'timedOut' => $timedOut,
        'outputExceeded' => $outputExceeded,
        'elapsedMs' => (microtime(true) - $started) * 1000,
    ];
}

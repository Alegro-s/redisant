<?php

declare(strict_types=1);


function send_email_via_msmtp(string $to, string $from, string $subject, string $body): bool
{
    $bin = getenv('NEXUS_MSMTP_BIN') ?: '/usr/bin/msmtp';
    if (!is_executable($bin)) {
        return false;
    }
    if (function_exists('mb_encode_mimeheader')) {
        $subjHdr = mb_encode_mimeheader($subject, 'UTF-8', 'B', "\r\n");
    } else {
        $subjHdr = '=?UTF-8?B?' . base64_encode($subject) . '?=';
    }
    $bodyNorm = str_replace(["\r\n", "\r"], "\n", $body);
    $msg = 'From: ' . $from . "\r\n";
    $msg .= 'To: ' . $to . "\r\n";
    $msg .= 'Subject: ' . $subjHdr . "\r\n";
    $msg .= "MIME-Version: 1.0\r\n";
    $msg .= "Content-Type: text/plain; charset=UTF-8\r\n";
    $msg .= "Content-Transfer-Encoding: 8bit\r\n";
    $msg .= "\r\n";
    $msg .= str_replace("\n", "\r\n", $bodyNorm);

    $des = [0 => ['pipe', 'r'], 1 => ['pipe', 'w'], 2 => ['pipe', 'w']];
    $proc = @proc_open([$bin, '-a', 'default', $to], $des, $pipes, null, null);
    if (!is_resource($proc)) {
        return false;
    }
    fwrite($pipes[0], $msg);
    fclose($pipes[0]);
    $out = stream_get_contents($pipes[1]);
    fclose($pipes[1]);
    $err = stream_get_contents($pipes[2]);
    fclose($pipes[2]);
    $exit = proc_close($proc);
    if ($exit !== 0) {
        error_log('msmtp failed exit=' . $exit . ' stderr=' . $err . ' stdout=' . $out);
    }
    return $exit === 0;
}

header('Content-Type: application/json; charset=utf-8');

$secret = getenv('NEXUS_OTP_WEBHOOK_SECRET') ?: '';
if ($secret === '') {
    http_response_code(500);
    echo json_encode(['error' => 'NEXUS_OTP_WEBHOOK_SECRET not set']);
    exit;
}

$hdr = $_SERVER['HTTP_X_NEXUS_WEBHOOK_SECRET'] ?? '';
if (!hash_equals($secret, $hdr)) {
    http_response_code(401);
    echo json_encode(['error' => 'invalid webhook secret']);
    exit;
}

$raw = file_get_contents('php://input') ?: '';
$data = json_decode($raw, true);
if (!is_array($data)) {
    http_response_code(400);
    echo json_encode(['error' => 'invalid json']);
    exit;
}

$channel = $data['channel'] ?? '';
$code = (string)($data['code'] ?? '');
$login = (string)($data['login'] ?? '');
$toEmail = (string)($data['to_email'] ?? '');
$toPhone = (string)($data['to_phone'] ?? '');
$purpose = (string)($data['purpose'] ?? '');
$verifyUrl = (string)($data['verify_url'] ?? '');

if ($purpose === 'waypoint_metric_alert') {
    $toEmail = (string)($data['to_email'] ?? '');
    $subj = (string)($data['alert_subject'] ?? '');
    $body = (string)($data['alert_body'] ?? '');
    if ($toEmail === '' || !filter_var($toEmail, FILTER_VALIDATE_EMAIL)) {
        http_response_code(400);
        echo json_encode(['error' => 'invalid to_email']);
        exit;
    }
    if ($subj === '' || $body === '') {
        http_response_code(400);
        echo json_encode(['error' => 'alert_subject and alert_body required']);
        exit;
    }
    $from = getenv('NEXUS_MAIL_FROM') ?: 'igor-vinogradov04@yandex.ru';
    $ok = send_email_via_msmtp($toEmail, $from, $subj, $body);
    if (!$ok) {
        $headers = "MIME-Version: 1.0\r\nContent-Type: text/plain; charset=UTF-8\r\n";
        $headers .= 'From: ' . $from . "\r\n";
        $ok = @mail($toEmail, $subj, $body, $headers);
    }
    if (!$ok) {
        http_response_code(502);
        echo json_encode([
            'ok' => false,
            'error' => 'waypoint_metric_alert: send failed (msmtp / mail)',
            'mailed' => $toEmail,
        ]);
        exit;
    }
    echo json_encode(['ok' => true, 'purpose' => 'waypoint_metric_alert', 'mailed' => $toEmail]);
    exit;
}

$isEmailVerification = ($purpose === 'email_verification');
$expectedDigits = $isEmailVerification ? 8 : 6;

if ($code === '' || strlen($code) !== $expectedDigits || !ctype_digit($code)) {
    http_response_code(400);
    echo json_encode([
        'error' => $isEmailVerification
            ? 'bad code: expected 8 digits for email_verification'
            : 'bad code: expected 6 digits for login OTP',
    ]);
    exit;
}

if ($channel === 'email') {
    if ($toEmail === '' || !filter_var($toEmail, FILTER_VALIDATE_EMAIL)) {
        http_response_code(400);
        echo json_encode(['error' => 'invalid to_email']);
        exit;
    }
    $from = getenv('NEXUS_MAIL_FROM') ?: 'igor-vinogradov04@yandex.ru';
    $headers = "MIME-Version: 1.0\r\nContent-Type: text/plain; charset=UTF-8\r\n";
    $headers .= 'From: ' . $from . "\r\n";

    if ($isEmailVerification) {
        $subject = 'NEXUS: подтвердите email';
        $body = "Здравствуйте!\n\nКод подтверждения регистрации: {$code}\nЛогин (ник): {$login}\n\n";
        $body .= "Код действителен 24 часа. Без подтверждения вход недоступен.\n";
        if ($verifyUrl !== '') {
            $body .= "\nСтраница ввода кода: {$verifyUrl}\n";
        }
    } else {
        $subject = 'NEXUS: код входа';
        $body = "Здравствуйте!\n\nКод для входа в NEXUS: {$code}\nЛогин: {$login}\n\nКод действителен 10 минут.";
    }

    $ok = send_email_via_msmtp($toEmail, $from, $subject, $body);
    if (!$ok) {
        $ok = @mail($toEmail, $subject, $body, $headers);
    }
    if (!$ok) {
        http_response_code(502);
        echo json_encode([
            'ok' => false,
            'error' => 'отправка не удалась (msmtp и mail(); проверьте msmtp /etc/msmtprc и NEXUS_MAIL_FROM)',
            'channel' => 'email',
            'mailed' => $toEmail,
            'purpose' => $purpose ?: 'login_otp',
        ]);
        exit;
    }
    echo json_encode(['ok' => true, 'channel' => 'email', 'mailed' => $toEmail, 'purpose' => $purpose ?: 'login_otp']);
    exit;
}

if ($channel === 'sms') {
    if ($isEmailVerification) {
        http_response_code(400);
        echo json_encode(['error' => 'email_verification is email-only']);
        exit;
    }
    $logFile = __DIR__ . '/sms-out.log';
    $line = date('c') . " to={$toPhone} code={$code} login={$login}\n";
    file_put_contents($logFile, $line, FILE_APPEND);
    echo json_encode(['ok' => true, 'channel' => 'sms', 'logged' => basename($logFile)]);
    exit;
}

if ($channel === 'nexus') {
    if ($isEmailVerification) {
        http_response_code(400);
        echo json_encode(['error' => 'email_verification is email-only']);
        exit;
    }
    echo json_encode(['ok' => true, 'channel' => 'nexus']);
    exit;
}

http_response_code(400);
echo json_encode(['error' => 'unknown channel']);

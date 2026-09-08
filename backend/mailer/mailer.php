<?php

require_once __DIR__ . '/../vendor/autoload.php';
require_once __DIR__ . '/../config/env.php';

use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;

if (empty($_ENV['MAIL_HOST'])) {
    loadEnv(__DIR__ . '/../.env');
}

function normalizeMailLanguage(?string $language): string
{
    $lang = strtolower(trim((string)($language ?? 'en')));
    return in_array($lang, ['en', 'fr', 'ar'], true) ? $lang : 'en';
}

function mailTheme(): array
{
    return [
        'primary' => '#16B39A',
        'primaryDark' => '#10937E',
        'background' => '#F4F7FB',
        'surface' => '#FFFFFF',
        'text' => '#111827',
        'muted' => '#6B7280',
        'border' => '#E5E7EB',
        'soft' => '#F8FAFC',
        'codeBg' => '#F1F5F9',
    ];
}

function mailCopy(string $language): array
{
    switch (normalizeMailLanguage($language)) {
        case 'fr':
            return [
                'appName' => 'Factorator',
                'tagline' => 'Votre application intelligente de facturation',
                'hello' => 'Bonjour,',
                'verificationTitle' => 'Vérification de l’email',
                'verificationIntro' => 'Utilisez le code suivant pour vérifier votre adresse email :',
                'verificationExpiry' => 'Ce code expire dans 10 minutes.',
                'resetTitle' => 'Réinitialisation du mot de passe',
                'resetIntro' => 'Utilisez le code suivant pour réinitialiser votre mot de passe :',
                'resetExpiry' => 'Ce code expire dans 10 minutes.',
                'invoiceTitle' => 'Votre facture est prête',
                'invoiceIntro' => 'Veuillez trouver votre facture en pièce jointe.',
                'purchaseOrderTitle' => 'Votre bon de commande est prêt',
                'purchaseOrderIntro' => 'Veuillez trouver votre bon de commande fournisseur en pièce jointe.',
                'footer' => 'Cet email a été envoyé automatiquement par Factorator.',
                'verificationSubject' => 'Vérifiez votre email',
                'resetSubject' => 'Réinitialisez votre mot de passe',
                'invoiceSubject' => 'Votre facture PDF',
                'purchaseOrderSubject' => 'Votre bon de commande PDF',
            ];
        case 'ar':
            return [
                'appName' => 'Factorator',
                'tagline' => 'تطبيقك الذكي للفوترة',
                'hello' => 'مرحباً،',
                'verificationTitle' => 'تأكيد البريد الإلكتروني',
                'verificationIntro' => 'استخدم الرمز التالي لتأكيد بريدك الإلكتروني:',
                'verificationExpiry' => 'تنتهي صلاحية هذا الرمز خلال 10 دقائق.',
                'resetTitle' => 'إعادة تعيين كلمة المرور',
                'resetIntro' => 'استخدم الرمز التالي لإعادة تعيين كلمة المرور:',
                'resetExpiry' => 'تنتهي صلاحية هذا الرمز خلال 10 دقائق.',
                'invoiceTitle' => 'فاتورتك جاهزة',
                'invoiceIntro' => 'يرجى العثور على الفاتورة مرفقة مع هذا البريد.',
                'purchaseOrderTitle' => 'أمر الشراء الخاص بك جاهز',
                'purchaseOrderIntro' => 'يرجى العثور على أمر الشراء مرفقًا مع هذا البريد.',
                'footer' => 'تم إرسال هذا البريد الإلكتروني تلقائياً من خلال Factorator.',
                'verificationSubject' => 'تأكيد البريد الإلكتروني',
                'resetSubject' => 'إعادة تعيين كلمة المرور',
                'invoiceSubject' => 'ملف الفاتورة PDF',
                'purchaseOrderSubject' => 'ملف أمر الشراء PDF',
            ];
        default:
            return [
                'appName' => 'Factorator',
                'tagline' => 'Your smart invoicing app',
                'hello' => 'Hello,',
                'verificationTitle' => 'Email Verification',
                'verificationIntro' => 'Use the following code to verify your email address:',
                'verificationExpiry' => 'This code expires in 10 minutes.',
                'resetTitle' => 'Password Reset',
                'resetIntro' => 'Use the following code to reset your password:',
                'resetExpiry' => 'This code expires in 10 minutes.',
                'invoiceTitle' => 'Your invoice is ready',
                'invoiceIntro' => 'Please find your invoice attached.',
                'purchaseOrderTitle' => 'Your purchase order is ready',
                'purchaseOrderIntro' => 'Please find your supplier purchase order attached.',
                'footer' => 'This email was sent automatically by Factorator.',
                'verificationSubject' => 'Verify your email',
                'resetSubject' => 'Reset your password',
                'invoiceSubject' => 'Your invoice PDF',
                'purchaseOrderSubject' => 'Your purchase order PDF',
            ];
    }
}

function buildMailTemplate(
    string $language,
    string $title,
    string $bodyHtml
): string {
    $lang = normalizeMailLanguage($language);
    $copy = mailCopy($lang);
    $theme = mailTheme();

    $dir = $lang === 'ar' ? 'rtl' : 'ltr';
    $align = $lang === 'ar' ? 'right' : 'left';

    return "
    <!DOCTYPE html>
    <html lang=\"{$lang}\" dir=\"{$dir}\">
    <head>
      <meta charset=\"UTF-8\">
      <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
      <title>{$title}</title>
    </head>
    <body style=\"margin:0;padding:0;background:{$theme['background']};font-family:Arial,Helvetica,sans-serif;color:{$theme['text']};\">
      <div style=\"padding:32px 16px;\">
        <div style=\"max-width:640px;margin:0 auto;background:{$theme['surface']};border:1px solid {$theme['border']};border-radius:24px;overflow:hidden;box-shadow:0 12px 40px rgba(15,23,42,0.08);\">
          
          <div style=\"background:linear-gradient(135deg, {$theme['primary']} 0%, {$theme['primaryDark']} 100%);padding:32px;\">
            <div style=\"color:#ffffff;text-align:{$align};\">
              <div style=\"font-size:30px;font-weight:800;letter-spacing:0.3px;\">{$copy['appName']}</div>
              <div style=\"margin-top:8px;font-size:14px;opacity:0.92;\">{$copy['tagline']}</div>
            </div>
          </div>

          <div style=\"padding:36px 32px;text-align:{$align};\">
            <div style=\"font-size:15px;color:{$theme['muted']};margin-bottom:10px;\">{$copy['hello']}</div>
            <h1 style=\"margin:0 0 18px 0;font-size:28px;line-height:1.3;color:{$theme['text']};font-weight:800;\">{$title}</h1>
            <div style=\"font-size:15px;line-height:1.9;color:{$theme['text']};\">
              {$bodyHtml}
            </div>
          </div>

          <div style=\"padding:18px 32px;background:{$theme['soft']};border-top:1px solid {$theme['border']};text-align:{$align};font-size:12px;line-height:1.8;color:{$theme['muted']};\">
            {$copy['footer']}<br>
            &copy; " . date('Y') . " {$copy['appName']}
          </div>
        </div>
      </div>
    </body>
    </html>";
}

function makeCodeBox(string $code): string
{
    $theme = mailTheme();

    return "
    <div style=\"margin:22px 0;padding:18px 20px;background:{$theme['codeBg']};border:1px solid {$theme['border']};border-radius:18px;text-align:center;\">
      <div style=\"font-size:34px;font-weight:800;letter-spacing:10px;color:{$theme['text']};\">
        {$code}
      </div>
    </div>";
}

function makeMailer(): PHPMailer
{
    $mail = new PHPMailer(true);

    $mail->isSMTP();
    $mail->Host = $_ENV['MAIL_HOST'] ?? '';
    $mail->Port = (int)($_ENV['MAIL_PORT'] ?? 587);
    $mail->SMTPAuth = true;
    $mail->Username = $_ENV['MAIL_USERNAME'] ?? '';
    $mail->Password = $_ENV['MAIL_PASSWORD'] ?? '';
    $mail->SMTPSecure = $_ENV['MAIL_ENCRYPTION'] ?? 'tls';
    $mail->Timeout = 10;
    $mail->Timelimit = 20;

    $mail->setFrom(
        $_ENV['MAIL_FROM_ADDRESS'] ?? '',
        $_ENV['MAIL_FROM_NAME'] ?? 'Factorator'
    );

    $mail->isHTML(true);
    $mail->CharSet = 'UTF-8';

    return $mail;
}

function sendMailMessage(
    string $to,
    string $subject,
    string $htmlBody,
    ?string $attachmentPath = null,
    ?string $attachmentName = null
): void {
    $mail = makeMailer();

    $mail->addAddress($to);
    $mail->Subject = $subject;
    $mail->Body = $htmlBody;
    $mail->AltBody = strip_tags($htmlBody);

    if ($attachmentPath && file_exists($attachmentPath)) {
        $mail->addAttachment(
            $attachmentPath,
            $attachmentName ?? basename($attachmentPath)
        );
    }

    $mail->send();
}

function sendMailMessageWithBinaryAttachment(
    string $to,
    string $subject,
    string $htmlBody,
    string $binaryContent,
    string $attachmentName = 'document.pdf',
    string $mimeType = 'application/pdf'
): void {
    $mail = makeMailer();

    $mail->addAddress($to);
    $mail->Subject = $subject;
    $mail->Body = $htmlBody;
    $mail->AltBody = strip_tags($htmlBody);

    $mail->addStringAttachment(
        $binaryContent,
        $attachmentName,
        'base64',
        $mimeType
    );

    $mail->send();
}

function sendVerificationCode(
    string $to,
    string $code,
    string $language = 'en'
): void {
    $copy = mailCopy($language);

    $bodyHtml = "
      <p style=\"margin:0 0 14px 0;\">{$copy['verificationIntro']}</p>
      " . makeCodeBox($code) . "
      <p style=\"margin:0;color:#6B7280;\">{$copy['verificationExpiry']}</p>
    ";

    sendMailMessage(
        $to,
        $copy['verificationSubject'],
        buildMailTemplate($language, $copy['verificationTitle'], $bodyHtml)
    );
}

function sendResetCode(
    string $to,
    string $code,
    string $language = 'en'
): void {
    $copy = mailCopy($language);

    $bodyHtml = "
      <p style=\"margin:0 0 14px 0;\">{$copy['resetIntro']}</p>
      " . makeCodeBox($code) . "
      <p style=\"margin:0;color:#6B7280;\">{$copy['resetExpiry']}</p>
    ";

    sendMailMessage(
        $to,
        $copy['resetSubject'],
        buildMailTemplate($language, $copy['resetTitle'], $bodyHtml)
    );
}

function sendInvoicePdf(
    string $to,
    string $pdfBinary,
    string $filename,
    string $language = 'en',
    string $documentType = 'invoice'
): void {
    if (!str_ends_with(strtolower($filename), '.pdf')) {
        $filename .= '.pdf';
    }

    $theme = mailTheme();
    $normalizedType = strtolower(trim($documentType));
    $lang = normalizeMailLanguage($language);
    $documentCopy = [
        'en' => [
            'invoice' => ['Your invoice is ready', 'Please find your invoice attached.', 'Your invoice PDF'],
            'devis' => ['Your quotation is ready', 'Please find your quotation attached.', 'Your quotation PDF'],
            'credit_note' => ['Your credit note is ready', 'Please find your credit note attached.', 'Your credit note PDF'],
            'sales_order' => ['Your sales order is ready', 'Please find your sales order attached.', 'Your sales order PDF'],
            'delivery_note' => ['Your delivery note is ready', 'Please find your delivery note attached.', 'Your delivery note PDF'],
            'purchase_order' => ['Your purchase order is ready', 'Please find your supplier purchase order attached.', 'Your purchase order PDF'],
        ],
        'fr' => [
            'invoice' => ['Votre facture est prête', 'Veuillez trouver votre facture en pièce jointe.', 'Votre facture PDF'],
            'devis' => ['Votre devis est prêt', 'Veuillez trouver votre devis en pièce jointe.', 'Votre devis PDF'],
            'credit_note' => ['Votre avoir est prêt', 'Veuillez trouver votre avoir en pièce jointe.', 'Votre avoir PDF'],
            'sales_order' => ['Votre bon de commande est prêt', 'Veuillez trouver votre bon de commande en pièce jointe.', 'Votre bon de commande PDF'],
            'delivery_note' => ['Votre bon de livraison est prêt', 'Veuillez trouver votre bon de livraison en pièce jointe.', 'Votre bon de livraison PDF'],
            'purchase_order' => ['Votre commande fournisseur est prête', 'Veuillez trouver votre commande fournisseur en pièce jointe.', 'Votre commande fournisseur PDF'],
        ],
        'ar' => [
            'invoice' => ['فاتورتك جاهزة', 'يرجى الاطلاع على الفاتورة المرفقة.', 'ملف الفاتورة PDF'],
            'devis' => ['عرض السعر جاهز', 'يرجى الاطلاع على عرض السعر المرفق.', 'ملف عرض السعر PDF'],
            'credit_note' => ['الإشعار الدائن جاهز', 'يرجى الاطلاع على الإشعار الدائن المرفق.', 'ملف الإشعار الدائن PDF'],
            'sales_order' => ['طلب الحريف جاهز', 'يرجى الاطلاع على طلب الحريف المرفق.', 'ملف طلب الحريف PDF'],
            'delivery_note' => ['وصل التسليم جاهز', 'يرجى الاطلاع على وصل التسليم المرفق.', 'ملف وصل التسليم PDF'],
            'purchase_order' => ['طلب الشراء جاهز', 'يرجى الاطلاع على طلب الشراء المرفق.', 'ملف طلب الشراء PDF'],
        ],
    ];
    if (in_array($normalizedType, ['supplier_order', 'order'], true)) {
        $normalizedType = 'purchase_order';
    }
    [$title, $intro, $subject] = $documentCopy[$lang][$normalizedType]
        ?? $documentCopy[$lang]['invoice'];
    $safeFilename = htmlspecialchars($filename, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');

    $bodyHtml = "
      <p style=\"margin:0 0 14px 0;\">{$intro}</p>
      <div style=\"margin:22px 0;padding:20px;border:1px solid {$theme['border']};border-radius:18px;background:{$theme['soft']};\">
        <div style=\"font-size:14px;color:{$theme['muted']};margin-bottom:6px;\">PDF</div>
        <div style=\"font-size:20px;font-weight:800;color:{$theme['text']};word-break:break-word;\">{$safeFilename}</div>
        <div style=\"margin-top:10px;font-size:13px;color:{$theme['muted']};\">" . date('Y-m-d') . "</div>
      </div>
    ";

    sendMailMessageWithBinaryAttachment(
        $to,
        $subject,
        buildMailTemplate($language, $title, $bodyHtml),
        $pdfBinary,
        $filename,
        'application/pdf'
    );
}

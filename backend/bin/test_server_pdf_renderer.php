<?php

declare(strict_types=1);

require_once __DIR__ . '/../mailer/document_pdf_service.php';

$company = [
    'organization_name' => 'Factorator Test',
    'fiscal_id' => 'TEST-001',
    'phone' => '+216 00 000 000',
    'fax' => '',
    'address' => 'Tunis, Tunisie',
    'website' => 'example.test',
];
$document = [
    'number' => 'FACT-TEST-001', 'date' => '2026-08-24', 'due_date' => '2026-09-23',
    'expected_date' => '', 'status' => 'UNPAID', 'currency' => 'TND',
    'party_name' => 'Client Test', 'party_email' => 'client@example.test', 'party_phone' => '',
    'party_address' => 'Tunis', 'party_fiscal_id' => 'CLIENT-001',
    'notes' => 'Generated from authoritative server data.',
    'subtotal' => 100.000, 'tax_total' => 19.000, 'stamp' => 1.000, 'total' => 120.000,
    'items' => [[
        'code' => 'SVC-001', 'description' => 'Service test', 'qty' => 1, 'price' => 100,
        'discount' => 0, 'tva_rate' => 19, 'total' => 119,
    ]],
];

$pdf = documentPdfRender($company, $document, 'invoice', 'fr');
if (!str_starts_with($pdf, '%PDF-')) {
    fwrite(STDERR, "FAIL server PDF renderer did not produce a PDF\n");
    exit(1);
}
if (strlen($pdf) < 1000) {
    fwrite(STDERR, "FAIL server PDF renderer produced an unexpectedly small document\n");
    exit(1);
}

echo 'PASS server PDF renderer (' . strlen($pdf) . " bytes)\n";

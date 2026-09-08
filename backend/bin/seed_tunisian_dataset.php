<?php

declare(strict_types=1);

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

require_once __DIR__ . '/../config/db.php';

const DEMO_MARKER = 'DEMO-TN-2026';
const DATASET_END = '2026-08-11';

function failSeed(string $message): never
{
    fwrite(STDERR, $message . PHP_EOL);
    exit(1);
}

function executeStatement(mysqli_stmt $statement, array $params): int
{
    $statement->execute($params);
    return (int)$statement->insert_id;
}

function amount(float $value): float
{
    return round($value + 0.00000001, 3);
}

function distributedDate(int $index, int $count, string $from = '2024-01-01', string $to = DATASET_END): string
{
    $start = new DateTimeImmutable($from);
    $end = new DateTimeImmutable($to);
    $days = (int)$start->diff($end)->format('%a');
    $offset = $count <= 1 ? 0 : (int)floor(($index * $days) / ($count - 1));
    return $start->modify('+' . $offset . ' days')->format('Y-m-d');
}

function addDays(string $date, int $days): string
{
    $result = (new DateTimeImmutable($date))->modify('+' . $days . ' days');
    $end = new DateTimeImmutable(DATASET_END);
    return ($result > $end ? $end : $result)->format('Y-m-d');
}

function fiscalId(int $index): string
{
    $letters = ['A', 'B', 'D', 'E', 'F', 'M', 'N', 'P'];
    return sprintf('%07d/%s/%s/%03d', 1000000 + ($index % 8999999), $letters[$index % count($letters)], $letters[($index * 3 + 1) % count($letters)], $index % 1000);
}

function phoneNumber(int $index): string
{
    $prefixes = [20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 31, 50, 51, 52, 53, 54, 55, 56, 58, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79];
    return sprintf('+216 %02d %03d %03d', $prefixes[$index % count($prefixes)], 100 + (($index * 37) % 900), 100 + (($index * 83) % 900));
}

function documentNumber(array &$sequences, string $type, string $prefix, string $date): string
{
    $year = (int)substr($date, 0, 4);
    $key = $type . ':' . $year;
    $sequences[$key] = ($sequences[$key] ?? 0) + 1;
    return sprintf('%s-%d-%06d', $prefix, $year, $sequences[$key]);
}

function lineForProduct(array $product, int $qty): array
{
    $subtotal = amount($qty * (float)$product['price']);
    $fodec = amount($subtotal * (float)$product['fodec_rate'] / 100);
    $vat = $product['tax_regime'] === 'STANDARD'
        ? amount(($subtotal + $fodec) * (float)$product['vat_rate'] / 100)
        : 0.0;
    $total = amount($subtotal + $fodec + $vat);
    return [
        'product_id' => (int)$product['id'],
        'profile_id' => (int)$product['profile_id'],
        'code' => (string)$product['code'],
        'name' => (string)$product['name'],
        'item_type' => (string)$product['item_type'],
        'unit' => (string)$product['unit'],
        'qty' => $qty,
        'price' => (float)$product['price'],
        'cost' => (float)$product['cost'],
        'vat_rate' => (float)$product['vat_rate'],
        'tax_regime' => (string)$product['tax_regime'],
        'fodec_rate' => (float)$product['fodec_rate'],
        'fodec' => $fodec,
        'vat' => $vat,
        'tax' => amount($fodec + $vat),
        'subtotal' => $subtotal,
        'total' => $total,
        'deductibility' => (float)$product['deductibility'],
        'legal_basis' => (string)$product['legal_basis'],
    ];
}

function sumLines(array $lines): array
{
    $totals = ['subtotal' => 0.0, 'fodec' => 0.0, 'vat' => 0.0, 'tax' => 0.0, 'total' => 0.0];
    foreach ($lines as $line) {
        foreach ($totals as $key => $unused) $totals[$key] = amount($totals[$key] + (float)$line[$key]);
    }
    return $totals;
}

function monthEnd(string $date): string
{
    return (new DateTimeImmutable($date))->modify('last day of this month')->format('Y-m-d');
}

$options = getopt('', ['tenant:', 'confirm']);
if (!isset($options['confirm'])) failSeed('REFUSED: pass --confirm to seed the local test database.');
$tenantId = (int)($options['tenant'] ?? 0);
if ($tenantId <= 0) failSeed('REFUSED: pass a valid --tenant user id.');

set_time_limit(0);
ini_set('memory_limit', '1024M');

$conn = db();
$database = (string)$conn->query('SELECT DATABASE()')->fetch_row()[0];
if (!str_contains(strtolower($database), 'local') && !str_contains(strtolower($database), 'test')) {
    failSeed("REFUSED: '$database' is not recognizably a local/test database.");
}

$tenant = $conn->execute_query('SELECT id,organization_name,role FROM users WHERE id=? LIMIT 1', [$tenantId])->fetch_assoc();
if (!$tenant) failSeed('REFUSED: tenant account does not exist.');

$ownedTables = [
    'clients', 'suppliers', 'products', 'erp_invoices', 'erp_sales_orders', 'erp_delivery_notes',
    'erp_supplier_orders', 'erp_supplier_receptions', 'erp_supplier_invoices', 'expense_notes',
];
foreach ($ownedTables as $table) {
    $count = (int)$conn->execute_query("SELECT COUNT(*) FROM `$table` WHERE user_id=?", [$tenantId])->fetch_row()[0];
    if ($count > 0) failSeed("REFUSED: tenant $tenantId already owns data in $table. Clear it before reseeding.");
}

$counts = [
    'clients' => 2400,
    'suppliers' => 360,
    'products' => 1500,
    'quotes' => 2800,
    'orders' => 1800,
    'deliveries' => 1500,
    'invoices' => 12000,
    'credit_notes' => 400,
    'supplier_orders' => 1000,
    'supplier_receptions' => 800,
    'expenses' => 3200,
];

$cities = [
    ['Tunis', 'Avenue Habib Bourguiba'], ['Ariana', 'Avenue Hédi Nouira'], ['Ben Arous', 'Rue de l’Industrie'],
    ['La Marsa', 'Avenue Taïeb Mhiri'], ['Sfax', 'Route de Gremda'], ['Sousse', 'Boulevard de la Corniche'],
    ['Monastir', 'Avenue du Combattant Suprême'], ['Nabeul', 'Avenue Farhat Hached'], ['Bizerte', 'Rue d’Espagne'],
    ['Gabès', 'Avenue Mohamed Ali'], ['Médenine', 'Route de Tataouine'], ['Kairouan', 'Avenue de la République'],
    ['Mahdia', 'Avenue Tahar Sfar'], ['Gafsa', 'Avenue Bourguiba'], ['Béja', 'Rue Kheireddine Pacha'],
    ['Jendouba', 'Avenue de l’UMA'], ['Zaghouan', 'Rue du 20 Mars'], ['Tozeur', 'Avenue Abou El Kacem Chebbi'],
];
$companyRoots = ['Comptoir', 'Société', 'Établissements', 'Groupe', 'Maison', 'Ateliers', 'Distribution', 'Industries', 'Services', 'Solutions', 'Commerce', 'Manufacture'];
$companySubjects = ['Carthage', 'du Sahel', 'El Amen', 'El Wifak', 'Ifriqiya', 'Atlas', 'Jasmin', 'Olivier', 'Cap Bon', 'Méditerranée', 'Maghreb', 'Nour', 'Ribat', 'Djerba', 'Kairouan'];
$companySectors = ['Distribution', 'Équipement', 'Bureautique', 'Agroalimentaire', 'Maintenance', 'Emballage', 'Informatique', 'Textile', 'Construction', 'Logistique', 'Hygiène', 'Électricité'];
$firstNames = ['Ahmed', 'Mohamed', 'Sami', 'Walid', 'Hatem', 'Nabil', 'Youssef', 'Hamadi', 'Amine', 'Skander', 'Sarra', 'Inès', 'Meriem', 'Rania', 'Sonia', 'Olfa', 'Emna', 'Nour'];
$lastNames = ['Trabelsi', 'Hammemi', 'Ben Salah', 'Gharbi', 'Ayari', 'Mansouri', 'Jlassi', 'Khelifi', 'Baccouche', 'Mejri', 'Saïdi', 'Chaabane', 'Zouari', 'Abidi', 'Bouazizi', 'Dridi'];
$salespeople = ['Sonia Trabelsi', 'Nabil Hammemi', 'Youssef Gharbi', 'Meriem Ayari', 'Hamadi Ben Salah', 'Sarra Khelifi'];

$insertClient = $conn->prepare('INSERT INTO clients(reference,type,name,email,phone,address,fiscalId,cin,payment_terms_days,user_id,date_creation) VALUES(?,?,?,?,?,?,?,?,?,?,?)');
$insertSupplier = $conn->prepare('INSERT INTO suppliers(reference,type,name,email,phone,address,fiscal_id,user_id,created_at) VALUES(?,?,?,?,?,?,?,?,?)');
$insertTaxProfile = $conn->prepare('INSERT INTO erp_tax_profiles(user_id,name,vat_rate,vat_exempt,fodec_applicable,fodec_rate,tax_regime,deductibility_rate,legal_basis,certificate_reference,effective_from) VALUES(?,?,?,?,?,?,?,?,?,?,?)');
$insertProduct = $conn->prepare('INSERT INTO products(code,name,category,item_type,tax_profile_id,price,last_purchase_price,average_cost,tva_rate,unit,stock_quantity,reorder_point,user_id) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)');

$insertInvoice = $conn->prepare("INSERT INTO erp_invoices(invoice,custom_email,custom_code,salesperson_name,sales_order_id,delivery_note_id,source_invoice_id,source_flow,invoice_date,invoice_due_date,currency,exchange_rate,exchange_rate_date,subtotal,subtotal_tnd,base_tva,montant_tva,tax_total_tnd,subtotal_ttc,shipping,discount,vat,total,total_tnd,notes,invoice_type,return_to_stock,status,transformation_status,is_validated,timbre,payment_method,date_ajout,tx_retenue,retenue,net_retenue,user_id) VALUES(?,?,?,?,NULLIF(?,0),NULLIF(?,0),NULLIF(?,0),?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)");
$insertInvoiceItem = $conn->prepare('INSERT INTO erp_invoice_items(invoice_id,invoice,product_id,tax_profile_id,product_code,product,qty,tva_rate,tax_regime,fodec_rate,fodec_amount,legal_basis,certificate_reference,montant_tva,tax_tnd,price,discount,subtotal,subtotal_tnd,subtotalTTC,total_tnd,invoice_date) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)');
$insertPayment = $conn->prepare("INSERT INTO erp_invoice_payments(invoice_id,user_id,amount,exchange_rate,exchange_rate_date,amount_tnd,payment_date,method,account_name,reference_number,status,recorded_by,created_at) VALUES(?,?,?,1,?,?,?,?,?,?, 'POSTED',?,?)");
$insertWithholding = $conn->prepare('INSERT INTO erp_invoice_withholdings(invoice_id,user_id,withholding_type,rate,calculation_base,withheld_amount,certificate_number,certificate_date,expected_certificate_date,certificate_status,received_at,validated_at,validation_notes,recorded_by,created_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)');

$insertOrder = $conn->prepare('INSERT INTO erp_sales_orders(order_number,client_id,order_date,expected_delivery_date,delivery_address,customer_reference,source_devis_id,notes,status,subtotal,montant_tva,total,user_id,created_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)');
$insertOrderItem = $conn->prepare('INSERT INTO erp_sales_order_items(sales_order_id,product_id,product_code,product,qty,price,discount,tva_rate,subtotal,montant_tva,total,created_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)');
$insertDelivery = $conn->prepare("INSERT INTO erp_delivery_notes(delivery_number,document_type,client_id,sales_order_id,delivery_date,expected_delivery_date,delivery_address,vehicle_registration,customer_reference,movement_reason,notes,status,item_count,stock_applied,user_id,created_at) VALUES(?,'DELIVERY',?,?,?,?,?,?,?,?,?,?,?,?,?,?)");
$insertDeliveryItem = $conn->prepare('INSERT INTO erp_delivery_note_items(delivery_note_id,product_id,product_code,product,qty,price,discount,tva_rate,subtotal,montant_tva,total,unit,created_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)');

$insertSupplierOrder = $conn->prepare('INSERT INTO erp_supplier_orders(order_number,supplier_id,order_date,expected_date,notes,status,subtotal,total_vat,total,user_id,created_at) VALUES(?,?,?,?,?,?,?,?,?,?,?)');
$insertSupplierOrderItem = $conn->prepare('INSERT INTO erp_supplier_order_items(supplier_order_id,catalog_id,product_code,description,item_type,qty,price,tva_rate,unit,line_total,created_at) VALUES(?,?,?,?,?,?,?,?,?,?,?)');
$insertReception = $conn->prepare('INSERT INTO erp_supplier_receptions(supplier_id,supplier_order_id,invoice_number,invoice_date,received_date,notes,status,stock_applied,stock_applied_at,total_ht,total_vat,total_ttc,user_id,created_at) VALUES(?,?,?,?,?,? ,\'REVIEWED\',1,?,?,?,?,?,?)');
$insertReceptionItem = $conn->prepare('INSERT INTO erp_supplier_reception_items(supplier_reception_id,catalog_id,code,name,item_type,ordered_qty,qty,accepted_qty,damaged_qty,rejected_qty,discrepancy_reason,stock_impact,price,selling_price,subtotal,tva_rate,unit,created_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)');
$insertSupplierInvoice = $conn->prepare("INSERT INTO erp_supplier_invoices(user_id,supplier_id,supplier_order_id,invoice_number,invoice_date,due_date,status,currency,exchange_rate,exchange_rate_date,total_ht,total_ht_tnd,total_vat,total_tax_tnd,stamp_duty,stamp_duty_tnd,total_ttc,total_ttc_tnd,credited_amount,notes,created_by,validated_at,created_at) VALUES(?,?,?,?,?,?,?,'TND',1,?,?,?,?,?,0,0,?,?,0,?,?,?,?)");
$insertSupplierInvoiceItem = $conn->prepare('INSERT INTO erp_supplier_invoice_items(supplier_invoice_id,supplier_reception_item_id,product_id,tax_profile_id,description,quantity,unit_price,vat_rate,fodec_rate,fodec_amount,tax_regime,deductibility_rate,legal_basis,certificate_reference,total_ht,total_ht_tnd,total_vat,deductible_vat_tnd,non_deductible_vat_tnd,total_tax_tnd,total_ttc,total_ttc_tnd) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)');
$insertSupplierPayment = $conn->prepare('INSERT INTO erp_supplier_payments(user_id,supplier_invoice_id,amount,exchange_rate,exchange_rate_date,amount_tnd,payment_date,method,account,reference_number,recorded_by,created_at) VALUES(?,?,?,1,?,?,?,?,?,?,?,?)');
$insertExpense = $conn->prepare('INSERT INTO expense_notes(user_id,supplier_id,title,category,amount,expense_date,description,status,created_at) VALUES(?,?,?,?,?,?,?,?,?)');
$insertMovement = $conn->prepare('INSERT INTO product_stock_movements(user_id,product_id,movement_type,quantity,unit_cost,movement_value,cogs_value,reference_type,reference_id,reason_code,lot_number,idempotency_key,note,created_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)');

$conn->begin_transaction();
try {
    echo 'Seeding tenant ' . $tenantId . ' (' . $tenant['organization_name'] . ') in ' . $database . PHP_EOL;

    $profiles = [];
    $profileDefinitions = [
        'VAT19' => ['TVA standard 19%', 19.0, 0, 0, 0.0, 'STANDARD', 100.0, 'Régime standard - données de démonstration'],
        'VAT13' => ['TVA réduite 13%', 13.0, 0, 0, 0.0, 'STANDARD', 100.0, 'Taux réduit - données de démonstration'],
        'VAT7' => ['TVA réduite 7%', 7.0, 0, 0, 0.0, 'STANDARD', 100.0, 'Taux réduit - données de démonstration'],
        'EXEMPT' => ['Exonéré', 0.0, 1, 0, 0.0, 'EXEMPT', 0.0, 'Exonération de démonstration à valider'],
        'FODEC19' => ['TVA 19% + FODEC 1%', 19.0, 0, 1, 1.0, 'STANDARD', 100.0, 'FODEC de démonstration à valider'],
        'VAT19HALF' => ['TVA 19% - déductibilité 50%', 19.0, 0, 0, 0.0, 'STANDARD', 50.0, 'Déductibilité partielle de démonstration'],
    ];
    foreach ($profileDefinitions as $key => $definition) {
        [$name, $vatRate, $vatExempt, $fodecApplicable, $fodecRate, $regime, $deductibility, $basis] = $definition;
        $profiles[$key] = executeStatement($insertTaxProfile, [$tenantId, $name, $vatRate, $vatExempt, $fodecApplicable, $fodecRate, $regime, $deductibility, $basis, '', '2020-01-01']);
    }

    $clientIds = [];
    for ($i = 0; $i < $counts['clients']; $i++) {
        $city = $cities[$i % count($cities)];
        $individual = $i % 8 === 0;
        $name = $individual
            ? $firstNames[$i % count($firstNames)] . ' ' . $lastNames[($i * 5) % count($lastNames)]
            : $companyRoots[$i % count($companyRoots)] . ' ' . $companySubjects[($i * 7) % count($companySubjects)] . ' ' . $companySectors[($i * 11) % count($companySectors)] . ' ' . sprintf('%03d', intdiv($i, count($companyRoots)) + 1);
        $type = $individual ? 'PARTICULIER' : 'ENTREPRISE';
        $email = sprintf('client.%04d@demo-tunisie.example', $i + 1);
        $address = sprintf('%d %s, %s, Tunisie', 1 + (($i * 17) % 199), $city[1], $city[0]);
        $clientIds[] = executeStatement($insertClient, [sprintf('C%06d', $i + 1), $type, $name, $email, phoneNumber($i), $address, $individual ? null : fiscalId($i), $individual ? sprintf('%08d', 50000000 + $i) : null, [15, 30, 45, 60][$i % 4], $tenantId, distributedDate($i, $counts['clients'], '2022-01-01') . ' 09:00:00']);
    }
    echo '  clients: ' . count($clientIds) . PHP_EOL;

    $supplierIds = [];
    for ($i = 0; $i < $counts['suppliers']; $i++) {
        $city = $cities[($i * 3) % count($cities)];
        $name = $companyRoots[($i + 3) % count($companyRoots)] . ' ' . $companySubjects[($i * 5 + 2) % count($companySubjects)] . ' ' . $companySectors[($i * 7 + 1) % count($companySectors)] . ' Fournisseur ' . sprintf('%03d', $i + 1);
        $supplierIds[] = executeStatement($insertSupplier, [sprintf('F%06d', $i + 1), 'company', $name, sprintf('fournisseur.%03d@demo-tunisie.example', $i + 1), phoneNumber($i + 5000), sprintf('%d %s, %s, Tunisie', 2 + (($i * 19) % 180), $city[1], $city[0]), fiscalId($i + 5000), $tenantId, distributedDate($i, $counts['suppliers'], '2022-01-01') . ' 08:30:00']);
    }
    echo '  suppliers: ' . count($supplierIds) . PHP_EOL;

    $categories = ['Informatique', 'Bureautique', 'Électricité', 'Quincaillerie', 'Emballage', 'Hygiène', 'Sécurité', 'Textile', 'Agroalimentaire', 'Plomberie', 'Automobile', 'Mobilier'];
    $productNames = ['Câble réseau', 'Ramette papier', 'Disjoncteur', 'Perceuse', 'Carton renforcé', 'Détergent professionnel', 'Gants de protection', 'Polo de travail', 'Huile alimentaire', 'Robinet industriel', 'Filtre moteur', 'Chaise de bureau', 'Clavier', 'Classeur', 'Projecteur LED', 'Visserie inox', 'Film étirable', 'Savon liquide', 'Casque de chantier', 'Tissu coton'];
    $serviceNames = ['Installation', 'Maintenance préventive', 'Assistance technique', 'Audit de stock', 'Formation utilisateur', 'Livraison locale', 'Configuration réseau', 'Nettoyage professionnel'];
    $units = ['pièce', 'carton', 'kg', 'litre', 'mètre', 'paquet'];
    $products = [];
    $stockProducts = [];
    $workflowProducts = [];
    $stockDelta = [];
    $basePrices = [12.9, 18.5, 24.9, 35.7, 48.3, 65.9, 89.5, 125.4, 178.9, 245.6, 395.0, 690.0, 1250.0, 2490.0, 5890.0];
    for ($i = 0; $i < $counts['products']; $i++) {
        $isService = $i >= 1280;
        $category = $isService ? 'Services' : $categories[$i % count($categories)];
        $profileKey = $isService ? ($i % 7 === 0 ? 'VAT7' : 'VAT19') : match ($category) {
            'Agroalimentaire' => $i % 3 === 0 ? 'VAT7' : 'VAT19',
            'Automobile' => 'VAT19HALF',
            'Textile' => $i % 5 === 0 ? 'VAT13' : 'VAT19',
            'Électricité', 'Quincaillerie' => $i % 4 === 0 ? 'FODEC19' : 'VAT19',
            default => $i % 31 === 0 ? 'EXEMPT' : 'VAT19',
        };
        $definition = $profileDefinitions[$profileKey];
        $rawPrice = $basePrices[$i % count($basePrices)] * (1 + (($i * 7) % 23) / 20);
        $price = $profileKey === 'FODEC19' ? (float)round($rawPrice) : amount($rawPrice);
        $cost = $isService ? 0.0 : amount($price * (0.47 + (($i * 13) % 24) / 100));
        $name = $isService
            ? $serviceNames[$i % count($serviceNames)] . ' ' . ['Essentiel', 'Pro', 'Plus', 'Entreprise'][$i % 4] . ' ' . sprintf('%03d', $i - 1279)
            : $productNames[$i % count($productNames)] . ' ' . ['Standard', 'Pro', 'Eco', 'Premium', 'Industriel'][$i % 5] . ' ' . sprintf('%04d', $i + 1);
        $code = ($isService ? 'TN-S-' : 'TN-P-') . sprintf('%05d', $i + 1);
        $unit = $isService ? ($i % 2 === 0 ? 'heure' : 'forfait') : $units[$i % count($units)];
        $productId = executeStatement($insertProduct, [$code, $name, $category, $isService ? 'SERVICE' : 'PRODUCT', $profiles[$profileKey], $price, $cost, $cost, $definition[1], $unit, 0, $isService ? 0 : 10 + ($i % 35), $tenantId]);
        $product = ['id' => $productId, 'code' => $code, 'name' => $name, 'category' => $category, 'item_type' => $isService ? 'SERVICE' : 'PRODUCT', 'profile_id' => $profiles[$profileKey], 'price' => $price, 'cost' => $cost, 'vat_rate' => $definition[1], 'fodec_rate' => $definition[4], 'tax_regime' => $definition[5], 'deductibility' => $definition[6], 'legal_basis' => $definition[7], 'unit' => $unit];
        $products[] = $product;
        if (!$isService) {
            $stockProducts[] = $product;
            $stockDelta[$productId] = 0.0;
            if ($profileKey !== 'FODEC19') $workflowProducts[] = $product;
        }
    }
    echo '  products/services: ' . count($products) . PHP_EOL;

    $movementSequence = 0;
    $addMovement = function (array $product, string $type, float $quantity, string $referenceType, int $referenceId, string $date, string $note) use ($insertMovement, $tenantId, &$stockDelta, &$movementSequence): void {
        if ($product['item_type'] !== 'PRODUCT') return;
        $movementSequence++;
        $movementValue = amount($quantity * (float)$product['cost']);
        $cogs = $quantity < 0 ? amount(abs($quantity) * (float)$product['cost']) : 0.0;
        executeStatement($insertMovement, [$tenantId, $product['id'], $type, $quantity, $product['cost'], $movementValue, $cogs, $referenceType, $referenceId, DEMO_MARKER, null, DEMO_MARKER . '-' . $movementSequence, $note, $date . ' 12:00:00']);
        $stockDelta[$product['id']] = amount(($stockDelta[$product['id']] ?? 0) + $quantity);
    };

    $insertInvoiceLines = function (int $invoiceId, string $number, string $date, array $lines) use ($insertInvoiceItem): void {
        foreach ($lines as $line) {
            executeStatement($insertInvoiceItem, [$invoiceId, $number, $line['product_id'], $line['profile_id'], $line['code'], $line['name'], $line['qty'], $line['vat_rate'], $line['tax_regime'], $line['fodec_rate'], $line['fodec'], $line['legal_basis'], '', $line['vat'], $line['tax'], $line['price'], 0, $line['subtotal'], $line['subtotal'], $line['total'], $line['total'], $date]);
        }
    };

    $sequences = [];
    $acceptedQuotes = [];
    for ($i = 0; $i < $counts['quotes']; $i++) {
        $date = distributedDate($i, $counts['quotes']);
        $clientIndex = ($i * 17) % count($clientIds);
        $lines = [lineForProduct($workflowProducts[($i * 5) % count($workflowProducts)], 1 + ($i % 5)), lineForProduct($workflowProducts[($i * 11 + 7) % count($workflowProducts)], 1 + (($i * 3) % 4))];
        $totals = sumLines($lines);
        $status = $i % 10 < 7 ? 'ACCEPTED' : ($i % 10 === 7 ? 'SENT' : ($i % 10 === 8 ? 'REJECTED' : 'DRAFT'));
        $validated = $status === 'DRAFT' ? 0 : 1;
        $number = documentNumber($sequences, 'DEVIS', 'DEV', $date);
        $invoiceId = executeStatement($insertInvoice, [$number, sprintf('client.%04d@demo-tunisie.example', $clientIndex + 1), (string)$clientIds[$clientIndex], $salespeople[$i % count($salespeople)], 0, 0, 0, 'DIRECT', $date, addDays($date, 30), 'TND', 1, $date, $totals['subtotal'], $totals['subtotal'], amount($totals['subtotal'] + $totals['fodec']), $totals['vat'], $totals['tax'], $totals['total'], 0, 0, $totals['vat'], $totals['total'], $totals['total'], DEMO_MARKER . ' - Devis tunisien de démonstration', 'DEVIS', 0, $status, 'NOT_TRANSFORMED', $validated, 0, null, $date . ' 09:15:00', null, null, null, $tenantId]);
        $insertInvoiceLines($invoiceId, $number, $date, $lines);
        if ($status === 'ACCEPTED') $acceptedQuotes[] = ['id' => $invoiceId, 'client_id' => $clientIds[$clientIndex], 'client_index' => $clientIndex, 'date' => $date, 'lines' => $lines, 'totals' => $totals];
    }
    echo '  quotations: ' . $counts['quotes'] . PHP_EOL;

    $orders = [];
    for ($i = 0; $i < $counts['orders']; $i++) {
        $quote = $acceptedQuotes[$i];
        $date = addDays($quote['date'], 2 + ($i % 8));
        $city = $cities[$i % count($cities)];
        $status = $i < $counts['deliveries'] ? 'INVOICED' : ($i % 4 === 0 ? 'DRAFT' : 'CONFIRMED');
        $number = documentNumber($sequences, 'BON_COMMANDE', 'BC', $date);
        $orderId = executeStatement($insertOrder, [$number, $quote['client_id'], $date, addDays($date, 7 + ($i % 15)), sprintf('%d %s, %s', 4 + ($i % 150), $city[1], $city[0]), 'REF-CL-' . sprintf('%06d', $i + 1), $quote['id'], DEMO_MARKER . ' - Commande issue du devis ' . $quote['id'], $status, $quote['totals']['subtotal'], $quote['totals']['vat'], $quote['totals']['total'], $tenantId, $date . ' 10:00:00']);
        foreach ($quote['lines'] as $line) executeStatement($insertOrderItem, [$orderId, $line['product_id'], $line['code'], $line['name'], $line['qty'], $line['price'], 0, $line['vat_rate'], $line['subtotal'], $line['vat'], $line['total'], $date . ' 10:05:00']);
        $orders[] = $quote + ['order_id' => $orderId, 'order_date' => $date];
        $conn->execute_query("UPDATE erp_invoices SET transformation_status='FULLY_ORDERED' WHERE id=?", [$quote['id']]);
    }
    echo '  sales orders: ' . count($orders) . PHP_EOL;

    $deliveries = [];
    for ($i = 0; $i < $counts['deliveries']; $i++) {
        $order = $orders[$i];
        $date = addDays($order['order_date'], 2 + ($i % 6));
        $city = $cities[($i * 5) % count($cities)];
        $number = documentNumber($sequences, 'BON_LIVRAISON', 'BL', $date);
        $deliveryId = executeStatement($insertDelivery, [$number, $order['client_id'], $order['order_id'], $date, $date, sprintf('%d %s, %s', 4 + ($i % 150), $city[1], $city[0]), sprintf('%03d TUN %04d', 100 + ($i % 899), 1000 + ($i % 8999)), 'REF-CL-' . sprintf('%06d', $i + 1), 'Livraison commerciale', DEMO_MARKER . ' - Livraison complète', 'DELIVERED', count($order['lines']), 1, $tenantId, $date . ' 11:00:00']);
        foreach ($order['lines'] as $line) {
            executeStatement($insertDeliveryItem, [$deliveryId, $line['product_id'], $line['code'], $line['name'], $line['qty'], $line['price'], 0, $line['vat_rate'], $line['subtotal'], $line['vat'], $line['total'], $line['unit'], $date . ' 11:05:00']);
            $product = $workflowProducts[array_search($line['product_id'], array_column($workflowProducts, 'id'), true)];
            $addMovement($product, 'DELIVERY_OUT', -(float)$line['qty'], 'DELIVERY', $deliveryId, $date, 'Sortie liée au bon de livraison ' . $number);
        }
        $deliveries[] = $order + ['delivery_id' => $deliveryId, 'delivery_date' => $date];
    }
    echo '  delivery notes: ' . count($deliveries) . PHP_EOL;

    $creditCandidates = [];
    $invoiceIds = [];
    $paymentMethods = ['BANK_TRANSFER', 'CHEQUE', 'BANK_TRANSFER', 'CARD', 'CASH', 'DRAFT'];
    for ($i = 0; $i < $counts['invoices']; $i++) {
        $workflow = $i < count($deliveries) ? $deliveries[$i] : null;
        $date = $workflow ? addDays($workflow['delivery_date'], 1 + ($i % 3)) : distributedDate($i, $counts['invoices']);
        $clientIndex = $workflow ? $workflow['client_index'] : (($i * 29 + 7) % count($clientIds));
        $lines = $workflow ? $workflow['lines'] : [
            lineForProduct($products[($i * 7) % count($products)], 1 + ($i % 7)),
            lineForProduct($products[($i * 13 + 17) % count($products)], 1 + (($i * 3) % 5)),
            lineForProduct($products[($i * 19 + 41) % count($products)], 1 + (($i * 5) % 4)),
        ];
        $totals = sumLines($lines);
        $stamp = 1.0;
        $grandTotal = amount($totals['total'] + $stamp);
        $mode = $i % 20;
        $validated = $mode < 18 ? 1 : 0;
        $due = addDays($date, [15, 30, 45, 60][$i % 4]);
        $status = $mode <= 10 ? 'PAID' : ($mode <= 13 ? 'PARTIALLY_PAID' : ($mode <= 17 ? ($due < DATASET_END ? 'OVERDUE' : 'UNPAID') : ($mode === 18 ? 'DRAFT' : 'CANCELLED')));
        $number = documentNumber($sequences, 'FACTURE', 'FAC', $date);
        $withholdingRate = $validated && $i % 23 === 0 ? ($i % 46 === 0 ? 3.0 : 1.5) : 0.0;
        $withheld = $withholdingRate > 0 ? amount($grandTotal * $withholdingRate / 100) : 0.0;
        $acceptedWithholding = $withholdingRate > 0 && ($status === 'PAID' || $i % 4 !== 0);
        $invoiceId = executeStatement($insertInvoice, [$number, sprintf('client.%04d@demo-tunisie.example', $clientIndex + 1), (string)$clientIds[$clientIndex], $salespeople[$i % count($salespeople)], $workflow['order_id'] ?? 0, $workflow['delivery_id'] ?? 0, 0, $workflow ? 'DELIVERY' : 'DIRECT', $date, $due, 'TND', 1, $date, $totals['subtotal'], $totals['subtotal'], amount($totals['subtotal'] + $totals['fodec']), $totals['vat'], $totals['tax'], $totals['total'], 0, 0, $totals['vat'], $grandTotal, $grandTotal, DEMO_MARKER . ($workflow ? ' - Facture issue du flux devis → commande → livraison' : ' - Facture directe tunisienne de démonstration'), 'FACTURE', 0, $status, 'NOT_TRANSFORMED', $validated, $stamp, $status === 'PAID' ? 'TRANSFER' : null, $date . ' ' . sprintf('%02d:%02d:00', 8 + ($i % 11), ($i * 7) % 60), $withholdingRate ?: null, $withheld ?: null, $withholdingRate ? amount($grandTotal - $withheld) : null, $tenantId]);
        $insertInvoiceLines($invoiceId, $number, $date, $lines);
        $invoiceIds[] = $invoiceId;
        if ($workflow) $conn->execute_query('UPDATE erp_sales_orders SET invoice_id=?,status=\'INVOICED\' WHERE id=?', [$invoiceId, $workflow['order_id']]);

        if ($validated) {
            foreach ($lines as $line) {
                if (!$workflow) {
                    $product = $products[array_search($line['product_id'], array_column($products, 'id'), true)];
                    $addMovement($product, 'INVOICE_OUT', -(float)$line['qty'], 'INVOICE', $invoiceId, $date, 'Sortie liée à la facture ' . $number);
                }
            }
        }

        if ($withholdingRate > 0) {
            $certificateStatus = $acceptedWithholding ? ($i % 2 === 0 ? 'VALIDATED' : 'RECEIVED') : 'PENDING';
            $certificateDate = $acceptedWithholding ? addDays($date, 12 + ($i % 20)) : null;
            $expectedDate = addDays($date, 30);
            $certificateNumber = $acceptedWithholding ? 'RS-' . substr($date, 0, 4) . '-' . sprintf('%06d', $i + 1) : '';
            executeStatement($insertWithholding, [$invoiceId, $tenantId, 'RETENUE_SOURCE', $withholdingRate, $grandTotal, $withheld, $certificateNumber, $certificateDate, $expectedDate, $certificateStatus, $certificateDate ? $certificateDate . ' 15:00:00' : null, $certificateStatus === 'VALIDATED' && $certificateDate ? $certificateDate . ' 16:00:00' : null, DEMO_MARKER . ' - Certificat synthétique', $tenantId, $date . ' 14:00:00']);
        }

        if ($status === 'PAID' || $status === 'PARTIALLY_PAID') {
            $paid = $status === 'PAID' ? amount($grandTotal - ($acceptedWithholding ? $withheld : 0)) : amount($grandTotal * 0.42);
            $paymentDate = addDays($date, 1 + (($i * 7) % 28));
            $method = $paymentMethods[$i % count($paymentMethods)];
            executeStatement($insertPayment, [$invoiceId, $tenantId, $paid, $date, $paid, $paymentDate, $method, $method === 'CASH' ? 'Caisse principale' : 'Banque BIAT - compte démo', 'REG-' . substr($paymentDate, 0, 4) . '-' . sprintf('%07d', $i + 1), $tenantId, $paymentDate . ' 15:30:00']);
        }

        if ($validated && in_array($status, ['OVERDUE', 'UNPAID'], true) && count($creditCandidates) < $counts['credit_notes'] && $i % 3 === 0) {
            $creditCandidates[] = ['invoice_id' => $invoiceId, 'client_id' => $clientIds[$clientIndex], 'client_index' => $clientIndex, 'date' => $date, 'line' => lineForProduct($products[array_search($lines[0]['product_id'], array_column($products, 'id'), true)], 1)];
        }
        if (($i + 1) % 3000 === 0) echo '    invoices generated: ' . ($i + 1) . PHP_EOL;
    }
    echo '  sales invoices: ' . count($invoiceIds) . PHP_EOL;

    for ($i = 0; $i < min($counts['credit_notes'], count($creditCandidates)); $i++) {
        $source = $creditCandidates[$i];
        $date = addDays($source['date'], 8 + ($i % 20));
        $line = $source['line'];
        $totals = sumLines([$line]);
        $number = documentNumber($sequences, 'AVOIR', 'AV', $date);
        $creditId = executeStatement($insertInvoice, [$number, sprintf('client.%04d@demo-tunisie.example', $source['client_index'] + 1), (string)$source['client_id'], $salespeople[$i % count($salespeople)], 0, 0, $source['invoice_id'], 'DIRECT', $date, $date, 'TND', 1, $date, $totals['subtotal'], $totals['subtotal'], amount($totals['subtotal'] + $totals['fodec']), $totals['vat'], $totals['tax'], $totals['total'], 0, 0, $totals['vat'], $totals['total'], $totals['total'], DEMO_MARKER . ' - Avoir partiel lié à la facture ' . $source['invoice_id'], 'AVOIR', 1, 'PAID', 'NOT_TRANSFORMED', 1, 0, null, $date . ' 13:00:00', null, null, null, $tenantId]);
        $insertInvoiceLines($creditId, $number, $date, [$line]);
        $product = $products[array_search($line['product_id'], array_column($products, 'id'), true)];
        $addMovement($product, 'RETURN_IN', (float)$line['qty'], 'CREDIT_NOTE', $creditId, $date, 'Retour lié à l’avoir ' . $number);
    }
    echo '  credit notes: ' . min($counts['credit_notes'], count($creditCandidates)) . PHP_EOL;

    $supplierPaymentIds = [];
    for ($i = 0; $i < $counts['supplier_orders']; $i++) {
        $date = distributedDate($i, $counts['supplier_orders']);
        $supplierId = $supplierIds[($i * 7) % count($supplierIds)];
        $lines = [
            lineForProduct($workflowProducts[($i * 3) % count($workflowProducts)], 8 + ($i % 18)),
            lineForProduct($workflowProducts[($i * 5 + 13) % count($workflowProducts)], 6 + (($i * 2) % 14)),
            lineForProduct($workflowProducts[($i * 11 + 29) % count($workflowProducts)], 10 + (($i * 3) % 20)),
        ];
        foreach ($lines as &$line) {
            $line['price'] = amount(max(1, $line['cost']));
            $line['subtotal'] = amount($line['qty'] * $line['price']);
            $line['fodec'] = 0.0;
            $line['vat'] = amount($line['subtotal'] * $line['vat_rate'] / 100);
            $line['tax'] = $line['vat'];
            $line['total'] = amount($line['subtotal'] + $line['vat']);
        }
        unset($line);
        $totals = sumLines($lines);
        $status = $i < $counts['supplier_receptions'] ? 'RECEIVED' : ($i % 3 === 0 ? 'DRAFT' : 'SENT');
        $orderNumber = sprintf('PO-TN%02d-%04d-%06d', $tenantId, (int)substr($date, 0, 4), $i + 1);
        $orderId = executeStatement($insertSupplierOrder, [$orderNumber, $supplierId, $date, addDays($date, 10 + ($i % 20)), DEMO_MARKER . ' - Commande fournisseur', $status, $totals['subtotal'], $totals['vat'], $totals['total'], $tenantId, $date . ' 08:00:00']);
        foreach ($lines as $line) executeStatement($insertSupplierOrderItem, [$orderId, $line['product_id'], $line['code'], $line['name'], 'PRODUCT', $line['qty'], $line['price'], $line['vat_rate'], $line['unit'], $line['total'], $date . ' 08:05:00']);

        if ($i >= $counts['supplier_receptions']) continue;
        $receivedDate = addDays($date, 4 + ($i % 12));
        $supplierDocument = sprintf('FF-%04d-%06d', (int)substr($receivedDate, 0, 4), $i + 1);
        $receptionId = executeStatement($insertReception, [$supplierId, $orderId, $supplierDocument, $receivedDate, $receivedDate, DEMO_MARKER . ' - Réception fournisseur contrôlée', $receivedDate . ' 14:00:00', $totals['subtotal'], $totals['vat'], $totals['total'], $tenantId, $receivedDate . ' 14:00:00']);
        $receptionItemIds = [];
        foreach ($lines as $line) {
            $receptionItemIds[] = executeStatement($insertReceptionItem, [$receptionId, $line['product_id'], $line['code'], $line['name'], 'PRODUCT', $line['qty'], $line['qty'], $line['qty'], 0, 0, null, $line['qty'], $line['price'], $products[array_search($line['product_id'], array_column($products, 'id'), true)]['price'], $line['subtotal'], $line['vat_rate'], $line['unit'], $receivedDate . ' 14:05:00']);
            $product = $products[array_search($line['product_id'], array_column($products, 'id'), true)];
            $addMovement($product, 'SUPPLIER_IN', (float)$line['qty'], 'SUPPLIER_RECEPTION', $receptionId, $receivedDate, 'Entrée fournisseur ' . $supplierDocument);
        }

        $billMode = $i % 10;
        $billStatus = $billMode < 6 ? 'PAID' : ($billMode < 8 ? 'PARTIALLY_PAID' : 'VALIDATED');
        $dueDate = addDays($receivedDate, [30, 45, 60][$i % 3]);
        $supplierInvoiceId = executeStatement($insertSupplierInvoice, [$tenantId, $supplierId, $orderId, $supplierDocument, $receivedDate, $dueDate, $billStatus, $receivedDate, $totals['subtotal'], $totals['subtotal'], $totals['vat'], $totals['tax'], $totals['total'], $totals['total'], DEMO_MARKER . ' - Facture fournisseur liée à la réception', $tenantId, $receivedDate . ' 15:00:00', $receivedDate . ' 14:30:00']);
        foreach ($lines as $lineIndex => $line) {
            $deductible = amount($line['vat'] * $line['deductibility'] / 100);
            $nonDeductible = amount($line['vat'] - $deductible);
            executeStatement($insertSupplierInvoiceItem, [$supplierInvoiceId, $receptionItemIds[$lineIndex], $line['product_id'], $line['profile_id'], $line['name'], $line['qty'], $line['price'], $line['vat_rate'], 0, 0, $line['tax_regime'], $line['deductibility'], $line['legal_basis'], '', $line['subtotal'], $line['subtotal'], $line['vat'], $deductible, $nonDeductible, $line['tax'], $line['total'], $line['total']]);
        }
        if ($billStatus !== 'VALIDATED') {
            $paid = $billStatus === 'PAID' ? $totals['total'] : amount($totals['total'] * 0.47);
            $paymentDate = addDays($receivedDate, 5 + ($i % 25));
            $method = $paymentMethods[($i + 2) % count($paymentMethods)];
            $supplierPaymentIds[] = executeStatement($insertSupplierPayment, [$tenantId, $supplierInvoiceId, $paid, $receivedDate, $paid, $paymentDate, $method, $method === 'CASH' ? 'Caisse achats' : 'Banque BIAT - achats', 'FR-' . substr($paymentDate, 0, 4) . '-' . sprintf('%06d', $i + 1), $tenantId, $paymentDate . ' 16:00:00']);
        }
    }
    echo '  supplier orders/receptions/invoices: ' . $counts['supplier_orders'] . '/' . $counts['supplier_receptions'] . '/' . $counts['supplier_receptions'] . PHP_EOL;

    $expenseCategories = ['Carburant', 'Télécommunications', 'Loyer', 'Électricité et eau', 'Déplacement', 'Entretien', 'Fournitures', 'Honoraires', 'Assurance', 'Marketing'];
    $expenseTitles = ['Frais mensuels', 'Achat ponctuel', 'Intervention technique', 'Abonnement professionnel', 'Mission régionale', 'Entretien des locaux'];
    for ($i = 0; $i < $counts['expenses']; $i++) {
        $date = distributedDate($i, $counts['expenses']);
        $status = $i % 10 < 7 ? 'APPROVED' : ($i % 10 === 7 ? 'REIMBURSED' : ($i % 10 === 8 ? 'PENDING' : 'REJECTED'));
        $value = amount(23.5 + (($i * 97) % 6800) + (($i * 37) % 1000) / 1000);
        executeStatement($insertExpense, [$tenantId, $i % 4 === 0 ? $supplierIds[$i % count($supplierIds)] : null, $expenseTitles[$i % count($expenseTitles)] . ' - ' . sprintf('%05d', $i + 1), $expenseCategories[$i % count($expenseCategories)], $value, $date, DEMO_MARKER . ' - Dépense tunisienne synthétique', $status, $date . ' 17:00:00']);
    }
    echo '  expenses: ' . $counts['expenses'] . PHP_EOL;

    foreach ($stockProducts as $index => $product) {
        $desired = $index % 37 === 0 ? (float)($index % 4) : (float)(25 + (($index * 17) % 480));
        $initial = amount($desired - ($stockDelta[$product['id']] ?? 0));
        if ($initial < 0) {
            $initial = 0.0;
            $desired = amount($stockDelta[$product['id']] ?? 0);
        }
        if ($initial > 0) {
            executeStatement($insertMovement, [$tenantId, $product['id'], 'INITIAL', $initial, $product['cost'], amount($initial * $product['cost']), 0, 'PRODUCT', $product['id'], 'OPENING_BALANCE', null, DEMO_MARKER . '-INITIAL-' . $product['id'], 'Stock initial reconstitué pour le jeu de démonstration', '2023-12-31 18:00:00']);
        }
        $conn->execute_query('UPDATE products SET stock_quantity=? WHERE id=? AND user_id=?', [$desired, $product['id'], $tenantId]);
    }

    foreach ($sequences as $key => $lastNumber) {
        [$type, $year] = explode(':', $key);
        $conn->execute_query('INSERT INTO erp_document_number_sequences(user_id,document_type,document_year,next_number) VALUES(?,?,?,?) ON DUPLICATE KEY UPDATE next_number=VALUES(next_number)', [$tenantId, $type, (int)$year, $lastNumber]);
    }

    $periodStart = new DateTimeImmutable('2024-01-01');
    $periodEnd = new DateTimeImmutable('2026-08-01');
    for ($month = $periodStart; $month <= $periodEnd; $month = $month->modify('+1 month')) {
        $from = $month->format('Y-m-01');
        $to = monthEnd($from);
        $conn->execute_query('INSERT INTO erp_accounting_periods(user_id,period_start,period_end,status,created_at) VALUES(?,?,?,\'DRAFT\',?)', [$tenantId, $from, $to, $from . ' 08:00:00']);
    }
    $presets = [['Mois en cours', 'CURRENT_MONTH'], ['Mois précédent', 'PREVIOUS_MONTH'], ['Trimestre en cours', 'CURRENT_QUARTER'], ['Exercice 2026', 'CURRENT_YEAR'], ['30 derniers jours', 'LAST_30_DAYS']];
    foreach ($presets as [$name, $kind]) $conn->execute_query('INSERT INTO erp_report_presets(user_id,name,period_kind,created_by) VALUES(?,?,?,?)', [$tenantId, $name, $kind, $tenantId]);

    $conn->commit();
} catch (Throwable $error) {
    $conn->rollback();
    failSeed('SEED FAILED and was rolled back: ' . $error->getMessage() . ' at ' . $error->getFile() . ':' . $error->getLine());
}

$tables = ['clients', 'suppliers', 'products', 'erp_invoices', 'erp_invoice_items', 'erp_invoice_payments', 'erp_invoice_withholdings', 'erp_sales_orders', 'erp_sales_order_items', 'erp_delivery_notes', 'erp_delivery_note_items', 'erp_supplier_orders', 'erp_supplier_order_items', 'erp_supplier_receptions', 'erp_supplier_reception_items', 'erp_supplier_invoices', 'erp_supplier_invoice_items', 'erp_supplier_payments', 'expense_notes', 'product_stock_movements'];
$summary = [];
foreach ($tables as $table) {
    $ownerColumn = in_array($table, ['erp_invoice_items', 'erp_sales_order_items', 'erp_delivery_note_items', 'erp_supplier_order_items', 'erp_supplier_reception_items', 'erp_supplier_invoice_items'], true) ? null : 'user_id';
    if ($ownerColumn) {
        $summary[$table] = (int)$conn->execute_query("SELECT COUNT(*) FROM `$table` WHERE user_id=?", [$tenantId])->fetch_row()[0];
    } else {
        $joins = [
            'erp_invoice_items' => 'JOIN erp_invoices p ON p.id=x.invoice_id',
            'erp_sales_order_items' => 'JOIN erp_sales_orders p ON p.id=x.sales_order_id',
            'erp_delivery_note_items' => 'JOIN erp_delivery_notes p ON p.id=x.delivery_note_id',
            'erp_supplier_order_items' => 'JOIN erp_supplier_orders p ON p.id=x.supplier_order_id',
            'erp_supplier_reception_items' => 'JOIN erp_supplier_receptions p ON p.id=x.supplier_reception_id',
            'erp_supplier_invoice_items' => 'JOIN erp_supplier_invoices p ON p.id=x.supplier_invoice_id',
        ];
        $summary[$table] = (int)$conn->execute_query("SELECT COUNT(*) FROM `$table` x {$joins[$table]} WHERE p.user_id=?", [$tenantId])->fetch_row()[0];
    }
}
echo json_encode(['success' => true, 'marker' => DEMO_MARKER, 'tenant_id' => $tenantId, 'database' => $database, 'counts' => $summary], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) . PHP_EOL;

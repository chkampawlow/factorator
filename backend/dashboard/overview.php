<?php

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, private');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../config/field_projection.php';
require_once __DIR__ . '/cache.php';
require_once __DIR__ . '/revenue_series.php';
require_once __DIR__ . '/../bon_livraisons/workflow_summary.php';


/*
|--------------------------------------------------------------------------
| Helpers
|--------------------------------------------------------------------------
*/

function dashOne(
    mysqli $conn,
    string $sql,
    string $types,
    array $args
): array {
    $stmt = $conn->prepare($sql);

    if (!$stmt) {
        throw new RuntimeException(
            'Dashboard query prepare failed: ' . $conn->error
        );
    }

    if ($types !== '') {
        $stmt->bind_param($types, ...$args);
    }

    $stmt->execute();

    $row = $stmt
        ->get_result()
        ->fetch_assoc() ?: [];

    $stmt->close();

    return $row;
}


function dashRows(
    mysqli $conn,
    string $sql,
    string $types,
    array $args
): array {
    $stmt = $conn->prepare($sql);

    if (!$stmt) {
        throw new RuntimeException(
            'Dashboard query prepare failed: ' . $conn->error
        );
    }

    if ($types !== '') {
        $stmt->bind_param($types, ...$args);
    }

    $stmt->execute();

    $rows = $stmt
        ->get_result()
        ->fetch_all(MYSQLI_ASSOC);

    $stmt->close();

    return $rows;
}


function dashInt(mixed $value): int
{
    return (int)($value ?? 0);
}


function dashFloat(mixed $value): float
{
    return round(
        (float)($value ?? 0),
        3
    );
}


/*
|--------------------------------------------------------------------------
| Main
|--------------------------------------------------------------------------
*/

try {

    /*
    |--------------------------------------------------------------------------
    | Method
    |--------------------------------------------------------------------------
    */

    $pricingRequiredCount = 0;

    if (
        ($_SERVER['REQUEST_METHOD'] ?? 'GET')
        !== 'GET'
    ) {
        jsonResponse([
            'success' => false,
            'message' => 'Method not allowed.',
            'error_code' => 'METHOD_NOT_ALLOWED',
        ], 405);
    }


    /*
    |--------------------------------------------------------------------------
    | Authentication
    |--------------------------------------------------------------------------
    */

    $auth = requireAuth();

    $conn = db();

    /*
     * Actor = actual employee/user currently signed in.
     *
     * Tenant = company workspace whose business data we are reading.
     */
    $actorId = authActorId($auth);
    $tenantId = authTenantId($auth);

    if (
        $actorId <= 0 ||
        $tenantId <= 0
    ) {
        throw new RuntimeException(
            'Invalid authenticated workspace context.'
        );
    }


    /*
    |--------------------------------------------------------------------------
    | Permission
    |--------------------------------------------------------------------------
    */

    requirePermission(
        $conn,
        $actorId,
        'dashboard.view'
    );


    /*
    |--------------------------------------------------------------------------
    | Role
    |--------------------------------------------------------------------------
    */

    $role = normalizeUserRole(
        $auth->role ?? null
    );

    if ($role === 'UNAUTHORIZED') {
        jsonResponse([
            'success' => false,
            'message' => 'Your role cannot access this workspace.',
            'error_code' => 'FORBIDDEN',
        ], 403);
    }


    $isAdministrator =
        $role === 'ADMINISTRATOR';

    $isCommercial =
        $role === 'COMMERCIAL';

    $isStock =
        $role === 'STOCK';

    $isAccounting =
        $role === 'ACCOUNTING';


    /*
    |--------------------------------------------------------------------------
    | Permissions
    |--------------------------------------------------------------------------
    */

    $canInvoices =
        userHasPermission(
            $conn,
            $actorId,
            'invoices.view'
        );

    $canDevis =
        userHasPermission(
            $conn,
            $actorId,
            'devis.view'
        );

    $canOrders =
        userHasPermission(
            $conn,
            $actorId,
            'orders.view'
        );

    $canDeliveries =
        userHasPermission(
            $conn,
            $actorId,
            'deliveries.view'
        );

    $canClients =
        userHasPermission(
            $conn,
            $actorId,
            'clients.view'
        );

    $canProducts =
        userHasPermission(
            $conn,
            $actorId,
            'products.view'
        );

    $canStock =
        userHasPermission(
            $conn,
            $actorId,
            'stock.view'
        );

    $canSuppliers =
        userHasPermission(
            $conn,
            $actorId,
            'suppliers.view'
        );

    $canSupplierOrders =
        userHasPermission(
            $conn,
            $actorId,
            'supplierOrders.view'
        );

    $canExpenses =
        userHasPermission(
            $conn,
            $actorId,
            'expenses.view'
        );

    $canReports =
        userHasPermission(
            $conn,
            $actorId,
            'reports.view'
        );

    $canPayments =
        userHasPermission(
            $conn,
            $actorId,
            'payments.view'
        )
        ||
        userHasPermission(
            $conn,
            $actorId,
            'payments.manage'
        );

    $canWithholding =
        userHasPermission(
            $conn,
            $actorId,
            'withholding.view'
        )
        ||
        userHasPermission(
            $conn,
            $actorId,
            'withholding.manage'
        );


    /*
    |--------------------------------------------------------------------------
    | Cache
    |--------------------------------------------------------------------------
    |
    | Cache is tied to the logged-in actor so STOCK and COMMERCIAL users
    | don't accidentally receive an administrator dashboard response.
    |--------------------------------------------------------------------------
    */

    [
        $cacheHandle,
        $cached
    ] = dashboardCacheAcquire(
        $actorId
    );

    if ($cached !== null) {
        jsonResponse($cached);
    }


    /*
    |--------------------------------------------------------------------------
    | Dates
    |--------------------------------------------------------------------------
    */

    $month = date('Y-m-01');
    $today = date('Y-m-d');


    /*
    |--------------------------------------------------------------------------
    | Base payload
    |--------------------------------------------------------------------------
    */

    $payload = [

        'success' => true,

        'role' => $role,

        'workspace' => match ($role) {
            'ADMINISTRATOR' => 'ADMINISTRATION',
            'COMMERCIAL' => 'SALES',
            'STOCK' => 'INVENTORY',
            'ACCOUNTING' => 'ACCOUNTING',
            default => 'GENERAL',
        },

        'generated_at' =>
            date(DATE_ATOM),

        'capabilities' => [

            'invoices' =>
                $canInvoices,

            'devis' =>
                $canDevis,

            'orders' =>
                $canOrders,

            'deliveries' =>
                $canDeliveries,

            'clients' =>
                $canClients,

            'products' =>
                $canProducts,

            'stock' =>
                $canStock,

            'suppliers' =>
                $canSuppliers,

            'supplier_orders' =>
                $canSupplierOrders,

            'expenses' =>
                $canExpenses,

            'reports' =>
                $canReports,

            'payments' =>
                $canPayments,

            'withholding' =>
                $canWithholding,
        ],


        /*
         * Existing Angular-compatible fields.
         */

        'invoice' => [],

        'monthly_expenses' => 0,

        'workflow' => [
            'confirmed_orders' => 0,
            'pending_supplier_orders' => 0,
            'deliveries_to_invoice' => 0,
            'delivery_invoice_drafts' => 0,
        ],

        'low_stock_count' => 0,

        'low_stock' => [],

        'top_clients' => [],

        'top_products' => [],

        'recent_invoices' => [],

        'monthly_series' => [],


        /*
         * New role-aware data.
         */

        'attention' => [],

        'sales' => null,

        'inventory' => null,

        'accounting' => null,

        'administration' => null,
    ];


    /*
    |--------------------------------------------------------------------------
    | SALES / INVOICE DATA
    |--------------------------------------------------------------------------
    |
    | ADMINISTRATOR
    | COMMERCIAL
    | ACCOUNTING
    |--------------------------------------------------------------------------
    */

    if (
        $canInvoices
        &&
        (
            $isAdministrator ||
            $isCommercial ||
            $isAccounting
        )
    ) {

        $invoice = dashOne(
            $conn,

            "
            SELECT

                SUM(
                    invoice_type = 'FACTURE'
                    AND is_validated = 1
                    AND UPPER(status) <> 'CANCELLED'
                ) invoice_count,

                SUM(
                    invoice_type = 'FACTURE'
                    AND is_validated = 1
                    AND UPPER(status) IN (
                        'PAID',
                        'PAYED',
                        'PAID_IN_FULL'
                    )
                ) paid_count,

                SUM(
                    invoice_type = 'FACTURE'
                    AND is_validated = 1
                    AND UPPER(status) NOT IN (
                        'PAID',
                        'PAYED',
                        'PAID_IN_FULL',
                        'CANCELLED'
                    )
                    AND invoice_due_date >= ?
                ) unpaid_count,

                SUM(
                    invoice_type = 'FACTURE'
                    AND is_validated = 1
                    AND UPPER(status) NOT IN (
                        'PAID',
                        'PAYED',
                        'PAID_IN_FULL',
                        'CANCELLED'
                    )
                    AND invoice_due_date < ?
                ) overdue_count,

                SUM(
                    invoice_type = 'DEVIS'
                    AND UPPER(status) = 'ACCEPTED'
                    AND transformation_status NOT IN (
                        'FULLY_ORDERED',
                        'FULLY_TRANSFORMED'
                    )
                ) accepted_devis,

                ROUND(
                    COALESCE(
                        SUM(
                            CASE

                                WHEN
                                    invoice_type = 'AVOIR'
                                    AND is_validated = 1
                                    AND UPPER(status) <> 'CANCELLED'

                                THEN -ABS(subtotal_tnd)

                                WHEN
                                    invoice_type = 'FACTURE'
                                    AND is_validated = 1
                                    AND UPPER(status) <> 'CANCELLED'

                                THEN subtotal_tnd

                                ELSE 0

                            END
                        ),
                        0
                    ),
                    3
                ) revenue_total,

                ROUND(
                    COALESCE(
                        SUM(
                            CASE

                                WHEN
                                    invoice_date >= ?
                                    AND invoice_type = 'AVOIR'
                                    AND is_validated = 1
                                    AND UPPER(status) <> 'CANCELLED'

                                THEN -ABS(subtotal_tnd)

                                WHEN
                                    invoice_date >= ?
                                    AND invoice_type = 'FACTURE'
                                    AND is_validated = 1
                                    AND UPPER(status) <> 'CANCELLED'

                                THEN subtotal_tnd

                                ELSE 0

                            END
                        ),
                        0
                    ),
                    3
                ) monthly_revenue

            FROM erp_invoices

            WHERE user_id = ?
            ",

            'ssssi',

            [
                $today,
                $today,
                $month,
                $month,
                $tenantId,
            ]
        );


        $payload['invoice'] =
            $invoice;


        /*
        |--------------------------------------------------------------------------
        | Recent invoices
        |--------------------------------------------------------------------------
        */

        $recent = dashRows(
            $conn,

            "
            SELECT

                i.id,

                i.invoice,

                i.invoice_date,

                i.invoice_due_date,

                i.invoice_type,

                i.is_validated,

                i.status,

                i.total,

                i.total_tnd,

                i.currency,

                c.name client_name,

                i.custom_email

            FROM erp_invoices i

            LEFT JOIN clients c

                ON c.id =
                    CAST(
                        i.custom_code AS UNSIGNED
                    )

                AND c.user_id =
                    i.user_id

            WHERE

                i.user_id = ?

                AND i.invoice_type = 'FACTURE'

                AND i.is_validated = 1

                AND UPPER(i.status) <> 'CANCELLED'

            ORDER BY

                i.invoice_date DESC,

                i.id DESC

            LIMIT 6
            ",

            'i',

            [
                $tenantId
            ]
        );


        $payload['recent_invoices'] =
            $recent;


        /*
        |--------------------------------------------------------------------------
        | Sales workspace object
        |--------------------------------------------------------------------------
        */

        $payload['sales'] = [

            'invoice_count' =>
                dashInt(
                    $invoice['invoice_count']
                    ?? 0
                ),

            'paid_count' =>
                dashInt(
                    $invoice['paid_count']
                    ?? 0
                ),

            'unpaid_count' =>
                dashInt(
                    $invoice['unpaid_count']
                    ?? 0
                ),

            'overdue_count' =>
                dashInt(
                    $invoice['overdue_count']
                    ?? 0
                ),

            'accepted_devis' =>
                dashInt(
                    $invoice['accepted_devis']
                    ?? 0
                ),

            'revenue_total' =>
                dashFloat(
                    $invoice['revenue_total']
                    ?? 0
                ),

            'monthly_revenue' =>
                dashFloat(
                    $invoice['monthly_revenue']
                    ?? 0
                ),

            'recent_invoices' =>
                $recent,
        ];


        /*
        |--------------------------------------------------------------------------
        | Revenue curve
        |--------------------------------------------------------------------------
        |
        | Return a complete eight-month series. Missing months are filled with
        | zeroes so mobile clients can draw a real timeline instead of receiving
        | only the current aggregate.
        |--------------------------------------------------------------------------
        */

        $seriesStart = (new DateTimeImmutable($month))
            ->modify('-7 months')
            ->format('Y-m-01');
        $seriesEnd = (new DateTimeImmutable($month))
            ->modify('+1 month')
            ->format('Y-m-01');

        $revenueRows = dashRows(
            $conn,
            "
            SELECT
                DATE_FORMAT(invoice_date, '%Y-%m') month,
                ROUND(
                    COALESCE(
                        SUM(
                            CASE
                                WHEN invoice_type = 'AVOIR' THEN -ABS(subtotal_tnd)
                                WHEN invoice_type = 'FACTURE' THEN subtotal_tnd
                                ELSE 0
                            END
                        ),
                        0
                    ),
                    3
                ) revenue
            FROM erp_invoices
            WHERE user_id = ?
              AND invoice_date >= ?
              AND invoice_date < ?
              AND invoice_type IN ('FACTURE', 'AVOIR')
              AND is_validated = 1
              AND UPPER(status) <> 'CANCELLED'
            GROUP BY DATE_FORMAT(invoice_date, '%Y-%m')
            ORDER BY month
            ",
            'iss',
            [$tenantId, $seriesStart, $seriesEnd]
        );

        $payload['monthly_series'] = dashboardMonthlyRevenueSeries(
            $revenueRows,
            $month,
            8
        );
        $payload['sales']['monthly_series'] = $payload['monthly_series'];


        /*
        |--------------------------------------------------------------------------
        | Invoice attention
        |--------------------------------------------------------------------------
        */

        $overdueCount =
            dashInt(
                $invoice['overdue_count']
                ?? 0
            );

        if ($overdueCount > 0) {

            $payload['attention'][] = [

                'type' =>
                    'OVERDUE_INVOICES',

                'tone' =>
                    'warning',

                'count' =>
                    $overdueCount,

                'route' =>
                    '/invoices',

                'query' => [
                    'status' =>
                        'OVERDUE',
                ],
            ];
        }


        $acceptedCount =
            dashInt(
                $invoice['accepted_devis']
                ?? 0
            );

        if (
            $acceptedCount > 0
            &&
            $canDevis
        ) {

            $payload['attention'][] = [

                'type' =>
                    'ACCEPTED_DEVIS',

                'tone' =>
                    'info',

                'count' =>
                    $acceptedCount,

                'route' =>
                    '/devis',

                'query' => [
                    'status' =>
                        'ACCEPTED',
                ],
            ];
        }
    }


    /*
    |--------------------------------------------------------------------------
    | Commercial workflow
    |--------------------------------------------------------------------------
    */

    if (
        $isAdministrator ||
        $isCommercial
    ) {

        /*
        |--------------------------------------------------------------------------
        | Sales orders
        |--------------------------------------------------------------------------
        */

        if ($canOrders) {

            $orderWorkflow =
                dashOne(
                    $conn,

                    "
                    SELECT

                        COUNT(*) confirmed_orders

                    FROM erp_sales_orders

                    WHERE

                        user_id = ?

                        AND status IN (
                            'CONFIRMED',
                            'PARTIALLY_DELIVERED'
                        )
                    ",

                    'i',

                    [
                        $tenantId
                    ]
                );


            $payload['workflow']['confirmed_orders'] =
                dashInt(
                    $orderWorkflow['confirmed_orders']
                    ?? 0
                );
        }


        /*
        |--------------------------------------------------------------------------
        | Delivery workflow
        |--------------------------------------------------------------------------
        */

        if ($canDeliveries) {

            $deliveryWorkflow =
                deliveryWorkflowSummary(
                    $conn,
                    $tenantId
                );


            $payload['workflow']['deliveries_to_invoice'] =
                dashInt(
                    $deliveryWorkflow['ready_to_invoice']
                    ?? 0
                );


            $payload['workflow']['delivery_invoice_drafts'] =
                dashInt(
                    $deliveryWorkflow['invoice_drafts']
                    ?? 0
                );


            if (
                $payload['workflow']['deliveries_to_invoice']
                > 0
            ) {

                $payload['attention'][] = [

                    'type' =>
                        'DELIVERIES_TO_INVOICE',

                    'tone' =>
                        'warning',

                    'count' =>
                        $payload['workflow']['deliveries_to_invoice'],

                    'route' =>
                        '/deliveries',

                    'query' => [
                        'status' =>
                            'DELIVERED',
                    ],
                ];
            }


            if (
                $payload['workflow']['delivery_invoice_drafts']
                > 0
            ) {

                $payload['attention'][] = [

                    'type' =>
                        'INVOICE_DRAFTS',

                    'tone' =>
                        'info',

                    'count' =>
                        $payload['workflow']['delivery_invoice_drafts'],

                    'route' =>
                        '/invoices',

                    'query' => [
                        'status' =>
                            'DRAFT',
                    ],
                ];
            }
        }


        /*
        |--------------------------------------------------------------------------
        | Top clients
        |--------------------------------------------------------------------------
        */

        if (
            $canClients
            &&
            $canInvoices
        ) {

            $topClients =
                dashRows(
                    $conn,

                    "
                    SELECT

                        COALESCE(
                            cl.name,
                            i.custom_email,
                            ''
                        ) label,

                        ROUND(
                            SUM(
                                CASE

                                    WHEN i.invoice_type = 'AVOIR'

                                    THEN -ABS(i.subtotal_tnd)

                                    ELSE i.subtotal_tnd

                                END
                            ),
                            3
                        ) value

                    FROM erp_invoices i

                    LEFT JOIN clients cl

                        ON cl.id =
                            CAST(
                                i.custom_code AS UNSIGNED
                            )

                        AND cl.user_id =
                            i.user_id

                    WHERE

                        i.user_id = ?

                        AND i.is_validated = 1

                        AND i.invoice_type IN (
                            'FACTURE',
                            'AVOIR'
                        )

                        AND UPPER(i.status)
                            <> 'CANCELLED'

                    GROUP BY

                        COALESCE(
                            cl.name,
                            i.custom_email,
                            ''
                        )

                    ORDER BY
                        value DESC

                    LIMIT 5
                    ",

                    'i',

                    [
                        $tenantId
                    ]
                );


            $payload['top_clients'] =
                $topClients;


            if (
                is_array(
                    $payload['sales']
                )
            ) {
                $payload['sales']['top_clients'] =
                    $topClients;
            }
        }
    }


    /*
    |--------------------------------------------------------------------------
    | STOCK WORKSPACE
    |--------------------------------------------------------------------------
    |
    | ADMINISTRATOR
    | STOCK
    |--------------------------------------------------------------------------
    */

    if (
        ($isAdministrator || $isStock)
        &&
        ($canProducts || $canStock)
    ) {

        /*
        |--------------------------------------------------------------------------
        | Product counts
        |--------------------------------------------------------------------------
        */

        $productStats =
            dashOne(
                $conn,

                "
                SELECT

                    COUNT(*) product_count,

                    SUM(
                        stock_quantity < reorder_point
                    ) low_stock_count,

                    SUM(
                        stock_quantity <= 0
                    ) zero_stock_count,

                    SUM(
                        selling_price_required = 1
                    ) pricing_required_count

                FROM products

                WHERE

                    user_id = ?

                    AND item_type = 'PRODUCT'
                ",

                'i',

                [
                    $tenantId
                ]
            );


        $productCount =
            dashInt(
                $productStats['product_count']
                ?? 0
            );


        $lowStockCount =
            dashInt(
                $productStats['low_stock_count']
                ?? 0
            );


        $zeroStockCount =
            dashInt(
                $productStats['zero_stock_count']
                ?? 0
            );

        $pricingRequiredCount =
            dashInt(
                $productStats['pricing_required_count']
                ?? 0
            );


        /*
        |--------------------------------------------------------------------------
        | Low stock
        |--------------------------------------------------------------------------
        */

        $lowStock =
            dashRows(
                $conn,

                "
                SELECT

                    name label,

                    stock_quantity value,

                    unit,

                    reorder_point

                FROM products

                WHERE

                    user_id = ?

                    AND item_type = 'PRODUCT'

                    AND stock_quantity < reorder_point

                ORDER BY

                    stock_quantity,

                    name

                LIMIT 8
                ",

                'i',

                [
                    $tenantId
                ]
            );


        /*
        |--------------------------------------------------------------------------
        | Top products
        |--------------------------------------------------------------------------
        */

        $topProducts =
            dashRows(
                $conn,

                "
                SELECT

                    COALESCE(
                        NULLIF(ii.product, ''),
                        NULLIF(ii.product_code, ''),
                        ''
                    ) label,

                    ROUND(
                        SUM(
                            CASE

                                WHEN i.invoice_type = 'AVOIR'

                                THEN -ii.qty

                                ELSE ii.qty

                            END
                        ),
                        3
                    ) value

                FROM erp_invoice_items ii

                JOIN erp_invoices i
                    ON i.id = ii.invoice_id

                WHERE

                    i.user_id = ?

                    AND i.is_validated = 1

                    AND i.invoice_type IN (
                        'FACTURE',
                        'AVOIR'
                    )

                    AND UPPER(i.status)
                        <> 'CANCELLED'

                GROUP BY

                    COALESCE(
                        NULLIF(ii.product_code, ''),
                        NULLIF(ii.product, ''),
                        ''
                    ),

                    COALESCE(
                        NULLIF(ii.product, ''),
                        NULLIF(ii.product_code, ''),
                        ''
                    )

                HAVING value <> 0

                ORDER BY
                    value DESC

                LIMIT 8
                ",

                'i',

                [
                    $tenantId
                ]
            );


        /*
        |--------------------------------------------------------------------------
        | Supplier workflow
        |--------------------------------------------------------------------------
        */

        $pendingSupplierOrders = 0;


        if ($canSupplierOrders) {

            $supplierWorkflow =
                dashOne(
                    $conn,

                    "
                    SELECT

                        COUNT(*) pending_supplier_orders,

                        SUM(
                            status = 'PARTIALLY_RECEIVED'
                        ) partial_receptions

                    FROM erp_supplier_orders

                    WHERE

                        user_id = ?

                        AND status IN (
                            'SENT',
                            'PARTIALLY_RECEIVED'
                        )
                    ",

                    'i',

                    [
                        $tenantId
                    ]
                );


            $pendingSupplierOrders =
                dashInt(
                    $supplierWorkflow['pending_supplier_orders']
                    ?? 0
                );


            $pendingReceptions =
                dashInt(
                    $supplierWorkflow['partial_receptions']
                    ?? 0
                );

        } else {

            $pendingReceptions = 0;
        }


        /*
        |--------------------------------------------------------------------------
        | Stock delivery workload
        |--------------------------------------------------------------------------
        */

        $stockDeliveryWorkflow = [];

        if ($canDeliveries) {

            $stockDeliveryWorkflow =
                deliveryWorkflowSummary(
                    $conn,
                    $tenantId
                );
        }


        /*
        |--------------------------------------------------------------------------
        | Compatibility
        |--------------------------------------------------------------------------
        */

        $payload['workflow']['pending_supplier_orders'] =
            $pendingSupplierOrders;


        $payload['low_stock_count'] =
            $lowStockCount;


        $payload['low_stock'] =
            $lowStock;


        $payload['top_products'] =
            $topProducts;


        /*
        |--------------------------------------------------------------------------
        | Inventory object
        |--------------------------------------------------------------------------
        */

        $payload['inventory'] = [

            'product_count' =>
                $productCount,

            'low_stock_count' =>
                $lowStockCount,

            'zero_stock_count' =>
                $zeroStockCount,

            'pricing_required_count' =>
                $pricingRequiredCount,

            'pending_supplier_orders' =>
                $pendingSupplierOrders,

            'pending_receptions' =>
                $pendingReceptions,

            'deliveries_ready_to_invoice' =>
                dashInt(
                    $stockDeliveryWorkflow['ready_to_invoice']
                    ?? 0
                ),

            'low_stock' =>
                $lowStock,

            'top_products' =>
                $topProducts,
        ];


        /*
        |--------------------------------------------------------------------------
        | Stock attention
        |--------------------------------------------------------------------------
        */

        if ($lowStockCount > 0) {

            $payload['attention'][] = [

                'type' =>
                    'LOW_STOCK',

                'tone' =>
                    'warning',

                'count' =>
                    $lowStockCount,

                'route' =>
                    '/products',

                'query' => [
                    'stock' =>
                        'low',
                ],
            ];
        }


        if ($zeroStockCount > 0) {

            $payload['attention'][] = [

                'type' =>
                    'OUT_OF_STOCK',

                'tone' =>
                    'danger',

                'count' =>
                    $zeroStockCount,

                'route' =>
                    '/products',

                'query' => [
                    'stock' =>
                        'low',
                ],
            ];
        }


        if ($pendingSupplierOrders > 0) {

            $payload['attention'][] = [

                'type' =>
                    'SUPPLIER_ORDERS_PENDING',

                'tone' =>
                    'info',

                'count' =>
                    $pendingSupplierOrders,

                'route' =>
                    '/supplier-orders',
            ];
        }
    }


    /*
    |--------------------------------------------------------------------------
    | ACCOUNTING WORKSPACE
    |--------------------------------------------------------------------------
    |
    | ADMINISTRATOR
    | ACCOUNTING
    |--------------------------------------------------------------------------
    */

    if (
        $isAdministrator ||
        $isAccounting
    ) {

        /*
        |--------------------------------------------------------------------------
        | Expenses
        |--------------------------------------------------------------------------
        */

        $monthlyExpenses = 0.0;


        if (
            $canExpenses ||
            $canReports
        ) {

            $expense =
                dashOne(
                    $conn,

                    "
                    SELECT

                        ROUND(
                            COALESCE(
                                SUM(amount),
                                0
                            ),
                            3
                        ) monthly_expenses

                    FROM expense_notes

                    WHERE

                        user_id = ?

                        AND expense_date >= ?

                        AND status IN (
                            'APPROVED',
                            'REIMBURSED'
                        )
                    ",

                    'is',

                    [
                        $tenantId,
                        $month
                    ]
                );


            $monthlyExpenses =
                dashFloat(
                    $expense['monthly_expenses']
                    ?? 0
                );
        }


        $payload['monthly_expenses'] =
            $monthlyExpenses;


        /*
        |--------------------------------------------------------------------------
        | Use information we KNOW exists right now.
        |--------------------------------------------------------------------------
        |
        | We'll add payment tables, withholding status,
        | VAT periods and supplier invoice aging after verifying their exact
        | schemas instead of guessing column names.
        |--------------------------------------------------------------------------
        */

        $payload['accounting'] = [

            'monthly_expenses' =>
                $monthlyExpenses,

            'monthly_revenue' =>
                dashFloat(
                    $payload['invoice']['monthly_revenue']
                    ?? 0
                ),

            'revenue_total' =>
                dashFloat(
                    $payload['invoice']['revenue_total']
                    ?? 0
                ),

            'invoice_count' =>
                dashInt(
                    $payload['invoice']['invoice_count']
                    ?? 0
                ),

            'paid_count' =>
                dashInt(
                    $payload['invoice']['paid_count']
                    ?? 0
                ),

            'unpaid_count' =>
                dashInt(
                    $payload['invoice']['unpaid_count']
                    ?? 0
                ),

            'overdue_count' =>
                dashInt(
                    $payload['invoice']['overdue_count']
                    ?? 0
                ),

            'activity_difference' =>
                dashFloat(
                    (
                        $payload['invoice']['monthly_revenue']
                        ?? 0
                    )
                    -
                    $monthlyExpenses
                ),
        ];
    }


    /*
    |--------------------------------------------------------------------------
    | ADMINISTRATION WORKSPACE
    |--------------------------------------------------------------------------
    */

    if ($isAdministrator) {

        /*
        |--------------------------------------------------------------------------
        | Members
        |--------------------------------------------------------------------------
        */

        $membershipStats =
            dashOne(
                $conn,

                "
                SELECT

                    SUM(
                        status = 'ACTIVE'
                    ) active_members,

                    SUM(
                        status = 'SUSPENDED'
                    ) suspended_members,

                    SUM(
                        status = 'REVOKED'
                    ) revoked_members

                FROM company_memberships

                WHERE company_id = ?
                ",

                'i',

                [
                    $tenantId
                ]
            );


        /*
        |--------------------------------------------------------------------------
        | Invitations
        |--------------------------------------------------------------------------
        */

        $invitationStats =
            dashOne(
                $conn,

                "
                SELECT

                    SUM(
                        status = 'PENDING'
                        AND expires_at > NOW()
                    ) pending_invitations,

                    SUM(
                        status = 'ACCEPTED'
                    ) accepted_invitations,

                    SUM(
                        status = 'REVOKED'
                    ) revoked_invitations

                FROM company_invitations

                WHERE company_id = ?
                ",

                'i',

                [
                    $tenantId
                ]
            );


        $activeMembers =
            dashInt(
                $membershipStats['active_members']
                ?? 0
            );


        $pendingInvitations =
            dashInt(
                $invitationStats['pending_invitations']
                ?? 0
            );


        $payload['administration'] = [

            'active_members' =>
                $activeMembers,

            'suspended_members' =>
                dashInt(
                    $membershipStats['suspended_members']
                    ?? 0
                ),

            'revoked_members' =>
                dashInt(
                    $membershipStats['revoked_members']
                    ?? 0
                ),

            'pending_invitations' =>
                $pendingInvitations,

            'pricing_required_count' =>
                $pricingRequiredCount,

            'accepted_invitations' =>
                dashInt(
                    $invitationStats['accepted_invitations']
                    ?? 0
                ),

            'revoked_invitations' =>
                dashInt(
                    $invitationStats['revoked_invitations']
                    ?? 0
                ),
        ];


        if ($pendingInvitations > 0) {

            $payload['attention'][] = [

                'type' =>
                    'PENDING_INVITATIONS',

                'tone' =>
                    'info',

                'count' =>
                    $pendingInvitations,

                'route' =>
                    '/company-settings',
            ];
        }

        if ($pricingRequiredCount > 0) {
            $payload['attention'][] = [
                'type' => 'PRODUCT_PRICING_REQUIRED',
                'tone' => 'warning',
                'count' => $pricingRequiredCount,
                'route' => '/products',
                'query' => ['pricing' => 'required'],
            ];
        }
    }


    /*
    |--------------------------------------------------------------------------
    | Cache + response
    |--------------------------------------------------------------------------
    */

    $payload = projectDashboardFields($payload, $role);

    dashboardCacheStore(
        $cacheHandle,
        $payload
    );


    jsonResponse(
        $payload
    );


} catch (Throwable $e) {

    jsonResponse([
        'success' => false,

        'message' =>
            'Could not load dashboard.',

        'error_code' =>
            'DASHBOARD_OVERVIEW_FAILED',

    ], 500);
}

# El Fatoura Mobile ↔ Web Workflow Test Report

Audit started: 2026-09-08  
Flutter workspace: `factorator`  
Angular workspace: `el-fatoura-angular`  
Shared production API: `https://facture.myenv.digital/backend`

## Status legend

- **PASS** — exercised by an automated test or build.
- **PARTIAL** — some layers pass, but the complete authenticated workflow has not run.
- **BLOCKED** — a required deployed endpoint or test environment is unavailable.
- **PENDING** — requires an authenticated, isolated test company and manual cross-client verification.

## Automated baseline

| Check | Result | Evidence |
|---|---:|---|
| Flutter unit/model tests | **PASS** | 43/43 |
| Flutter macOS debug build | **PASS** | `facturation.app` built successfully |
| Angular production build | **PASS** | Production bundle generated |
| Angular unit tests | **PARTIAL** | 90/91; supplier matching incorrectly selects a line with `taxProfileId = 0` |
| Angular Playwright tests | **PARTIAL** | 12/15 |
| Backend document transition tests | **PASS** | 16/16 |
| Backend accountant arithmetic cases | **PASS** | 10/10 |
| Backend rounding cases | **PASS** | 6/6 |
| Backend company/session context checks | **PASS** | All checks passed |
| Backend field-projection/role checks | **PASS** | All checks passed |
| Local authenticated DB integration | **BLOCKED** | Local database connection unavailable |

The three Angular Playwright failures are currently test-harness regressions:

1. Two landing tests expect English while the application intentionally defaults to French.
2. The sales workflow uses `getByText('Consulting').first()`, which resolves to a hidden duplicate while a visible matching row is present.

The Angular unit failure is a real rule mismatch: `fetchSupplierMatchingOptions` selects a received line when quantity and product are valid, but does not require `taxProfileId > 0`, contrary to its test and intended invoice-validation rule.

## Production endpoint deployment

All 71 Flutter endpoint files exist in the local PHP backend. Read-only production probes found 64 routes returning structured JSON/auth/method responses and seven routes returning 404:

| Missing production endpoint | Mobile impact |
|---|---|
| `/accounting/mobile_review.php` | Accounting Review cannot load |
| `/notifications/list.php` | Notification Center cannot load its list |
| `/notifications/mark_read.php` | Read/unread and Mark All Read cannot work |
| `/products/barcode_lookup.php` | Product barcode scanning cannot resolve products |
| `/mailer/download_document_pdf.php` | Document Center server-PDF preview cannot load |
| `/supplier_invoices/available_sources.php` | Supplier-invoice source selection is unavailable |
| `/ai/assistant.php` | Assistant unavailable; navigation is disabled by default |

These local backend files must be deployed before the affected mobile workflows can pass against production.

## End-to-end workflow matrix

| Area | Cross-client scenario | Current status |
|---|---|---:|
| Authentication | Signup → verification → login → refresh → logout | **PENDING** |
| Authentication | Login with 2FA and invalid/expired challenge | **PENDING** |
| Password recovery | Request code → reset password → login | **PENDING** |
| Role navigation | Administrator, Commercial, Stock and Accounting see only authorized destinations | **PARTIAL** |
| Dashboard | Web activity appears in mobile totals, recent documents, chart and attention cards | **PENDING** |
| Notifications | Web/backend event appears on phone and read state synchronizes | **BLOCKED** |
| Global search | Search the same client/product/document in both applications | **PENDING** |
| Clients | Create on phone → edit on web → archive/delete → refresh both | **PENDING** |
| Products | Create/edit on web → inspect and edit on phone | **PENDING** |
| Barcode and stock | Scan → resolve product → adjust stock → verify web stock history | **BLOCKED** |
| Sales documents | Create invoice/devis, add/edit lines, validate and compare totals | **PENDING** |
| Settlement | Record/change status and verify payment balance in both applications | **PENDING** |
| Sales orders | Create/confirm on web → inspect on phone | **PENDING** |
| Deliveries | Create on web → confirm/deliver on phone → verify web workflow | **PENDING** |
| Expenses | Create/edit/approve/reimburse and compare both clients | **PENDING** |
| Supplier reception | Web supplier order → phone partial reception/discrepancy/photo → confirm → verify stock | **PENDING** |
| Document Center | Search/filter/open relations and compare source documents | **PARTIAL** |
| PDF | Generate/open the same document PDF in both clients | **BLOCKED** |
| Accounting Review | Compare receivables, payables, expenses and matching queues | **BLOCKED** |
| Profile/settings | Update company data and verify web; test local language/theme/image | **PENDING** |
| Localization | FR/EN/AR, RTL, long labels and numeric/date formatting | **PENDING** |
| Pagination | Verify records 101+ for clients, products, invoices, expenses and documents | **KNOWN FAILURE** |

## Known mobile pagination limitation

The PHP list endpoints support `page`, `page_size`, and `total`. Flutter's shared `getAllPages` helper defaults to one page of 100 records, and the primary list screens do not currently expose page controls or infinite scrolling. Therefore records after the first 100 are not reachable in those screens. Notifications separately attempt up to five pages, but their production endpoints are not deployed.

## Manual cross-client procedure

Use a temporary test company, never a production customer company. For every scenario:

1. Record the starting object IDs, totals, status and stock quantity in Angular.
2. Perform one authorized mutation in Flutter.
3. Refresh Angular and verify the same ID, values, status and audit effect.
4. Perform the reverse mutation in Angular.
5. Pull-to-refresh Flutter and verify the same result.
6. Repeat the read with a role that must be denied.
7. Verify a second company cannot access the first company's object ID.
8. Record API request ID and response code for any failure.

Required test identities:

- one Administrator test user;
- one Commercial user;
- one Stock user;
- one Accounting user;
- ideally a second isolated company for tenant-boundary checks.

Required fixture chain:

```text
Client + product
  → accepted quotation
  → confirmed sales order
  → confirmed/delivered delivery note
  → validated invoice
  → partial payment
  → final payment

Supplier + product
  → sent supplier order
  → partial/final reception
  → stock movement
  → matched supplier invoice
  → partial/final supplier payment
```

## Next execution gate

Authenticated CRUD testing should begin only after the missing PHP files are deployed and a disposable test company is available. The first live pass should cover authentication, dashboard, clients and products before moving into financial or stock-changing workflows.

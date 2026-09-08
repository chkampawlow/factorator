# El Fatoura — Flutter Mobile Companion Roadmap

## Goal

Build a role-oriented Flutter companion for the existing El Fatoura Angular + PHP + MariaDB ERP.

**Do not rebuild the whole ERP in Flutter.** Angular remains the complete office workspace. Flutter is the operational mobile app for Commercial, Stock, Logistics, Accounting, and Administrator users.

## 1. Architecture

```text
Flutter
  ↓
Existing PHP API
  ↓
Authentication + Active Company/Tenant
  ↓
Backend Permissions
  ↓
Existing Business Services
  ↓
MariaDB
```

Flutter must not create a second source of truth or duplicate stock, accounting, document, tenant, or permission logic.

## Current repository status

The roadmap is no longer purely prospective. The repository now contains the mobile foundation and a broad operational surface:

- real backend login/session refresh, active membership, permission gates, 2FA, verification, and password reset;
- dashboard, clients, products, invoices, sales orders, deliveries, supplier receptions, expenses, accounting review, documents, notifications, and global search;
- capture/extraction review, barcode scanning, PDF/XML views, and FR/EN/AR resources;
- 34 screen files, 88 Dart files, and nine test files;
- all 43 Flutter tests passing in the 2026-09-07 verification run;
- static analysis with no errors and 105 advisory warnings still requiring cleanup.

Items described as “later,” “future,” or “definition of done” remain release criteria until they are verified against the deployed API and physical-device workflows. The assistant is disabled by default behind `ASSISTANT_ENABLED`.

The backend currently assigns only `ADMINISTRATOR`, `COMMERCIAL`, `STOCK`, and `ACCOUNTING`. `LOGISTICS` in Flutter is a forward-compatible access profile, not a fifth deployed backend role.

## 2. Security First

Before building business screens:

- Reuse the existing authentication system.
- Resolve the active company/tenant correctly.
- Distinguish actor/user ID from company/tenant ID.
- Load the user's permissions.
- Treat Flutter permissions as UX only.
- Enforce every permission again in PHP.
- Validate every foreign ID against the active tenant.
- Preserve audit logging, transactions, idempotency and document locking.
- Never calculate authoritative accounting or stock values only on the phone.

## 3. Role-Aware Navigation

### Commercial
`Home | Clients | Sales | Documents | Assistant`

Focus:
- Clients
- Product availability
- Devis
- Sales orders
- Delivery progress
- Customer invoices
- Payment status
- Overdue receivables
- Commercial alerts

### Stock
`Home | Inventory | Scan | Receptions | Assistant`

Focus:
- Product search
- Barcode/QR scanning
- Physical/reserved/available stock
- Reorder point
- Stock movements
- Low-stock products
- Products requiring selling prices
- Reception lookup
- Stock adjustments only with permission

### Logistics
`Home | Deliveries | Receptions | Scan | Assistant`

Focus:
- Customer deliveries
- Delivery-note lookup
- Quantity verification
- Delivery status
- Supplier receptions
- Partial receptions
- Accepted/damaged/rejected quantities
- Discrepancy reasons
- Evidence photos

### Accounting
`Home | Finance | Review | Documents | Assistant`

Focus:
- Receivables
- Supplier payables
- Expense review
- Supplier invoice review
- Three-way matching status
- Payments
- Credits and returns
- E-invoice status later

### Administrator
`Home | Operations | Documents | Tasks | Assistant`

Focus:
- Company operational dashboard
- Receivables/payables
- Low stock
- Pending receptions
- Expenses requiring review
- Products requiring pricing
- Important workflow alerts
- Lightweight user/invitation management

**Never expose the server Super Admin portal, SQL console, migrations, backups or environment configuration in the normal Flutter app.**

## 4. Dashboard

Build dashboard cards dynamically from permissions.

Possible cards:
- Sales today
- Outstanding receivables
- Supplier payables
- Low-stock products
- Pending deliveries
- Pending supplier receptions
- Overdue invoices
- Expenses requiring attention
- Products requiring pricing
- Important workflow failures

PHP supplies authoritative totals.

## 5. Global Search

Search permitted entities from one place:

- Clients
- Suppliers
- Products
- Devis
- Sales orders
- Delivery notes
- Invoices
- Supplier POs
- Supplier receptions
- Supplier invoices

Search results must respect tenant and permissions.

## 6. Commercial Workflow

Implement:

1. Client list/search
2. Client details
3. Add/edit client where permitted
4. Product availability
5. Devis list/detail
6. Sales-order list/detail
7. Delivery progress
8. Invoice/payment status
9. Overdue receivables
10. Commercial quick actions

Do not expose supplier costs or internal accounting unless explicitly permitted.

## 7. Stock Workflow

Implement:

1. Product search
2. Product detail
3. Barcode scanner
4. Physical stock
5. Reserved stock
6. Available stock
7. Reorder point
8. Recent movements
9. Low-stock list
10. Products requiring pricing
11. Reception lookup

Example:

```text
PRD-00184
CAT6 Network Cable

Physical:      28
Reserved:       9
Available:     19
Reorder point: 25

⚠ Reorder recommended
```

All mutations go through existing PHP endpoints.

## 8. Logistics — Customer Delivery

```text
Sales Order
   ↓
Prepare Delivery
   ↓
Verify Quantities
   ↓
Delivery Note
   ↓
Deliver
   ↓
Confirmation
```

V1:
- Pending deliveries
- Delivery details
- Quantity verification
- Customer contact/address
- Status updates
- Comments

Later:
- Proof photo
- Customer signature
- Driver assignment
- Maps/navigation

## 9. Logistics — Supplier Reception

```text
Supplier PO
   ↓
Reception
   ↓
Received quantities
   ↓
Accepted / Damaged / Rejected
   ↓
Evidence
   ↓
Confirm
   ↓
Existing backend performs atomic stock posting
```

Flutter must call the existing atomic confirmation endpoint. Never reproduce reception stock-posting logic in Dart.

Support:
- Partial receptions
- Multiple receptions
- Discrepancy reasons
- Evidence photos
- Overdelivery/no-order behavior already supported by backend
- Remaining quantities

## 10. Supplier Mobile Profile

Keep the Supplier screen simple:

- Identity
- Contact information
- Fiscal ID
- Status
- Payment terms
- Outstanding balance
- Open POs
- Pending receptions
- Unpaid invoices
- Recent activity

Navigation:

```text
Supplier
 ├─ Purchase Orders
 ├─ Receptions
 ├─ Supplier Invoices
 └─ Payments
```

Do not duplicate purchasing/accounting logic inside Supplier CRUD.

## 11. Document Center

Support viewing/searching according to permissions:

- Devis
- Sales orders
- Delivery notes
- Invoices
- Credit notes
- Supplier POs
- Supplier receptions
- Supplier invoices
- Expenses

Mobile priorities:
- Search/filter
- View
- Status
- PDF preview
- Related-document navigation
- Download/share if permitted
- Small number of safe workflow actions

Leave complex document editing on Angular initially.

## 12. Scan & Capture

Create a central mobile action:

```text
+ Capture

Take Photo
Scan Barcode
Upload PDF
Scan Business Document
```

This becomes the entry point for stock scanning and the future extractor.

## 13. Extractor

Target flow:

```text
Photo/PDF
   ↓
Upload
   ↓
Classification
   ↓
Field Extraction
   ↓
Confidence
   ↓
Human Review
   ↓
ERP Matching
   ↓
Controlled Draft
```

Start with useful purchasing documents:
- Supplier invoice
- Supplier delivery document
- Purchase order
- Expense receipt

Show extracted supplier, document number, date, lines, taxes and total.

Attempt matching to:
- Existing supplier
- Purchase order
- Reception

Never automatically validate a financial document merely because confidence is high.

## 14. AI Assistant

Start read-only.

Commercial examples:
- "Which clients need follow-up?"
- "Show overdue invoices."
- "Do we have 20 units of Product X?"

Stock:
- "What is below reorder point?"
- "Show today's stock movements."

Logistics:
- "What deliveries are pending?"
- "Which receptions have discrepancies?"

Accounting:
- "Which supplier invoices need attention?"
- "Show overdue receivables."

Administrator:
- "What needs attention today?"

Architecture:

```text
Flutter
  ↓
PHP Assistant Gateway
  ↓
Tenant
  ↓
Permission Check
  ↓
Approved ERP Tool
  ↓
Result
```

Never trust the LLM itself to enforce authorization.

## 15. Notifications

Role-specific notifications:

**Commercial**
- Quotation follow-up
- Order confirmed
- Delivery completed
- Invoice overdue

**Stock**
- Low stock
- Reorder point reached
- Product requires pricing
- Reception pending

**Logistics**
- Delivery assigned
- Reception expected
- Reception discrepancy

**Accounting**
- Expense review
- Supplier invoice discrepancy
- Customer payment overdue
- Supplier payable due

**Administrator**
- Approval required
- Critical workflow failure
- E-invoice problem

Avoid sensitive lock-screen content.

## 16. Reorder Point

V1:

```text
Available <= Reorder Point
       ↓
Low-stock warning
       ↓
Open product/purchasing
```

Later:

```text
Low Stock
  ↓
Select Products
  ↓
Suggested Quantities
  ↓
Supplier
  ↓
Draft Supplier PO
  ↓
Human Review
```

Never automatically send a purchase order.

## 17. Suggested Flutter Structure

```text
lib/
├── app/
│   ├── router/
│   ├── theme/
│   └── config/
├── core/
│   ├── api/
│   ├── auth/
│   ├── permissions/
│   ├── tenant/
│   ├── storage/
│   ├── errors/
│   └── widgets/
├── features/
│   ├── dashboard/
│   ├── clients/
│   ├── suppliers/
│   ├── products/
│   ├── inventory/
│   ├── sales/
│   ├── deliveries/
│   ├── supplier_orders/
│   ├── receptions/
│   ├── supplier_accounting/
│   ├── documents/
│   ├── capture/
│   ├── extractor/
│   ├── notifications/
│   └── assistant/
└── main.dart
```

## 18. Phase 0 — Audit Existing APIs

Before coding Flutter screens, inventory the PHP API:

| Feature | Endpoint | Permission | Ready? | Changes |
|---|---|---|---|---|
| Login | TBD after audit | Public | ? | ? |
| Current user | TBD | Auth | ? | ? |
| Company context | TBD | Auth | ? | ? |
| Products | TBD | Product view | ? | ? |
| Clients | TBD | Client view | ? | ? |
| Deliveries | TBD | Delivery view | ? | ? |
| Receptions | TBD | Purchasing view | ? | ? |

Verify:
- authentication
- refresh behavior
- company context
- JSON contracts
- permissions
- pagination
- errors
- uploads
- PDF endpoints

Do not invent duplicate endpoints before auditing what already exists.

## 19. Phase 1 — Foundation

Build:
- Flutter project
- Environment configuration
- API client
- Authentication
- Secure token storage
- Refresh handling
- Active tenant/company
- Current user
- Permission service
- Role-aware router
- Error/loading states
- Localization foundation
- RTL foundation

## 20. Phase 2 — Dashboard + Search

Build:
- Role-specific home
- Dashboard cards
- Quick actions
- Global search
- Attention/tasks section
- Notification preview

## 21. Phase 3 — Commercial

Build:
- Clients
- Product availability
- Devis lookup
- Sales orders
- Delivery progress
- Invoice status
- Receivables

## 22. Phase 4 — Stock

Build:
- Product lookup
- Inventory
- Barcode scanner
- Stock movements
- Low stock
- Reorder warnings
- Products requiring pricing

## 23. Phase 5 — Logistics

Build:
- Customer deliveries
- Supplier receptions
- Partial reception
- Accepted/damaged/rejected quantities
- Discrepancy reasons
- Evidence upload
- Atomic confirmation integration

## 24. Phase 6 — Documents

Build:
- Unified document search
- Filters
- Details
- Status
- Related documents
- PDF preview

## 25. Phase 7 — Capture + Extractor

Implemented in Flutter:
- Central Capture destination with camera, product barcode lookup, and multi-file PDF/image picker
- Authenticated multipart upload to the existing extractor endpoint
- Client-side enforcement of the backend's file-count, type, per-file-size, and batch-size limits
- Upload progress and long-running extraction timeout handling
- Typed extraction results for document fields, lines, confidence, warnings, and batch failures
- Human-review screen with editable extracted values and explicit review confirmation
- Document classification for supplier invoice, supplier delivery, purchase order, and expense receipt
- Controlled handoff to the existing expense form; nothing is saved automatically and the expense starts as `PENDING`

Still backend-dependent:
- Authoritative supplier, purchase-order, reception, product, and tax-profile matching
- Controlled supplier-invoice, supplier-reception, and supplier-order draft creation after matching

Until those backend services exist, purchasing destinations remain review-only and direct users to the Angular workspace. Flutter must not invent or persist financial foreign keys from OCR text.

## 26. Phase 8 — AI Assistant

Build:
- Chat UI
- Streaming if available
- Permission-aware tools
- Role-specific suggestions
- Deep links into Flutter screens

Example:

```text
"Show low stock"
   ↓
Assistant result
   ↓
Open Inventory filtered to LOW STOCK
```

## 27. Phase 9 — Accounting Review

Build:
- Receivables
- Payables
- Expenses
- Supplier invoice review
- Matching status
- Payments
- Credits/returns

Keep advanced accounting configuration on web.

## 28. Phase 10 — Notifications + Polish

Complete:
- Notification center
- Deep links
- French
- English
- Arabic
- RTL
- Accessibility
- Loading/empty/error/retry states
- Phone/tablet layouts
- Performance checks

## 29. Testing Matrix

Test with:
- Administrator
- Commercial
- Stock
- Accounting
- Logistics if represented separately

For each:
- Correct navigation
- Allowed actions
- Forbidden actions
- Direct API attempts
- Cross-tenant IDs
- Expired login
- Revoked session

## 30. Critical End-to-End Tests

### Commercial
```text
Login → Client → Product Availability → Devis → Order → Delivery → Invoice Status
```

### Stock
```text
Login → Scan Product → Inventory → Low Stock → Movements
```

### Logistics / Supplier
```text
Login
→ Supplier PO
→ Partial Reception
→ Accepted/Damaged
→ Confirm
→ Verify Stock
→ Final Reception
→ Verify PO Progress
```

### Customer Delivery
```text
Login → Pending Order → Delivery → Verify Quantities → Complete → Verify Status
```

### Tenant Isolation
```text
Company A User → Attempt Company B Record → Backend Rejects
```

## 31. Keep These on Angular/Web

Do not prioritize for Flutter V1:
- SQL console
- Database migrations
- Backups
- Server configuration
- Super Admin
- Full accounting configuration
- Accounting-period controls
- Large report builders
- Template designers
- Complex role configuration
- Infrastructure administration

## 32. Recommended V1

**Foundation**
- Authentication
- Tenant
- Permissions
- Role navigation

**Commercial**
- Clients
- Product availability
- Devis/order/invoice lookup

**Stock**
- Product lookup
- Barcode scan
- Inventory
- Low stock
- Movements

**Logistics**
- Deliveries
- Supplier receptions
- Discrepancies
- Evidence photos

**Shared**
- Dashboard
- Search
- Documents
- Notifications
- Capture

**V1+**
- Extractor
- Read-only AI

## 33. Exact Development Order

```text
1. Audit PHP APIs
2. Authentication
3. Tenant/company context
4. Permissions
5. Role-aware navigation
6. Dashboard
7. Global search
8. Commercial
9. Stock
10. Barcode scanning
11. Customer logistics
12. Supplier receptions
13. Documents
14. Notifications
15. Capture
16. Extractor
17. AI assistant
18. Accounting review
19. RTL/localization
20. Security and workflow regression tests
```

Do not start with AI/extraction before authentication, tenant isolation, permissions and core operational workflows are reliable.

### Current repository checkpoint — 2026-09-06

All 20 implementation areas above are represented in the Flutter and PHP source, including role-aware navigation, barcode lookup, logistics, supplier receptions, unified documents, notifications, the read-only assistant, accounting review, FR/EN/AR localization, RTL-safe layouts, and regression coverage.

The Capture + Extractor mobile flow now supports photo capture, PDF/image selection, authenticated batch upload, progress, typed extracted data, confidence/warnings, editable human review, and safe pending-expense prefill. Supplier/PO/reception matching and purchasing-draft creation remain explicitly incomplete because they require authoritative tenant-scoped backend resolvers.

Release validation still requires the deployment environment:

- Deploy the updated PHP endpoints and permission guard.
- Install/configure the extractor Python runtime on the deployed server and verify `backend/extractor/run_extraction.php` can invoke it.
- Apply `backend/sql/2026-09-05-notification-read-state.sql` once to the production database.
- Run the database-backed tenant-isolation and HTTP role-authorization suites against a test database and deployed API.
- Smoke-test camera permission, document upload/extraction, file selection, and barcode scanning on physical Android/iOS devices.

## 34. Definition of Done

The mobile companion is usable when:

- Authentication uses the real backend.
- Active company context is correct.
- PHP enforces permissions.
- Commercial has useful mobile sales access.
- Stock can scan and inspect inventory.
- Logistics can handle deliveries/receptions.
- Reception confirmation preserves atomic stock behavior.
- Accounting can review key finance information.
- Documents are searchable/viewable.
- Cross-tenant access is rejected.
- Unauthorized API actions are rejected.
- French/English/Arabic and RTL are usable.
- Critical workflows are tested.
- Flutter does not duplicate authoritative ERP business logic.

## 35. Product Positioning

```text
EL FATOURA WEB
Complete ERP workspace
──────────────────────
Administration
Full document creation
Accounting
Reports
Configuration
Advanced workflows

EL FATOURA MOBILE
Operational companion
──────────────────────
Commercial field access
Stock scanning
Warehouse operations
Deliveries
Supplier receptions
Capture/extraction
Notifications
AI assistance
Quick review/actions
```

**Goal:** El Fatoura in your pocket for the work that makes sense on a phone.

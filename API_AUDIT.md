# El Fatoura Flutter API Audit

Audit date: 2026-09-03  
Deployment: `https://facture.myenv.digital/backend`

## Method

The configured Flutter endpoints were probed with the application's static API
credential and without user credentials, access cookies, entity identifiers, or
mutation payloads. An endpoint is marked present when it returned a structured
JSON authentication, validation, or method error instead of a web-server 404.

This confirms routing and basic error contracts. It does not prove permission
enforcement, tenant isolation, or successful business operations; those require
authenticated role-specific test accounts and known test records.

## Summary

- 38 of 39 configured endpoint paths are present and return JSON.
- Protected GET endpoints consistently return HTTP 401 with `success: false`, a
  message, and a request ID when the access token is absent.
- Mutation endpoints consistently reject GET and advertise POST (or POST/DELETE
  for client deletion).
- `ai/assistant.php` returns HTTP 404 and is not production-ready.
- Login uses `ef_access` and `ef_refresh` cookies rather than returning tokens in
  the JSON body. Flutter now supports this contract.

## Endpoint Matrix

| Area | Endpoint(s) | Expected method | Audit status | Still required |
|---|---|---:|---|---|
| Authentication | `auth/login.php` | POST | Ready; successful contract observed | Expiry/revocation tests |
| Authentication | `auth/me.php` | GET | Present; protected | Verify full session/permission contract |
| Authentication | `auth/refresh.php` | POST | Present | Refresh rotation and reuse tests |
| Authentication | `auth/signup.php` | POST | Present from active app flow | Validation/tenant tests |
| Authentication | verification, password reset, 2FA endpoints | POST/GET | Present; JSON errors | Successful workflow tests |
| Clients | list, archived list, add, update, delete | GET/POST | All present | CRUD permission and cross-tenant tests |
| Products | list, add, update, delete | GET/POST | All present | Availability/stock fields and permissions |
| Invoices | list, detail, add, update, status, totals, delete | GET/POST | All present | Locking, idempotency, tenant tests |
| Invoice items | list, add, update, delete | GET/POST | All present | Invoice ownership and locking tests |
| Profile | `user/update_profile.php` | POST | Present | Company-vs-user authorization contract |
| Mail | `mailer/send_invoice_pdf.php` | POST | Present | Attachment limits and permission tests |
| Expenses | list, add, update, status, delete | GET/POST | All present | Accounting permissions and tenant tests |
| Assistant | `ai/assistant.php` | POST | **Missing (404)** | Implement permission-aware PHP gateway |

## Roadmap APIs Not Yet Configured in Flutter

The current app has no configured endpoints for:

- Server-authoritative dashboard totals and attention cards
- Global search
- Suppliers
- Quotations and sales orders
- Customer deliveries and delivery confirmation
- Inventory availability, reservations, movements, and low stock
- Supplier purchase orders and receptions
- Unified document search and related-document navigation
- Notifications
- Extractor uploads, classification, review, and controlled drafts
- Receivables, payables, payments, credits, and returns

These endpoints must be matched to existing PHP services before corresponding
Flutter screens are built. Do not infer paths or reproduce ERP calculations in
Dart.

## Required Authenticated Audit Matrix

For Administrator, Commercial, Stock, Logistics, and Accounting test users:

1. Call `auth/me.php` and record role, membership, company, tenant, and exact
   permission identifiers.
2. Verify each allowed list endpoint succeeds.
3. Verify each forbidden endpoint returns 403, including direct API calls.
4. Attempt a known record ID from another tenant and require rejection.
5. Test expired access-cookie refresh and refresh-cookie rotation.
6. Revoke the session and confirm both API rejection and Flutter logout.
7. Record pagination, filters, stable error codes, and request IDs.

## Client Actions Taken

- Production backend is the default, with `API_BASE_URL` available as an
  environment override.
- Cookie authentication supports `ef_access` and `ef_refresh`.
- Typed user/tenant/company/membership/permission context is persisted.
- Mobile navigation is filtered using membership, role, and permissions.
- Assistant navigation is disabled by default because its endpoint is absent.
  It can be enabled only for a deployment that supplies the gateway:

  ```sh
  flutter run --dart-define=ASSISTANT_ENABLED=true
  ```

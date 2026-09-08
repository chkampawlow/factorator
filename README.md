# El Fatoura Mobile

Flutter companion for the El Fatoura Angular + PHP + MariaDB commercial-management platform.

The mobile app focuses on operational work that makes sense on a phone. Angular remains the complete office workspace and the PHP API remains authoritative for permissions, tenancy, stock, accounting, document status, audit, and idempotency.

## Current scope

- Backend authentication, persisted access/refresh tokens, session refresh, active company membership, 2FA, email verification, and password reset
- Permission-aware navigation and mutation controls
- Dashboard, notifications, and global search
- Clients, products, invoices, sales orders, deliveries, expenses, and document center
- Supplier receptions with partial quantities, discrepancies, evidence upload, and backend stock confirmation
- Accounting review, capture/extractor review, barcode scanning, PDF sharing, and XML preview
- French, English, and Arabic resources, plus light/dark themes

The assistant exists behind the `ASSISTANT_ENABLED` build flag and is disabled by default.

## Architecture

```text
Flutter mobile UI
        ↓
Existing PHP JSON API
        ↓
Authentication + active company membership
        ↓
Backend permissions and business services
        ↓
MariaDB / MySQL
```

Flutter permission checks improve navigation and hide unsafe actions, but they are not a security boundary. Every protected operation must still be authorized and tenant-scoped by PHP.

## Roles

The deployed backend supports four assignable roles: `ADMINISTRATOR`, `COMMERCIAL`, `STOCK`, and `ACCOUNTING`.

Flutter recognizes `LOGISTICS` as a forward-compatible navigation profile. It is not currently an assignable backend role; logistics capabilities come from backend permissions until that contract is deliberately extended.

## Project structure

```text
lib/core/       API, session, permissions, shared models
lib/screens/    Mobile screens and workflows
lib/services/   Authentication and domain integrations
lib/storage/    API/local repositories
lib/l10n/       FR/EN/AR resources
lib/themes/     Light/dark visual system
lib/widgets/    Shared UI components
test/           Unit and model tests
```

## Configuration

Production API base: `https://facture.myenv.digital/backend`.

```bash
flutter run --dart-define=API_BASE_URL=http://127.0.0.1/backend
flutter run --dart-define=ASSISTANT_ENABLED=true
```

Authenticated requests use the access token/cookie issued by the backend in addition to the configured API gateway credential. Never document or commit production secrets in plain text.

## Setup and validation

```bash
flutter pub get
dart analyze
flutter test
flutter run
```

Repository verification on 2026-09-07:

- 34 screen files and 88 Dart files
- Nine test files; all 43 executed tests passed
- Static analysis completes with no errors, with 105 advisory items remaining (mainly deprecated color APIs and async `BuildContext` usage)

## Build

```bash
flutter build apk --release
```

Before release, validate real API connectivity, FR/EN/AR and RTL behavior, denied permissions, revoked sessions, cross-company identifiers, capture permissions, and critical workflows on a physical device.

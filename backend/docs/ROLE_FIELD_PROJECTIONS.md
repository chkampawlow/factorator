# Role-safe response field projections

Authorization decides whether a role may call an endpoint. Field projection separately limits which columns an authorized endpoint returns. `config/field_projection.php` is the shared response contract for dashboard, notification, client selector, catalog and document reads.

| Data group | Administrator | Commercial | Stock | Accounting |
|---|---|---|---|---|
| Client delivery contact | Yes | Yes | Yes | Yes through authorized finance documents |
| Client fiscal ID, CIN and payment terms | Yes | Yes | No | Yes |
| Product selling data and available quantity | Yes | Yes | Yes | Yes when the endpoint permission allows it |
| Purchase price, average cost, reorder policy and stock value | Yes | No | Yes | Yes |
| Invoice totals and customer identity | Yes | Yes | No direct invoice access | Yes |
| Payment method and withholding header fields | Yes | No | No | Yes |
| Tenant IDs, idempotency keys and internal persistence fields | No response exposure | No response exposure | No response exposure | No response exposure |

Dashboard and notification responses are also projected by role. A STOCK response does not contain sales/accounting sections, and ACCOUNTING notification counts do not reveal catalog or client totals.

Run `php backend/bin/verify_role_field_projections.php` after changing a protected read endpoint or adding a sensitive response field. HTTP fixture coverage must additionally confirm these projections with all four roles and direct URL requests.

# Backend permission matrix

This matrix is the authorization contract for HTTP endpoints. Authentication and
tenant scoping remain mandatory in addition to the listed permission.

| Endpoint group | Read permission | Write permission |
|---|---|---|
| Clients | `clients.view` | `clients.create`, `clients.edit`, or `clients.delete` |
| Suppliers | `suppliers.view` | `suppliers.create`, `suppliers.edit`, or `suppliers.delete` |
| Products/services | `products.view`, `services.view`, or the applicable document-workflow read permission for selectors | `products.create`, `products.edit`, `products.delete`, `services.create`, `services.edit`, or `services.delete` |
| Stock ledger and adjustments | `stock.view` or `reports.view` | `stock.adjust` |
| Quotes | `devis.view` | `devis.create`, `devis.edit`, `devis.delete`, `devis.send`, or `devis.validate` |
| Sales orders | `orders.view` | `orders.create`, `orders.edit`, `orders.delete`, `orders.confirm`, `orders.cancel`, or `orders.send` |
| Deliveries | `deliveries.view` | `deliveries.create`, `deliveries.edit`, `deliveries.delete`, `deliveries.confirm`, `deliveries.cancel`, `deliveries.deliver`, or `deliveries.send` |
| Invoices | `invoices.view` | `invoices.create`, `invoices.edit`, `invoices.delete`, `invoices.validate`, or `invoices.send` |
| Credit notes | `avoirs.view` | `invoices.credit` plus the applicable `avoirs.create`; then `avoirs.edit`, `avoirs.delete`, `avoirs.validate`, or `avoirs.send` |
| Supplier purchase orders | `supplierOrders.view` | `supplierOrders.create`, `supplierOrders.edit`, `supplierOrders.delete`, or `supplierOrders.send` |
| Supplier receptions | `supplierReceptions.view` | `supplierReceptions.create`, `supplierReceptions.edit`, `supplierReceptions.delete`, or `supplierReceptions.confirm` |
| Supplier invoices and credits | `supplierInvoices.view` | `supplierInvoices.create`, `supplierInvoices.validate`, or `supplierInvoices.credit` |
| Supplier payments and returns | `supplierInvoices.view` within the linked supplier accounting file | `supplierPayments.record` or `supplierReturns.confirm` |
| Expense notes | `expenses.view` | `expenses.create`, `expenses.edit`, `expenses.delete`, or `expenses.approve` |
| Payments | `payments.view`; invoice viewers receive aggregate settlement status only | `payments.record` or `payments.void` |
| Withholding | `withholding.view`; invoice viewers receive aggregate settlement status only | `withholding.record` or `withholding.edit` |
| Tax profiles | applicable product/service/invoice/report view permission | `products.edit`, `services.edit`, or `reports.view` |
| Reports and exports | `reports.view` | `reports.view` |
| AI/extractor | `assistant.use` / `extractor.use` | same |
| Users and tenant administration | `users.manage` | `users.manage` |

Rules:

1. Never infer authorization from a frontend route guard.
2. Every resource query must include the authenticated tenant's `user_id`.
3. Foreign IDs must be resolved through tenant-scoped lookup helpers.
4. A resource from another tenant must return the same 404/403 class as a missing resource.
5. Validated, locked, filed, and immutable records retain their workflow restrictions after authorization succeeds.
6. The remaining broad finance permissions (`invoices.manage`, `devis.manage`, `avoirs.manage`, `payments.manage`, and `withholding.manage`) are temporary compatibility grants for unconverted endpoints. Converted finance, purchasing, catalog, stock, sales-order, and delivery endpoints must not use broad legacy permissions.
7. Invoice and credit-note emails require an owned, issued document ID. Quotation email also requires a non-draft workflow status.
8. Authorization is followed by role-safe response projection: client fiscal identity, inventory cost/valuation, settlement fields and internal persistence identifiers are returned only to roles that require them. See `ROLE_FIELD_PROJECTIONS.md`.
8. Purchase-order email requires `supplierOrders.send`. Reception confirmation requires `supplierReceptions.confirm` and atomically posts stock, updates its purchase order, stores confirmation metadata, and writes an audit event. Optional linked-expense creation additionally requires `expenses.create`.
9. Sales-order and delivery-note emails require `orders.send` and `deliveries.send`. Delivery stock posting requires `deliveries.deliver`.

# Dashboard Upgrade 64 — Payment Allocation Plan Foundation (DRAFT)

Added a private, RLS-protected schema for prospective transfer allocation
plans and their line items, retaining original unit prices and quantities.
No user role has direct access to write these records; no plan creation or
execution RPC is exposed.

New read-only `gs_bill_transfer_allocation_readiness(request_id)`:
- Aggregates selected item quantities and original line prices.
- Counts cash, external evidence, and owner-offer records on affected orders.
- Returns a specific review reason, never an authorization to execute.
- `execution_permitted` is deliberately always FALSE.

This lays groundwork for separating a transferred unpaid balance from
historical payments. It does NOT allocate a payment, move an order, merge
customers, release a table, or prove absence of unrecorded payment.
Future work requires authoritative payment-provider and credit reconciliation,
transaction-level locks, a real allocation engine, and test coverage.

WARNING: No Flutter compile, SQL deployment or live integration tests.

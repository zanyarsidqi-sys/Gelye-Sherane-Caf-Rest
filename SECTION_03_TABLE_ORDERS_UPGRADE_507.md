# Upgrade 507 — Permission-scoped manual kitchen handoff

- Added a copyable, filtered staff handoff summary of actionable table-order items.
- Includes table, order/item IDs, product, quantity, status and Iraq-local snapshot time.
- Excludes delivered items, malformed IDs, and customer personal information.
- Disabled when board is unavailable/loading or fulfillment mutations are in flight.
- Clearly labels the clipboard output as a manual snapshot, **not** a dispatched ticket.
- No database migration or order mutation introduced.

Verification: archive integrity only; Flutter compile and Supabase integration not run.

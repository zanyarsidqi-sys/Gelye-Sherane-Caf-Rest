# Upgrade 1231 — Routed print snapshots and branding foundation

Implemented:
- `gs_route_confirmed_order` now freezes immutable station item payloads inside the routing transaction, including optional `guest_label` and preparation notes. It does not change order prices or invoices.
- Device claim excludes tickets without immutable payloads, preventing missing-content printing.
- Added append-only revision event schema for future correction/replacement/cancellation ticket generation; **the event ledger is not yet wired to a secure correction workflow or printer queue**.
- Added reusable Flutter footer widget and shared bill branding constant. **Not yet inserted into all 35 screens or all invoice/PDF/POS renderers**.
- All project files preserved.

Remaining issues:
- Previously queued tickets without snapshots remain unprintable until reconciled by an authorized workflow.
- Ticket uniqueness `(order_id,station_key)` prevents multiple correction print tickets; dedicated revision dispatch needs new queue logic.
- Print RPC access and station session schemas require real database verification. Hardware printing is not connected.
- Flutter build, Supabase migration execution, physical printer testing deferred.

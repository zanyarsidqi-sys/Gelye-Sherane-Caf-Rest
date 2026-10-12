# Tables Upgrade 155 — Guest move request UI

Adds a request-only guest movement dialog to the Flutter Tables section.
Authorized staff choose a destination with an active visit, guest count,
optional bill-review flag and reason. The UI calls the existing
`gs_request_table_guest_move` RPC with a fresh UUID idempotency key.

**No guests, visits, orders, payments or balances are moved.** Execution
requires a separate audited, atomic workflow, including payment allocation.
The server RPC rechecks capacity and permission under locks. This UI and
migration have not been compiled or tested against live Supabase.

Tables section progress: **26% estimated** (not verified).

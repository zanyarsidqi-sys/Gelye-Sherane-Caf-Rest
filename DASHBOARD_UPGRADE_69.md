# Dashboard Upgrade 69 — Join Tables / Move Guests (draft)

Adds `gs_table_guest_move_requests` and authorized, idempotent
`gs_request_table_guest_move` RPC. Validates two active occupied visits,
checks source guest count and destination capacity, serializes request
creation and rejects conflicting pending move requests. `move_bill` only
records intent; it does not move charges or merge customers.

No actual guest movement, table occupancy updates, reservation hold
integration, payment allocation or bill transfer is performed. Legacy
`gs_transfer_cafe_table` and historical orders require further review.
The move execution must atomically recheck guest counts, reservations,
cleaning state, settlement and capacity and write a full audit trail.

**Not production-ready:** schema compatibility, Flutter compilation,
Supabase migration and live concurrency tests are outstanding.

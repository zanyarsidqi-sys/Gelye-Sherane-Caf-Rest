# Dashboard Upgrade 51 — Atomic visit-bound cart orders (DRAFT)

Added migration 052 that updates `gs_create_cart_order` in place:
- For cafe table orders, locks the occupied table and finds its active visit.
- Stores `table_visit_id` atomically when inserting the order.
- Rejects new cafe orders if no active visit exists (fail closed).
- Motel orders still use tourism prices and have NULL table_visit_id.
- Preserves product validation and server-side price selection.
- Revokes access to legacy single-item `gs_create_order_for_destination` until
  its visit linkage is implemented.

IMPORTANT: This is NOT ready to deploy. There is no production-safe visit
opening RPC yet; deploying would block table orders. Other legacy order
creation functions also need review. Historical orders are not backfilled.
No Flutter compilation, SQL deployment or integration testing performed.

# Upgrade 535 — Transactional product replacement foundation

Added `gs_replace_unaccepted_table_item` RPC to replace a product in an unaccepted, open table order. It derives the new unit price from the active menu product and the order's Normal/Tourism mode, preserving quantity. It rejects stale product/price expectations, kitchen acceptance or tickets, invoice snapshots and payment evidence. Under a parent-order row lock, it updates the item, writes a revision with before/after totals and queues employee/customer notifications atomically. Requires a 5–250 character employee reason and `table_orders.can_edit`.

**Deployment:** Apply migration 535 after migrations 1–534. No Flutter UI wired in this upgrade; this is a server-side capability for a subsequent product-picker workflow. Existing price adjustment revision type is reused because the schema limits allowed types; before/after snapshots identify the product replacement.

**Not verified:** Live Supabase deployment, Flutter compilation, integration testing. Do not use for paid or kitchen-accepted items; these require supervised reconciliation. Existing staff menu selection, station routing and discount pricing must be reviewed before enabling the UI.

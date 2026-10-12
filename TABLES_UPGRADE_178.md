# Tables Upgrade 178 — Per-table Item Status and Cash-only Money Preview

Added a table-card receipt icon that opens a read-only breakdown of:
- Not accepted, accepted, preparing, prepared, picked up and delivered item quantities
- Individual items, quantity, order ID and recorded fulfillment state
- Total billed, verified legacy cash paid and **cash-only** outstanding

A new permission-checked Supabase RPC joins orders to the active visit,
so historical/other-table orders are not mixed in. A new locked-down
fulfillment-state table provides item-level status storage; no status
transition RPC is enabled yet. Missing fulfillment records are displayed
as **not accepted**, not falsely reported as delivered.

**Critical limitation:** Cash-only outstanding is NOT the actual total
outstanding where credit, mixed payments or unified-ledger payments exist.
The UI explicitly warns this is not a final settlement balance.
No payment posting or fulfillment mutation added.

No live migration or Flutter compilation was performed. ZIP verified.
Tables development 60% estimated, 7/20 earlier milestones unchanged.

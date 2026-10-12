# Upgrade 158 — Tables: read-only join/transfer financial preview

The Tables Flutter screen now offers **Review joining tables / unpaid bill transfer**.
Staff select two active visits and view individual source order items with their
original unit prices, quantities, line values and server-calculated restriction
reasons from `gs_preview_table_bill_transfer`.

No orders, guest counts, balances, payments or reservations are changed. The
existing `gs_apply_table_bill_transfer` function remains disabled because
authoritative payment allocation and atomic transfer are not implemented.

The existing preview function's `transfer_eligible` result is a **preliminary
cash-only review**, not permission to execute a transfer; the interface intentionally
does not offer an Apply action.

Tables completion estimate: 35% (7/20 major milestones fully complete,
13 remaining; this upgrade is partial progress toward joining/transfers).
Flutter compilation and live Supabase RPC tests have not been performed.

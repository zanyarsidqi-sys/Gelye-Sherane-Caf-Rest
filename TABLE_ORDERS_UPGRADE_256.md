# Upgrade 256 — Staff Table Order Board

- Adds Order Board tab alongside Table Orders, Takeaway & Delivery and Employee Jobs.
- Uses staff-authorized `gs_staff_table_order_board()` for live visit item statuses.
- Status mapping: Pending=not_accepted, New=accepted, Preparing=preparing, Prepared=prepared, Delivery=picked_up, Delivered=delivered.
- Actions use existing guarded `gs_advance_table_item_fulfillment` RPC, with expected-status concurrency check.
- Read-only query is limited to 500 items on open table visits. Refresh manually; no realtime subscription yet.
- No customer permissions are granted by this migration.
- Partial quantity delivery, station tickets, customer QR session and final settlement are separate workflows.
- Source/ZIP verified; Flutter compilation and Supabase deployment not performed.

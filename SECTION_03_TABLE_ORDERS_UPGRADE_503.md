# Upgrade 503 — Table Orders: searchable authorized fulfillment board

- Added an on-device, case-insensitive search field to the employee fulfillment board.
- Matches table number, product, order ID, item ID and status; supports multiword search.
- Combines search with existing stage filters and displays visible/authorized totals.
- Added a clear-search control, accessible search labels and distinct empty/search/no-access states.
- Search runs exclusively on records returned by the existing permission-scoped `gs_staff_table_order_board` RPC. No database schema changes or new access paths.
- Search controller is disposed with the widget.

Verification: source patch assertions and ZIP CRC/integrity validation. Flutter compilation and live Supabase tests have not been run.

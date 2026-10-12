# Upgrade 508 — Authorized table-specific order queue

- Added a table selector to the staff fulfillment board, populated only from the existing permission-scoped `gs_staff_table_order_board` response.
- Table selection combines with stage filters, free-text search, queue sorting, counts, and manual kitchen handoff.
- Table numbers are sorted numerically when possible; no extra unrestricted database calls are introduced.
- Clear filters resets table, stage, and search simultaneously.
- Stale selected tables fall back to All on display when no longer returned by the authorized RPC.
- No new order-editing endpoint or kitchen dispatch is claimed.

## Verification
ZIP integrity verified. Flutter compilation and live Supabase verification not performed in this environment.

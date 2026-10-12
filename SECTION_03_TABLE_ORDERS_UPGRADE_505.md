# Upgrade 505 — Table Orders queue prioritization

- Added employee-selectable queue ordering: oldest first, newest first, and numeric table number.
- Sorting occurs only after the existing permission-scoped RPC results and active stage/search filters.
- Invalid timestamps are sorted after valid ones, with stable item-ID tie-breaking.
- No changes to order status, authorization, database schema, or prior functionality.
- Flutter compilation and live Supabase testing are still required.

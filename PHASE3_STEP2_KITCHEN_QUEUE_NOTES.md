# Phase 3 — Kitchen queue usability update

- Adds oldest-first / newest-first ordering based on order creation time.
- Adds counts for new, preparing, and ready orders and visible queue size.
- Keeps all status transitions routed through the existing authorized Supabase RPC.
- No new database migration required for this update.

## Remaining before Step 2 is complete
- Validate actual database schemas, roles and permissions.
- Confirm table/motel orders reach the kitchen and complete without duplicate transitions.
- Run Flutter analyzer and widget/integration tests on supported devices.
- Verify occupancy and tourism pricing end-to-end.

Progress: previous 60% is an unverified overall estimate; no new numerical claim.

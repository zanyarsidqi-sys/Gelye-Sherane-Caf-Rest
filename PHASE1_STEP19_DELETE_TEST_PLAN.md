# Phase 1 Step 19 — DELETE authorization and rollback test preparation

Application: Rest

## Offline verification

11 source guard checks passed. Deliberately removing the counter-order authorization guard caused the checker to fail (negative test passed). ZIP integrity checked. No SQL executed.

## Disposable database test matrix (not yet run)

1. Authenticated user lacking `table_orders.can_edit` must be denied counter draft item deletion, leaving the row intact.
2. Authorized user deleting an item from another request must be denied; no cross-request deletion.
3. Authorized user deleting from a non-pending request must be denied; no data changes.
4. Authorized user deleting from a pending request should delete only the targeted item; verify audit expectations.
5. Website editor with `cafe_can_manage_website('edit')` can reassign tables for a pending event only; no other event affected.
6. Unauthorized user must be denied event table reassignment.
7. Force an insert/constraint failure after the event-table DELETE inside a transaction; confirm original rows remain after rollback.
8. Verify audit events are written or explicitly identify missing audit coverage.
9. Verify SECURITY DEFINER function owners, search paths, EXECUTE grants, and RLS/permission helpers against the live schema.

**Do not execute these against production.** Use disposable, isolated Supabase/PostgreSQL with test accounts and known fixtures. Confirm migration ordering and unique versions first.

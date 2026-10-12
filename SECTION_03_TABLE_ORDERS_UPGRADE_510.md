# Upgrade 510 — Repair audited instruction revision workflow

## Verified source-code issue

The Table Orders editor introduced in Upgrade 509 called `gs_edit_unaccepted_order_item_instructions` directly. Migration `20261010_266_instruction_revision_dispatch.sql` revoked authenticated EXECUTE on that function to ensure every edit goes through `gs_edit_unaccepted_item_with_revision`. Consequently the UI's edit submission would be rejected in a correctly migrated Supabase environment.

## Implemented

- Replaced the direct call with the authorized revision wrapper `gs_edit_unaccepted_item_with_revision`, retaining its expected-value optimistic concurrency and server-side permission/visit/kitchen/invoice guards.
- The existing wrapper records the edit, creates a revision event, and queues employee/customer update notifications transactionally if the instruction actually changes. No physical printing is claimed.
- Avoids submitting whitespace-equivalent no-op edits and avoids misleading audit-success messages for them.
- Preserved all existing project source files and migrations; no new migration is needed.

## Not verified

Flutter compilation and live Supabase migration execution/integration testing are still required. Quantity and product editing are not enabled.

# Upgrade 551 — Safe kitchen revision reinvestigation

- Adds a permission-protected Supabase RPC to reinvestigate a previously closed kitchen revision case only if a current receipt-audit inconsistency exists.
- A new linked case is created; prior closure and its resolution note remain immutable.
- Dispatch row locking, partial unique open-case index, and fresh server-side reconciliation prevent concurrent duplicate investigations and stale UI bypass.
- Flutter investigation history shows linked prior cases and a conditional Reinvestigate action with mandatory reason.
- No mutation to order pricing, invoices, payments, kitchen acknowledgments, or dispatch status.

Deployment: apply migration 551 after 550. Run Flutter analyze/build and staging Supabase integration tests before release. These were not run in this environment.

# Dashboard Upgrade 93 — Visit settlement schema fix and physical readiness gate

**Concrete correction:** Upgrade 92 incorrectly referred to `gs_orders.table_number`,
which is not part of the project's order schema. It now uses the existing
`gs_orders.destination` text field and excludes motel orders when counting
historical/unlinked café orders for the same physical table.

**New draft RPC:** `gs_table_checkout_readiness(table_id)` inspects table
occupancy, active visit, guest departure, cleaning state, open cleaning/shisha
tasks, and pending guest-movement requests. It requires both table and
financial view permissions. It returns a blocker and **always sets
`checkout_authorized=false`**; it never changes a table or posts payments.

**Remaining risks:** historical table numbers can be reused; manual review is
still required for unlinked orders. Financial settlement remains provisional.
Existing legacy table-release and checkout functions require further audit;
this diagnostic does not replace them. No Supabase execution or Flutter
compilation was performed. Run all migrations in staging and test RLS and
concurrency before deployment.

# Upgrade 546 — Kitchen revision reconciliation

Added a permission-scoped, read-only Supabase RPC `gs_staff_kitchen_revision_reconciliation(bigint)` for Section 03. It correlates product-replacement kitchen dispatch status and receipt audit evidence, identifies missing audit, conflicting state, missing timestamp, timestamp mismatch, failed recovery, and pending receipt. It never changes financial records, dispatches, or kitchen acceptance. Access requires both table order and kitchen view permissions. Deploy after migration 545.

## Verification
SQL reviewed statically; ZIP integrity checked. No live Supabase migration, Flutter compilation, or end-to-end integration test performed. Existing schema assumption: `gs_order_revision_dispatch.status` is text-compatible and timestamps are `timestamptz`. A production database test is required before release.

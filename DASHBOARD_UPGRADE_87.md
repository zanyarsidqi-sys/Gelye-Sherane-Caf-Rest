# Dashboard Upgrade 87 — Payment provenance inspection

Added a read-only, permission-gated SQL RPC `gs_dashboard_payment_provenance(order_id)`.
It surfaces ledger entry type, amount, source reference, verification/posting
metadata, cash crosswalk count, and an explicit anomaly/status reason.

Checks include future or inconsistent verification timestamps, missing posting
actor, missing provenance fields, unmatched legacy cash links, and entries
requiring independently authenticated card/online/credit provider evidence.

**Safety invariant:** `settlement_usable` is **always false**. This is a
source-data diagnostic, not an attestation of actual payment. No client
payment posting, bill transfer, refund, or complimentary waiver was enabled.

**Verification:** ZIP structure and CRC tested. No Supabase deployment,
PostgreSQL execution, Flutter build, or payment provider testing performed.

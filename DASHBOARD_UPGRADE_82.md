# Dashboard Upgrade 82 — Financial Integrity Diagnostics

Added a read-only, permission-checked Supabase RPC `gs_dashboard_payment_integrity_audit(order_id)`.

It examines one order and reports:
- Original order total, legacy cash receipts and unified-ledger net independently (never summed together).
- Unlinked legacy cash receipts and unmatched unified-ledger cash entries.
- Incorrect crosswalks (wrong order, amount, type, direction or source).
- Unverified external payment evidence and pending/verified owner offers.
- Potential overpayments and a machine-readable list of blockers.

**The function always returns `transfer_execution_safe=false`.** A clean diagnostic is NOT proof of settlement; payment posting and item-level allocations are not yet implemented. No bill is transferred or customer charged.

## Verification needed
Apply to a disposable Supabase staging database and test zero payments, matching and mismatched crosswalks, simultaneous receipts, denied employee permissions, and historical orders. Flutter builds and real provider tests remain outstanding. This upgrade does not complete Section 01.

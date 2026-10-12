# Upgrade 568 — Cross-device committed replacement receipts

- Adds `gs_table_replacement_receipt_history(p_limit)` with a bounded (1–50) result set.
- Requires an authenticated employee with Table Orders viewing permission and filters all receipts to `auth.uid()`.
- Exposes only committed receipt metadata, not internal arguments or other employees' records.
- Adds **My replacement receipts (all devices)** in Table Orders for employees to inspect recent completed replacement request IDs and outcomes.
- Retains the local pending request recovery flow; **receipt history cannot prove that an absent request is safe to retry**.

## Verification limits
Static checks only. Run the migration on staging, test Supabase permissions with separate employee accounts, and compile/test Flutter before deployment.

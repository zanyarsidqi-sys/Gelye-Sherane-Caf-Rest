# Dashboard Upgrade 89 — Conservative payment reconciliation summary

Added a read-only RPC `gs_dashboard_payment_reconciliation_summary(order_id)`.

- Calculates the order total and legacy cash receipt total.
- Separately reports reconciled cash mirrors and unlinked legacy cash.
- Excludes valid linked ledger cash mirrors from the additional ledger net,
  preventing a linked cash receipt from being counted twice.
- Reports a **provisional** remaining balance and reconciliation exceptions.
- Requires financial view permissions.
- Explicitly returns `settlement_confirmed=false` and `transfer_allowed=false`.

**Caution:** Even the deduplicated amount is provisional, because an unlinked
legacy receipt and an unmatched ledger entry may describe the same payment.
No provider verification, refund execution, transfer, or owner waiver is
implemented. Never use this RPC to release tables, settle orders or transfer
bills. Stage and test the migration before any deployment.

**Validation:** ZIP integrity only; no Flutter compile or Supabase execution.

# Dashboard Upgrade 86 — Reversal exposure diagnostic

Added a read-only, permission-gated Supabase RPC
`gs_dashboard_reversal_exposure(order_id)` to report, per original
credit ledger entry:

- Original payment amount and count/total of linked refund/reversal rows.
- Remaining amount after recorded reversals (clamped at zero).
- Anomaly labels for over-reversal and other ledger conditions.
- Explicit `refund_execution_permitted=false` on every row.

**No financial transaction is created.** This diagnostic is not a refund
API, provider verification, settlement certification, or bill-transfer
authorization. It cannot prove that external refunds succeeded.

Next: authoritative verified posting, order/item allocations, concurrent
refund integration tests, and Supabase migration validation. ZIP integrity
was checked; SQL execution and Flutter compilation were not performed.

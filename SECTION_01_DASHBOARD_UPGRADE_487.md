# Upgrade 487 — Cash ledger consistency protection

- Reject incomplete cash ledger pairs (amount without receipt count or vice versa) before showing any financial values.
- Reject positive cash totals with zero receipts, preventing misleading combined cash totals.
- Apply the same per-ledger validation to receipt display and combined totals.
- Preserve restricted-data handling and explicitly unreconciled reporting.
- No schema changes or new permissions. No credit settlement activation.

Development estimate: **83%** (unchanged). Flutter compilation, live Supabase tests, and actual ledger reconciliation remain pending.

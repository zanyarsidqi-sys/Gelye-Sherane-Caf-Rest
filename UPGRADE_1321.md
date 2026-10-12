# Upgrade 1321 — Dashboard / Payments recovery

- Dashboard Recorded Cash card explains that payment records can be refreshed/retried.
- Payments ledger RPC now times out after 20 seconds; receipts RPC after 15 seconds.
- Ledger error state now offers a working Retry cash ledger action, keeping authorization checks and existing refresh action.
- No changes to backend RPC names, permissions, receipt validation or financial calculations.
- Static verification only; Flutter/Dart compilation and live Supabase checks remain pending.

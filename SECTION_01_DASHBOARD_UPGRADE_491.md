# Upgrade 491 — Dashboard weekly cash report export

- Adds a seven-day cash collection report copy action to the existing dashboard.
- Exports daily amounts and receipt counts separately for Table Orders and Motel Food.
- Preserves restricted/unavailable values and omits combined totals unless both ledgers are fully accessible.
- Explicitly labels reports as unreconciled cash collections, not revenue or profit.
- No new database migration; uses the permission-scoped Upgrade 488 RPC.
- Dashboard development estimate remains 84%; full accounting reconciliation is outstanding.
- Flutter analysis, compilation, and live Supabase verification have not been performed.

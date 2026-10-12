# Upgrade 490 — Dashboard daily / weekly cash consistency diagnostic

- Adds a read-only cross-report comparison between the existing permission-scoped daily cash RPC (484) and weekly cash RPC (488).
- Compares today's IQD cash amount and receipt count for each ledger only when both snapshots are within 30 seconds and the weekly final date matches the Iraq business date.
- Restricted data is skipped; missing values are never replaced with zero.
- Detects mismatches but does **not** claim financial reconciliation or trigger any payment mutations.
- Does not add a migration. Existing cash reporting functions remain unchanged.

## Verification
ZIP structural integrity checked. Flutter analyzer, app builds, live Supabase migrations, and end-to-end financial tests not run. Section 01 remains 84% provisional development progress.

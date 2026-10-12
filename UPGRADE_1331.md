# Upgrade 1331 — financial binding integrity diagnostics

Both Dashboard and linked Payments Management remain in the Financial Overview batch.

- Extends the existing permission-gated readiness RPC with counts for cross-order reversal references, over-reversed ledger entries and multiple active visits for one table.
- Displays those new diagnostic counts in Payments Management.
- Adds a Dashboard integration note explaining why Standing Cash must stay unavailable until canonical settlement is verified.
- Does not alter or approve live financial amounts; diagnostic counts are not monetary totals.
- Does not change existing payment posting, RLS, or customer-facing order flows.

## Unverified
PostgreSQL migration execution, Flutter compile/analyze, Supabase authorization, staging payment scenarios and device tests.

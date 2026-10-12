# Dashboard Upgrade 49 — Integration & Security Review

- Added `DashboardIntegrationReview` via Dashboard AppBar action.
- Provides non-mutating, employee-permission-scoped connectivity checks for
  five existing draft Supabase read RPCs; no sample data or fake success.
- Distinguishes read-endpoint response from end-to-end verification.
- Displays release blockers for checkout, motel reservation, owner offers,
  permission schema, offline sync and Flutter compilation.
- No migrations deployed and no tests executed against live Supabase.

## Critical code-review findings
- Checkout and release draft SQL currently find orders using a table number,
  not an immutable visit ID; old orders can affect current guests.
- Cash-only settlement check cannot safely establish card/credit/online payment.
- Owner offers draft stores verified state but has no verified owner approval RPC.
- Motel meal offers draft lacks authoritative reservation and item linkage.
- Assignment directory relies on assumed employee_profiles columns.

Do not deploy these drafts as a production feature without schema reconciliation,
financial review, migration tests, and server-side authorization validation.

# Dashboard Upgrade 147 — Negative-path staging tests

Added `supabase/tests/mixed_checkout_negative_paths.sql` with executable
PostgreSQL assertions. Checks that the mixed-release gate is disabled,
no contradictory attestations exist, provider transaction and ledger
idempotency indexes are present, and the `authenticated` role cannot
invoke server-only verification/posting RPCs or read the private gate.

The test runs inside a transaction and rolls back. It is intended for a
**staging** database with migrations through Upgrade 146 applied, and must
be run by an operator permitted to SET ROLE authenticated.

These are negative-path privilege/consistency checks, not a substitute
for signed provider webhook tests, real order fixtures, concurrency
stress testing or Flutter compilation. They have **not** been executed
against Supabase. The mixed-payment release gate remains disabled.

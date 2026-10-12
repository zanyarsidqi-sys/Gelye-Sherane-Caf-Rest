# Dashboard Upgrade 120 — Verify settlement snapshots at checkout

**Actual integration fix:** cash-only checkout no longer trusts the mere
presence of a finance attestation. While order rows are locked, it
recomputes line totals, cash receipt sums and receipt counts, and
rejects discrepancies or subsequently attached noncash financial evidence.

Checkout also refuses to release a table with an unlinked legacy
noncancelled table order identified by table number. This avoids
leaving an older unpaid order behind while a table is marked available.

This supersedes the Upgrade 115 release function via `CREATE OR REPLACE`.
It is deliberately cash-only; mixed methods remain unsupported.

**Deployment caveat:** the legacy `destination` comparison is conservative
and may block checkout when old closed orders were not marked cancelled.
A proper visit-migration strategy is needed. This ZIP has passed archive
checks only; no PostgreSQL execution, Flutter build, or concurrency test.

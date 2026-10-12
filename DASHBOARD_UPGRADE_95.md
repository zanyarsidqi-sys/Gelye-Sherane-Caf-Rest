# Dashboard Upgrade 95 — Block unsafe legacy checkout path

## Concrete change
Replaced the legacy `gs_mark_table_departed_for_cleaning` implementation
with a fail-closed permission-checked function. Previously, that RPC
could mark a table departed and initiate cleaning based on **cash-only**
receipt sums and table numbers spanning historical visits. That was not
reliable after the introduction of visit IDs, payment evidence, credit,
owner offers and the unified ledger.

The replacement **always rejects checkout**. It does not modify table
status, create tasks, or declare any order paid. This is a security fix,
not a completed checkout workflow. A new authoritative, audited checkout
implementation must be built and tested before enabling departure/cleaning.

## Remaining work
- Verify existing table-release and legacy RPCs for bypasses.
- Implement verified visit-level settlement and payment allocations.
- Add visit-specific guest departure, cleaning, shisha and release transitions.
- Run staging migrations, authorization tests and Flutter builds.

ZIP CRC verified; SQL was not executed in Supabase and Flutter was not compiled.

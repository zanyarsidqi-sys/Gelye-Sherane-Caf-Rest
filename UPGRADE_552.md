# Upgrade 552 — Kitchen exception closure integration gate

Prevents an investigation from being closed while the kitchen revision remains pending receipt or failed dispatch. Closure now requires `acknowledged_consistent` from the permission-scoped reconciliation function. Existing employee authorization, case locking, resolution notes, and financial non-mutation remain in place.

## Deployment
Apply migration 552 after 551. This replaces the closure RPC body without altering its signature. Existing closed cases are not modified.

## Verification
Static integration contract checks are in `tests/integration/test_upgrade_552_contracts.py`. They do not substitute for Flutter compilation or a live Supabase migration and integration test.

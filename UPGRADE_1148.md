# Upgrade 1148 — Kitchen migration regression preflight

Added `tools/verify_kitchen_migration_contract_1148.py`, a repeatable, read-only
12-condition offline migration consistency checker. It finds the latest definition
of the Kitchen status RPC and served-item guard in the migration sequence, checks
authorization, locks, item validation, trigger events and grants. The test suite
also verifies that removing the authorization check makes the audit fail.

Run: `python tools/verify_kitchen_migration_contract_1148.py`.
This validates source migrations only, not deployed PostgreSQL, actual race
behavior, Flutter compilation, or runtime Kitchen acceptance. All five Kitchen
runtime acceptance areas remain unverified (0/5). Next: 1149.

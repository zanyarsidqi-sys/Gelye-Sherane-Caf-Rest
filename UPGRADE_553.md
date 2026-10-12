# Upgrade 553 — Cross-module replacement integration contracts

This upgrade adds executable offline regression contracts for the Table Orders replacement lifecycle across Flutter and Supabase. It preserves all existing application code and migrations.

## Added
- `tests/integration/test_upgrade_553_cross_module.py`: five automated checks covering server-side normal/tourism pricing, confirmed-price commit, financial evidence barriers, kitchen notification dispatch, revision snapshots, reconciliation and case closure permission gates, and Flutter RPC wiring.

## Verification actually performed
- `python -m unittest discover -s tests/integration -p 'test_upgrade_*.py' -v`: **8 tests passed** (3 existing + 5 new).
- ZIP integrity checked separately when packaged.
- Flutter compilation: **not performed** (Flutter executable unavailable).
- Live Supabase migration and role-based testing: **not performed**.

## Limitations / next meaningful work
These are source-level contract tests, not database integration tests. A live staging Supabase test suite must exercise concurrent replacement attempts, changes in product price after quoting, rejected permission roles, already paid orders, kitchen acceptance, dispatch retries, and case resolution. Do not deploy untested migrations to production.

Section 03 estimated progress remains 76% until runtime verification supports a revised estimate.

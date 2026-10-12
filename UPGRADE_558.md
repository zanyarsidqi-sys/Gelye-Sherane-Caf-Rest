# Upgrade 558 — Table Orders replacement integration verification

This upgrade adds offline regression coverage for the **final effective** product replacement quote and commit function definitions, rather than testing only their original Upgrade 538 declarations. It verifies the latest Upgrade 557 overrides, edit permissions, serialized order access, unresolved kitchen revision guards, financial/ticket evidence checks, server-side Normal/Tourism pricing, price confirmation, and revision dispatch destinations. It also checks legacy RPC access revocation and Flutter RPC references.

## Deployment / verification
- No new SQL migration is needed. Existing migrations remain unchanged.
- Run `python -m unittest discover -s tests/integration -p 'test_upgrade_558*.py' -v` from the project root.
- These are **static contract tests only**. They cannot verify actual PostgreSQL execution, concurrency, Supabase grants, Flutter compilation, or real kitchen delivery.
- Before production, apply migrations in a staging Supabase project and exercise authorized/unauthorized calls, stale prices, concurrent replacements, kitchen receipt, and invoice/payment barriers.

# Upgrade 556 — Missing kitchen dispatch guard

The replacement quote and commit RPCs now reject another replacement whenever a prior product-replacement revision lacks a positively acknowledged kitchen dispatch, **including when the dispatch row is missing entirely**. Previously an inner join excluded orphan revision events, allowing the replacement gate to be bypassed by missing outbox records.

This is a fail-closed guard, not automatic repair. Investigate missing dispatch records through the existing kitchen exception workflow. Existing order locks, pricing validation, payment/ticket checks, permissions and audit behavior are retained from Upgrade 555.

## Verification
- Static contract tests and archive integrity checked locally.
- Flutter compilation, migration execution against Supabase, and concurrency testing were not performed.
- Apply migration 556 after 555 in a staging environment before production.

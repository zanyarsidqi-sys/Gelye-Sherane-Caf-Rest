# Upgrade 1458 — Verified credit posting UI (disabled by default)

Changes: adds a two-confirmation Flutter RPC flow for verified credit requests, deterministic idempotency key, fail-closed response validation, duplicate-tap prevention, and an opt-in compile-time staging gate. Existing navigation and filters unchanged.

**Not enabled in production.** To test in an authorized staging build only, supply `--dart-define=GS_ENABLE_VERIFIED_CREDIT_POSTING=true` after applying ALL migrations, reviewing permissions, testing invoice/source integrity, concurrency, retries, rollback, journal/account balance, and credit-link triggers against actual PostgreSQL. Never turn on before sign-off.

A posted credit account charge is NOT a settled invoice, prepaid allocation, unified-ledger entry, or certified Standing Cash/Pending Payment balance. The response intentionally rejects any such certification.

No live database tests or Flutter compile were run in this environment.

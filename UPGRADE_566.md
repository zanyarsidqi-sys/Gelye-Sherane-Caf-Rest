# Upgrade 566 — Replacement receipt integrity and recovery

- Adds an immutable database trigger for completed replacement request receipts.
- Adds a permission-protected, actor-scoped recovery status RPC.
- Changes Flutter uncertain-response reconciliation to use the new status RPC.
- A missing receipt is **not** treated as permission to retry: the original request might still be in flight.
- Preserves all existing project files and earlier migrations.

## Deployment
Apply migration 566 after migration 565. Staging testing is required before production.

## Verification limitations
Static tests only; Flutter build and live Supabase execution were not available.

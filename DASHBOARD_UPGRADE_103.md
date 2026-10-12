# Upgrade 103 — Actual cash accounting correction posting (limited scope)

Unlike upgrades 99–102, this adds a **mutating, atomic posting RPC** for a narrow,
finance-approved **negative cash receipt accounting correction**. It creates an
append-only correction posting, with idempotent retries and independent
requester/reviewer/preparer/poster checks. A companion read RPC shows original,
adjustment and accounting-net amounts. No original cash receipt is edited.

**Not a refund:** posting does not return physical cash, send money to a provider,
change the unified payment ledger, change customer balances in existing reports,
or authorize checkout. Existing reconciliation reports must be explicitly updated
and tested before using the new accounting-net values. Positive corrections
require actual new collection and are rejected here.

No live Supabase migration or Flutter build has been run. Staging tests are
mandatory; specifically verify RLS, audit schema, SQL function compilation,
concurrent retries and separation-of-duties logic. Overall Phase 3 estimate
remains 54% until verified.

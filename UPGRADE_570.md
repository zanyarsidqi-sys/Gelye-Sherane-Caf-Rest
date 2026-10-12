# Upgrade 570 — Replacement receipt reconciliation

Adds an employee-scoped read-only Supabase RPC that reconciles a committed replacement receipt with its order revision, kitchen dispatch record, current item, and the presence of payment ledger entries. The cross-device request-ID lookup now displays those diagnostic indicators. The function never retries or changes an order; an absent receipt is never interpreted as safe to retry. A later replacement may make the current item differ legitimately. Payment presence is not payment correctness; kitchen dispatch existence is not acknowledgment.

Apply migration 570 after 569. Live Supabase and Flutter tests remain outstanding.

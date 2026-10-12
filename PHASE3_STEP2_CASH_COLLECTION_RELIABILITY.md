# Phase 3 Step 2 — Cash collection reliability

- Cash collection now loads order items and cash payments in two batched queries instead of two queries per order.
- Shows total, recorded cash, and outstanding amount for each order.
- Refreshes after both successful and uncertain payment attempts. A network error may occur after server commit; staff must check ledger before retrying.
- No changes to customer credit, card processing, or SQL migrations.
- IMPORTANT: Display balances reflect cash payments only; do not treat them as final balances if other tender types are enabled.
- Still requires Flutter compilation, real Supabase/RLS testing, and verification of the existing payment RPC idempotency rules.
- Implementation progress remains at the last reported 61% estimate; not independently audited.

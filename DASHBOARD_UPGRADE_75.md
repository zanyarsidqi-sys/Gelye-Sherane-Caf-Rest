# Dashboard Upgrade 75 — Payment Ledger Reconciliation Crosswalk (DRAFT)

Added `20261009_075_cash_ledger_reconciliation_crosswalk_draft.sql`.

- Introduces a private, unique one-to-one link between an original cash receipt
  and its corresponding unified-ledger entry. No automatic links are created.
- Read-only financial RPC reports missing links and mismatched order, amount,
  direction, type, or source system, with employee permission checks.
- Explicitly does not double-count the same cash payment across ledgers.
- No direct grants for employees to forge crosswalk links or ledger postings.
- No settlement confirmation, cash collection, provider verification, credit
  deduction, owner waiver, or bill transfer is enabled.

## Remaining blocker
Actual verified payment posting needs server-side provider integrations,
transactionally locked order balances, idempotent source references, correct
refund handling, and an authoritative reconciliation/migration strategy.
The review report is diagnostic only; a matching crosswalk does not establish
that a customer has fully settled an order.

## Validation status
ZIP integrity checked. SQL has not been run on PostgreSQL/Supabase and Flutter
has not been compiled. Do not deploy this draft to production.

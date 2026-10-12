# Dashboard Upgrade 61 — Unified Settlement Safety Foundation

Implemented a draft schema for noncash payment evidence and a **read-only**
settlement diagnostic RPC. It reconciles current cash entries and *recorded*
external evidence per order, returning clear warnings for unverified records.

Safety guarantees:
- Staff cannot create or mark evidence verified through this migration.
- External evidence is private under RLS; there are no direct table grants.
- `transfer_safe` is deliberately **always false**, because the current
  system cannot prove all card, online, credit and waiver settlements.
- No changes to existing cash collection, order totals or customer balances.
- No actual transfer, settlement approval, or checkout release.

Still required: verified provider callbacks, customer credit debit/approval,
owner waiver ledger, single locked and idempotent settlement engine, and
end-to-end payment tests. Existing payment RPC needs updating to consider
all verified payment types. SQL migration not deployed or tested.

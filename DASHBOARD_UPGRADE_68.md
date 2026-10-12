# Dashboard Upgrade 68 — Secure Transfer Execution Gate (DRAFT)

Added `gs_apply_table_bill_transfer(request_id, idempotency_key)` as a
permission-checked, **fail-closed** RPC contract. It validates the request
and checks existing financial sources, but ALWAYS raises an explicit
exception rather than moving money, items, guests, or table assignments.

Why execution is blocked:
- Cash records and the new unified ledger have not been reconciled.
- External provider payments and customer credit debits are not yet
  authoritative or transactionally posted.
- Item-level allocation of partially paid orders is not implemented.
- Owner-approved waivers need genuine owner verification and posting.
- Payment writers must share order locks and idempotency semantics.
- Destination visit/order changes and audit must be atomic.

This step prevents an accidental caller from treating a draft transfer
request as executable. It is not the promised operational bill-transfer
feature. SQL and Flutter have not been compiled/deployed or live-tested.
The 73-stage roadmap remains provisional and will likely require more
stages for genuine functional completion.

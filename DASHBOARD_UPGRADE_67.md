# Dashboard Upgrade 67 — Unified Payment Ledger Foundation (DRAFT)

Added a private ledger schema with unique external source references, verified
posting timestamps, and linked refund/reversal entries. No employee or client
has direct table privileges; there is **no payment posting RPC**.

A read-only financial diagnostic reports legacy cash and new-ledger amounts
**separately** and warns about potential double counting. `settlement_confirmed`
is always FALSE until migration, provider verification and unified payment
writers are implemented and tested.

Outstanding: trusted provider callback verification, credit account debits,
owner-approved waiver posting, atomic order locking, idempotent cash migration,
refund and reversal enforcement, financial reconciliation, live tests, and
secure bill transfer execution. No Flutter compile or Supabase deployment.

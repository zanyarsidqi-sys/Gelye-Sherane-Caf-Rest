# Upgrade 1463 — prepaid evidence allocation

The provider receipt table is a **trusted integration input**, not a staff confirmation screen. No ingestion adapter is included. The table is not populated by this upgrade. Only an independently verified payment-provider integration using protected service credentials may insert receipts. Never insert test receipts in production.

The authorized RPC allocates a verified full-amount receipt once, with invoice lock, cash/credit collision checks, idempotent retry and immutable source records. It deliberately does **not** mark an invoice settled, post to the unified ledger, or certify Dashboard IQD totals. Staging tests and reconciliation of actual payment-provider records are release blockers.

Staging checklist: apply migration on disposable database; test unauthenticated denial, missing receipt, amount mismatch, source mismatch, cash/credit collision, conflicting draft, successful allocation, repeat idempotency, concurrent allocation, rollback and immutable evidence. Never enable real payment posting until results are independently reviewed.

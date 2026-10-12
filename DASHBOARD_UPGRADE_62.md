# Dashboard Upgrade 62 — Cash Payment Race/Overcharge Hardening (DRAFT)

New migration `20261009_062_cash_payment_interlock_draft.sql`.

- Replaces existing cash payment RPC while keeping its call signature.
- Locks the order row before examining or writing the cash ledger.
- Preserves UUID idempotency and prevents same-key mismatched charges.
- Rejects payments that exceed remaining order value.
- **Fails closed** if external payment evidence, an active owner complimentary
  request, or an active bill-transfer request exists for the order.
- Does not allow transfers, mark noncash payments verified, or release tables.

This may intentionally BLOCK cash payments for orders awaiting review. It is
not ready to deploy until staff resolution flows and all payment writers are
reviewed. Correctness depends on every other settlement writer respecting
the same order lock. Flutter and Supabase tests have not been run.

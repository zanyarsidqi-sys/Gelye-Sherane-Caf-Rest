# Dashboard Upgrade 66 — Payment Verification Intake (DRAFT)

New migration `20261009_066_payment_verification_intake_draft.sql` adds:

- Private, RLS-protected payment-provider event inbox, keyed by provider event ID.
- Read-only exception queue for authorized financial staff.
- Amount/currency mismatch indicators for reconciliation review.
- No staff or client write privileges, no provider verification endpoint.
- No changes to balances, order settlement, credit accounts, or bill transfers.

**Important:** Matching an amount is NOT proof of payment. Production must
validate provider webhook signatures, retrieve transaction state from trusted
providers, bind it to the correct order/account, reject replay and mismatches,
handle reversals/refunds, and post a single idempotent ledger transaction.
Customer barcode credit debit requests require their own server-side balance
and approval checks. No provider integration, Flutter build, Supabase migration
execution, or end-to-end testing has been completed.

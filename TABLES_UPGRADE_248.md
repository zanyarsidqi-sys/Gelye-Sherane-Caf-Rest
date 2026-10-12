# Upgrade 248 — Locked invoice cash safety

## Actual change
- Replaces legacy `gs_record_cash_payment` with a fail-closed guard: a locked Admin-discounted invoice can **never** be paid using the old undiscounted order-item total.
- Preserves legacy cash collection for ordinary orders, with the existing per-order lock, reference idempotency, and overpayment checks.
- Adds Admin-only, read-only `gs_locked_discount_cash_readiness` RPC to inspect the locked snapshot, payment intent and source audit.

## Not yet supported
- No cash capture for locked invoices, credit debit, mixed settlement, payment posting, physical printing or live integration testing.
- Other legacy payment writers must be audited and guarded before production rollout; this patch alone does not guarantee all writers are safe.

## Deployment
Apply prior migrations in order, then `20261010_248_locked_invoice_cash_guard.sql` in staging. Test both ordinary cash collection and rejection of locked invoices before production. Review all writers with direct ledger permissions or SECURITY DEFINER privileges.

## Progress (estimated)
Tables code coverage remains 94% (unverified); integration and production readiness are not measured, and live tests have not run. Customers paused at 45%.

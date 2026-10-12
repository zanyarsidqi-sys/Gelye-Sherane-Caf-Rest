# Upgrade 397 — Cashier confirmation review gate

Adds a secured, idempotent cash-only cashier review preparation RPC and employee UI action. Requires active cash draft, matching unpaid invoice, reconciled source and matching allocation review plan. Review records are immutable through client access and cannot be mistaken for receipts. No payment posting, cash collection, customer credit debit, or invoice status changes.

## Deployment
Apply `20261010_397_motel_cash_confirmation_review.sql` after 396. No live database or Flutter compilation was available for this build.

## Next
Design the authoritative cash receipt ledger and settlement status transition with cashier acknowledgement, balancing and idempotent payment writer; reconcile with legacy ledger before enabling actual payment confirmation.

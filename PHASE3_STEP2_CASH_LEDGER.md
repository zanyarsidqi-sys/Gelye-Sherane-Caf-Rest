# Phase 3 Step 2 — Cash collection ledger
Added `gs_cash_payments`, permission-controlled cash RPC, idempotent reference handling, per-order locking, outstanding balance validation, and a Flutter cash collection panel.

## Deployment
Apply `20261009_021_cash_payment_ledger.sql` after previous migrations. Ensure employee permission key `invoices_payments` has `can_create` for cashiers. Test with authenticated staff and RLS before production.

## Limitations
This records manually confirmed cash only. It does NOT process cards, customer credit, refunds, or tax-compliant invoices. No Flutter build, live database migration, or integration test was performed. Cash collections can be reviewed using the ledger; other payment methods remain unavailable.

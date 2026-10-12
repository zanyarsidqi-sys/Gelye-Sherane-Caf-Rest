# Upgrade 359 — Delivered motel food billing staging ledger

Creates one immutable-by-permission staging record per delivered food request, with server-side amount reconciliation, idempotent unique request ID, employee read-only listing, and safe backfill. No invoice linkage or payment posting exists. Payment status remains unpaid until a later explicit, audited payment integration.

## Deployment
Apply migration 20261010_359_motel_food_billing_ledger.sql after 358. Validate SQL in staging and test Supabase RLS/roles and Flutter build. Existing historical delivered requests without timestamps or with mismatched item totals are intentionally not backfilled and require manual reconciliation.

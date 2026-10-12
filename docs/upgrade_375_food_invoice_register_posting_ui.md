# Upgrade 375 — Employee food-only invoice register posting

- Adds confirmation-protected **Post food-only register** action in Food Billing Ledger.
- Calls existing Upgrade 374 transaction-safe `gs_staff_post_motel_food_invoice_register` RPC.
- Shows posted register IDs, source counts, IQD totals and timestamps via `gs_staff_list_motel_food_invoice_register`.
- Server enforces both Motel Orders and Invoices & Payments edit permissions, exact source reconciliation and idempotency.
- **No unified invoice, cash collection, payment allocation, or credit deduction.**
- Deploy migrations in order through 374 before using this UI.
- Flutter compilation and live Supabase testing not available in this environment.

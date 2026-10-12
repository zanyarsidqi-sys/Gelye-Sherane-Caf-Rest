# Phase 3 Step 2 — Cash Payment Summary in Orders

Table Orders and Motel Orders now allow an employee to tap a live order and retrieve its server-calculated cash payment summary via `gs_order_cash_payment_summary`.

Requires SQL migration `20261009_025_order_cash_payment_summary.sql` and its prerequisites. Supabase permission checks remain server-side. The dialog does not record or modify payments. Card/credit settlements are excluded.

Not yet verified: Flutter compilation, database migration deployment, live authentication/RLS and integration tests.

Progress: 61% previous provisional implementation estimate; no defensible project-wide recalculation yet.

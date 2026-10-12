# Upgrade 377 — Finance Source Line Audit

Added an employee read-only drill-down in Invoices & Payments > Motel Food Handoff.
The SQL RPC `gs_staff_motel_food_finance_line_audit` compares each posted food register line against the staging ledger, original delivered food order, and source reservation. It flags missing sources, guest/room mismatches, source reference mismatches, amount mismatches, and orders no longer delivered. Viewing requires both Motel Orders and Invoices & Payments view permissions.

This is a **diagnostic**: it does not post unified invoices, mark bills paid, or allocate cash/credit. The previous summary integrity status checks line counts and totals only; staff should inspect line-level exceptions as well.

Section 04 estimate remains **79%**. Flutter build and live Supabase migration are not verified in this environment.

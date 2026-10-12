# Upgrade 791 — replacement write

Section: table_orders

Acceptance checkpoint: verify `gs_replace_unaccepted_table_item` in `lib/sections/table_orders.dart`.

Result: PASS in static source inspection. This does not establish Flutter runtime behavior, Supabase security, or production readiness.

No application code change for this checkpoint; it is a newly recorded acceptance assertion.

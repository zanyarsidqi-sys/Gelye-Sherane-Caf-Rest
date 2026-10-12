# Tables Upgrade 216 — Employee performance report

- Adds permission-protected SQL RPC `gs_manager_table_employee_performance` for 7/30/90 day reporting.
- Aggregates completed job counts, average response and service times, and late completion rates by employee in the database (not a 500-row client snapshot).
- Excludes missing or inconsistent timestamps from the corresponding averages; excludes jobs with no due date from late-rate denominator.
- Adds a manager dialog and toolbar action to `lib/sections/tables.dart`.
- Does not alter Section 08 — Customers.
- Section 02 estimate: 90%; Section 08 paused at 45%.
- ZIP validated; Flutter compilation, live Supabase migrations, and role-based tests NOT performed.

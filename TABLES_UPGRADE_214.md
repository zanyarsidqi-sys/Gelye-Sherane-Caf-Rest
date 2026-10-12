# Upgrade 214 — Manager job filters and overdue table reporting

Section 02 — Tables: the manager's read-only job overview now supports employee and table filters, a reset action, and an expandable ranking of tables with overdue jobs. Selecting an overdue table filters the job list to its overdue tasks. All figures are derived from the existing permission-scoped `gs_manager_table_job_overview` RPC snapshot (up to 500 rows); the screen does not assert complete historical counts. No database changes or new grants.

Source/ZIP verification only. Flutter compilation and live Supabase tests were not run. Tables 88% estimated; Customers 45% paused.

# Upgrade 213 — Manager employee workload and overdue reporting

Updated Section 02 (Tables) manager overview to summarize active jobs by assigned employee, in-progress jobs, urgent jobs and overdue jobs, sorted by overdue count then workload. Uses the existing permission-gated `gs_manager_table_job_overview` RPC; no new database permissions or migration required. Employee summaries are derived from the same read-only snapshot and include a clear warning that the RPC caps results at 500 jobs.

Verification: source presence and ZIP integrity only. Flutter compilation, Supabase integration, and live UI testing have NOT been run. Tables 87% estimated; Customers remains 45% paused.

# Upgrade 212 — Manager Table Service Overview

- Added a manager-only Supabase RPC to list up to 500 open table jobs, with employee names, status, priority, due time and assignment.
- Added a read-only Flutter manager overview with counts, filters, overdue flags and refresh.
- Uses existing `gs_can_access('tables','can_edit')` backend authorization; no new permission grants.
- Existing assignment and reassignment workflows unchanged.
- Pending: Flutter compile, migration deployment, live permission tests, concurrency tests.
- Section 02 Tables: 86% estimated, NOT production-verified. Section 08 Customers remains paused at 45%.

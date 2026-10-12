# Upgrade 498 — Dashboard reporting source health

- Added a four-source reporting health panel for operational totals, seven-day orders, daily cash, and weekly cash.
- Each source has independent loading, failure, and response-received states.
- Added Retry all action. Permission-restricted information is never presented as zero.
- Response received is explicitly **not** a guarantee of reconciliation or metric access.
- Preserved all prior migrations and source files; no database changes.

## Verification limitations

Source and archive checks only. Flutter analyze/build, live Supabase migrations, permissions and end-to-end tests were not executed. Dashboard development remains 84% provisional.

# Upgrade 203 — My job capacity in Available Jobs

- Added `gs_my_table_job_capacity()` RPC returning only the signed-in employee's eligibility, assigned count, configured limit, and remaining slots for each job kind.
- Available Jobs now shows `active / limit` and remaining slots per task; disallows Claim when unauthorized, full, or capacity cannot be loaded.
- Refresh reloads both queue and capacity. Claim RPC and database workload trigger remain the final enforcement authority (snapshot may become stale).
- Does not implement realtime/push notifications or verified deployment.
- Section 02 — Tables: **82% estimated coding completion**. Flutter build, SQL migration application, and concurrency tests not performed.

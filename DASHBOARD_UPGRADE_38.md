# Dashboard Coding Upgrade 38 — Service task backend foundation

Added `20261009_039_table_service_tasks_draft.sql`:
- Protected table-service task schema with table FK, request types, priority, quantity, status, assignee, timestamps.
- Permission-checked `gs_dashboard_table_service_tasks` read RPC used by the existing panel.
- Filters by table ID; rejects malformed IDs; caps results.
- No direct authenticated write permissions. No fake service tasks or sample numbers.

NOT IMPLEMENTED: cashier assignment, employee notifications, task completion,
automatic cleaning, shisha detection, table-release guard, audit event producers.
This is a draft migration, NOT deployed or verified against live Supabase.
Flutter compile/tests deferred per project instructions.

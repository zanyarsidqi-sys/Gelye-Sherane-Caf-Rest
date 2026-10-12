# Dashboard Upgrade 40 — Task assignment & progress UI (draft integration)
- Table Service Requests dialog offers Assign, Accept, Start, Complete actions.
- Calls `gs_assign_table_service_task` and `gs_update_table_service_task_status` server RPCs.
- Prevents overlapping requests, refreshes on success, shows backend rejection without claiming success.
- Assignment uses temporary employee UUID entry (proper permission-filtered employee picker pending).
- Server RPCs, audit table and migrations have NOT been deployed or tested.
- Notifications, employee picker, task creation, automatic cleaning and release guard still pending.
- UI buttons may be visible to users who lack server permission; backend must reject unauthorized actions.

# Upgrade 254 — Employee service job list

- Adds Employee Jobs tab to protected Table Orders section.
- Queries `gs_manager_table_job_overview` when permitted, otherwise `gs_list_my_table_jobs`; both enforce permissions server-side.
- Shows table number, task kind, details, priority, assigned employee, status, filters, and refresh.
- Assigned employees can start and complete their own service jobs through `gs_update_my_table_job`. Delivery tasks cannot be completed via generic job action.
- This is a service job queue, **not yet** a full pending/new/prepared/delivery kitchen order board. No automatic live subscription, secure public QR session or split billing implemented in this upgrade.
- Requires applying prior migrations, Flutter compilation and Supabase integration testing. No live testing performed.

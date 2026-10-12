# Dashboard Coding Upgrade 39
Draft secured backend RPCs:
- `gs_assign_table_service_task`: permission-gated assignment with row locking and audit.
- `gs_update_table_service_task_status`: state machine with assigned-employee or manager access, audit.
- No direct client writes; closed tasks cannot be reassigned; invalid transitions rejected.
Limitations: assignment checks auth user existence, NOT employee active/on-duty status;
no notifications or UI action buttons yet; no automatic cleaning/table release integration.
SQL depends on migrations 036 and 039 and must be reviewed/deployed/tested later.

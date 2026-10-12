# Dashboard Upgrade 46 — Notification inbox and overdue tracking

- Notification inbox now displays unread count and unread-only filter.
- Opening a notification acknowledges it through a recipient-scoped backend RPC, then opens the task queue.
- Added `gs_mark_service_notification_read` (no direct client table writes).
- Added `gs_my_overdue_service_tasks` for recipient-only on-demand SLA tracking (15-minute default, configurable argument).
- No scheduled/push reminders, badge polling, direct individual-task navigation, or live verification.
- Existing backend dependencies remain drafts and need schema review before deployment.

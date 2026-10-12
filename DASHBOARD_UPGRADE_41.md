# Dashboard Upgrade 41
- Replaced temporary employee UUID entry with a server-provided active employee picker.
- New draft RPC `gs_service_assignable_employees()` checks assignment permission.
- Added draft durable in-app task notification table, enqueue trigger, and recipient-only read RPC.
- Notifications are created transactionally on assignment/reassignment and task status updates.
- No actual push notification or employee inbox UI yet.
- Migration dependencies, schema compatibility, and permission behavior require live review.
- No Flutter compilation or Supabase deployment performed.

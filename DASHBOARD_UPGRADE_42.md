# Dashboard Upgrade 42 — Employee service notification inbox

- Dashboard notification icon opens recipient-scoped inbox.
- Inbox fetches via draft `gs_my_service_task_notifications` RPC; supports refresh, empty/error/loading states.
- Tap a notification to open service task queue.
- Notification delivery is database/in-app only; no push notifications, unread badge, read receipt, or direct task deep-link yet.
- Requires previous draft migrations and backend schema validation.
- ZIP integrity verified; Flutter compile and Supabase verification deferred.

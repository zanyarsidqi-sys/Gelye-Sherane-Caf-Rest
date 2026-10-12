# Dashboard Upgrade 80 — Manual notification cursor synchronization

The existing Offline Mode & Synchronization Flutter screen now includes a real,
**manual, online-only** notification cursor fetch against
`gs_my_service_notifications_since` (Upgrade 58 migration).

- Requests batches of up to 100 notifications, ordered by (created_at, id).
- Validates monotonic cursor ordering and only advances after a valid response.
- Keeps cursor in process memory; resets on employee account change.
- Shows fetched event count, cursor ID, timestamp, and request errors.
- Does not queue or replay financial mutations or persist sensitive data.

**Limitations:** This is not full offline sync. The notification creation cursor
cannot detect read/unread updates; the server summary still handles unread
counts. No durable encrypted cache, push delivery, background scheduler,
conflict resolution, or server-side queued mutation authorization exists.

Next: Stage 81 static audit and staging/Flutter testing plan. SQL has not been
deployed, and Flutter has not been compiled or run on a device.

# Upgrade 1208 — Delivery notification acknowledgment and escalation

- Staff receive permission-scoped unread assignment notifications, acknowledged per assignment timestamp.
- Reassignment creates a new unread notification; previous acknowledgments remain auditable.
- Supervisor open-screen polling (15 seconds) invokes idempotent overdue escalation before reading the escalation inbox.
- Overdue escalation requires an authorized supervisor session. No background scheduler, OS push notification, or live Supabase validation is claimed.
- Table Orders/Kitchen integration continues to use shared replacement delivery task and order identifiers.

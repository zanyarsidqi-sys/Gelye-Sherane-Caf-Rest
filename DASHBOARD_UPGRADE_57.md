# Dashboard Upgrade 57 — Notification sync & security review

Added draft migration 058:
- `gs_my_service_notifications_since` returns a stable, ascending cursor feed
  for notifications belonging only to the signed-in employee.
- `gs_my_service_notification_summary` returns own unread count and latest time.
- RPCs require authentication; no anonymous execution or direct table grants.
- Cursor uses both creation timestamp and id to handle ties.
- Bounded result sizes (maximum 250).

Review findings / not yet implemented:
1. No push delivery or real-time subscriptions have been tested.
2. Notification read/unread changes are not propagated by the creation cursor.
   The app must refresh the inbox/summary or implement a change stream.
3. Offline mode must cache read-only dashboard snapshots per employee and
   clear them on logout/account switch; never reuse another user's cached data.
4. Queue only permitted low-risk offline drafts with idempotency keys.
   Payment, bill transfer, owner approval, table release and cleaning signoff
   must be server-verified online transactions, not offline local approvals.
5. On reconnect, recheck MFA, permissions, active visit and current balances.
6. Migration names and RPC dependencies require live schema reconciliation.
7. Flutter UI, local persistence, RLS integration, realtime and production
   tests have NOT been completed.

This is a backend sync foundation and checklist, NOT full offline integration.

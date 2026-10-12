# Upgrade 188 — Table Work Notification Inbox

Added an on-demand **Table work notifications** dialog to the Tables toolbar.
The inbox loads the 100 most recent permitted events from the Upgrade 187
Supabase RPC, showing the table, event, message, timestamp and linked job ID.
Employees can manually refresh to see newly prepared or delivered items.

**Scope limitation:** This is a read-only polling UI, not push delivery,
realtime subscriptions, unread tracking, or personalized recipient routing.
Delivery-job pickup/completion is NOT connected in this increment.
The backend still records the notification events transactionally.

Tables progress ~66% estimated. No Flutter compilation or live Supabase
migration/testing performed. ZIP integrity verified.

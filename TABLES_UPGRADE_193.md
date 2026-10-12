# Upgrade 193 — Employee job-assignment inbox routing

New database trigger routes job claim/assignment/reassignment events to the
existing Table Work Notifications inbox. Assigned workers receive targeted
notifications; job creators receive event updates when they differ from the
assigned worker. Event-source deduplication protects against repeated routing.
Existing targeted claim events are backfilled; no broad broadcast of
employee-specific assignments. Notifications are visible when refreshed.

**Limitations:** There is no manager reassignment RPC yet, so the trigger
supports future reassignment events but cannot generate them. No push,
background dispatch or realtime subscriptions yet. The current inbox
still permits shared fulfillment notifications for authorized staff.

Tables completion: **72% estimated**, not live verified. No Flutter build
or Supabase migration was executed. ZIP integrity checked.

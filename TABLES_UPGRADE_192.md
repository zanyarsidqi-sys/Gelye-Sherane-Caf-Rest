# Upgrade 192 — Unread Table Notifications

Per-user unread/read state for both shared and employee-targeted table events.
Added permission-checked list and mark-read RPCs, with private read receipts.
The Tables notification dialog now displays unread count and allows each
employee to acknowledge an individual event. Acknowledging a broadcast event
does not mark it read for other employees. Read receipts are idempotent.

**Still pending:** automatic push delivery, realtime subscriptions, routing
new assignment events into this notification table, device alerts and
end-to-end testing. No claim that notification delivery is live.
Tables estimated 71%; Flutter build and Supabase deployment unverified.

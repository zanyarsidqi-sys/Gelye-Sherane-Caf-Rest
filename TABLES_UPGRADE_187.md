# Upgrade 187 — Table Fulfillment Notifications and Delivery Queue

When an item advances to Accepted, Preparing, Prepared, Picked Up, or
Delivered, a transactional notification event is recorded. On Prepared,
a table delivery job is created for eligible employees to claim in
**Available Jobs**. Repeated event insertion does not duplicate the
notification, and a job lookup reduces duplicate job creation.

Added `gs_list_table_work_notifications()` for permission-gated
read-only retrieval. **No real-time delivery, push dispatch, notification
badge, or read acknowledgement UI yet.** Jobs created here are not
automatically completed when the item is delivered. Worker claiming
is separate from actual item pickup authorization and must be linked.

Live Supabase migrations, Flutter build, and end-to-end tests remain
pending. Section 02 Tables ~65% estimated. ZIP integrity checked.

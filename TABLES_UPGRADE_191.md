# Tables Upgrade 191 — Reliable Item/Delivery Job Linking

Added a real `order_item_id` foreign key on service jobs, replacing
matching delivery jobs by free-text descriptions. Existing generated
jobs are backfilled only when the description matches exactly. The
migration **fails closed** if any active delivery jobs cannot be
linked or if duplicates exist; review/repair before retrying.

A partial unique index prevents two active delivery jobs for one item.
The preparation event trigger and verified pickup/delivery RPC now use
the relational link. Job claim, pickup, delivery and completion remain
transactionally separate from payment status.

**Limitations:** Existing cancelled delivery jobs may be retained;
partial-quantity delivery, push notifications, real-time alerts and
live build/Supabase migration tests remain pending. Do not run this
migration blindly on production data; inspect any preexisting jobs.

Tables **70% estimated**; deployment not verified. ZIP integrity verified.

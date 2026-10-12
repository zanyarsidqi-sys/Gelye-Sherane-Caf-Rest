# Upgrade 189 — My Jobs and employee lifecycle

Added a **My Jobs** Flutter dialog in Tables and two permission-checked
Supabase RPCs. Employees can view only their own active assigned jobs,
start an assigned job, and complete an in-progress non-delivery job.
Transitions lock the job row and write audit/notification events.

**Delivery safeguards:** `deliver_items` jobs cannot be marked completed
using the generic service-job action. The dedicated item-delivery
confirmation and synchronization with job completion remain pending.
Events are durable records; push delivery is not implemented.

Estimated Tables progress **67%**. No live Supabase or Flutter build tests.
ZIP integrity verified; SQL schema compatibility requires deployment checks.

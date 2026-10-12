# Tables Upgrade 175 — Unassigned Jobs, Atomic Claiming & Notification Events

Added a Supabase foundation for table-service jobs: take orders, deliver
items, clean, shisha service, tea service, bring bill and other tasks.
Managers with Tables edit permission can create unassigned jobs.

Eligible staff can list unassigned jobs and claim one using
`gs_claim_table_service_job(job_id)`. The function locks the job row,
so two simultaneous claims cannot both succeed. It writes a durable
`job_claimed` notification/audit event directed to the job creator.
Job creation also records a `job_created` event.

**Important:** Notification events are NOT push/in-app notifications yet.
A notification dispatcher, recipient routing and UI are pending.
Job completion, release, reassignment, item-level delivery verification
and worker load management also remain to be implemented.

Existing item-level payment preview is still non-posting/disabled.
No actual payments, orders or delivery statuses are changed by this code.

Tables estimate **55%** after scope expansion. 7 of 20 earlier milestones
complete; outstanding tasks include new expanded features. ZIP integrity
checked; live Supabase migration and Flutter build not tested.

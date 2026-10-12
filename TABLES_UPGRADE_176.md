# Tables Upgrade 176 — Flutter Unassigned Jobs Queue

Added **Available unassigned jobs** to the Tables toolbar.
Employees can view table, job type, priority, details, due date and
claim a job using the atomic Upgrade 175 Supabase RPC.

On claim success the list reloads; on conflict the employee sees a
failure and the queue refreshes. The backend is authoritative about
assignment. No payment, delivery or order status is modified.

This is an on-demand read/claim interface. Realtime subscriptions,
notification delivery, job completion/reassignment and My Jobs
interfaces are pending. No live Supabase/Flutter build tests.

Tables development **57% estimated** against expanded requirements.
7 of 20 original major milestones completed; scope-expanded features
remain outstanding.

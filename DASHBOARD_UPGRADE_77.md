# Dashboard Upgrade 77 — Guest Movement Request Cancellation

Implemented a **transactional, permission-checked cancellation** RPC for pending
movement requests. A cancellation locks the request row, changes status from
`pending` to `cancelled`, and records actor, reason, and timestamp in a private
RLS-protected audit table. A repeat cancellation returns `false` without
creating a second audit event. Applied/rejected requests cannot be cancelled.

**Guest movement execution remains disabled.** Moving people between tables
requires checks for active reservations, synchronized source/destination guest
counts, table cleaning/shisha status, outstanding bills, and payment allocations.
This update intentionally does not change guests, table occupancy, orders, or
financial records. No client screen is wired to the new cancellation RPC.

No Supabase staging execution or Flutter compilation has been performed.

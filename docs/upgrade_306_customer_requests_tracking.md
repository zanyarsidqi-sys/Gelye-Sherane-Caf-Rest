# Upgrade 306 — customer service request tracking

- Staff queue displays human-readable labels and distinct icons for Specific Order and Extra Chairs, including request notes and assigned employee identifier.
- Customer request screen automatically polls its existing visit-scoped status RPC every 8 seconds after submission and stops polling at terminal status or disposal.
- Staff queue no longer shows a misleading “new requests” notification for every existing waiting request on first load.
- Existing authorization, staff status transitions, duplicate limits and rate limits are unchanged.

## Remaining work
Background push notifications, staff-name resolution, cross-device real-time delivery, automated escalation, secure final bill and full Flutter/Supabase integration testing remain pending. These files are not live deployed.

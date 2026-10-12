# Upgrade 293: Event venue scope
- Customer preview now offers whole-café or selected-tables event requests.
- Added venue_scope to events and event-to-tables relation with RLS and revoked direct writes.
- Existing single-table events are preserved.
- Public submission remains disabled until secure verification, rate limiting and server-side conflict checks are deployed.
- Whole-venue and multi-table approval MUST be added to admin RPC before booking; this migration alone does not protect availability.
- Flutter compilation and live Supabase testing not performed.

# Upgrade 1227 — Station-scoped print dispatch protocol

Adds service-role-only database functions to claim the oldest queued ticket belonging to a live, authorized station device and to acknowledge a matching dispatch attempt. A device assigned to Kitchen cannot claim a Barista ticket. `FOR UPDATE SKIP LOCKED` prevents concurrent claims. Session revocation, expiry, and station order-print permission are checked. Attempts are tracked; stale acknowledgments are rejected.

**Not yet implemented:** The Edge Function endpoints to expose these functions to authenticated station devices; a local printer worker/driver; printing ticket contents and correction revisions; safe operator-controlled requeue of uncertain jobs; bill printing; and reliable detection of physical printer success. Do not automatically retry an uncertain print, because it may have physically printed already. An acknowledgement is a device assertion, not independently verified paper output.

No production testing performed. Flutter compilation, live Supabase, physical printers deferred.

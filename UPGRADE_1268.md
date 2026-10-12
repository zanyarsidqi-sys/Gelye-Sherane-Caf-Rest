# Upgrade 1268 — Dashboard no-snapshot recovery

Added an actionable Retry live data control to the completed-without-snapshot state, matching other Dashboard recovery states. Retains existing permission checks and uses the existing `_refresh` callback. No Supabase schema changes.

Verification: static source assertion and ZIP integrity only. Flutter compilation and backend/device testing not performed.

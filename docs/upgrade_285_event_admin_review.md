# Upgrade 285 — Admin event review
Adds deny-by-default approval/rejection RPC, status transition enforcement, table-row locking, conflict checks against approved ordinary and event reservations, and audit history.

**Not yet production ready:** Administrator app_metadata role must be configured by trusted backend. Existing ordinary booking confirmation must be updated to reject approved event overlaps while locking the same table; this migration alone does not guarantee bidirectional conflict prevention. No live Supabase test or Flutter compilation performed. Kitchen release and customer UI remain pending.
